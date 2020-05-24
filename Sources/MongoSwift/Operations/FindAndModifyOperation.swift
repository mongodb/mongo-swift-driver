import CLibMongoC

/// A class wrapping a `mongoc_find_and_modify_opts_t`, for use with `MongoCollection.findAndModify`.
internal class FindAndModifyOptions {
    /// an `OpaquePointer` to a `mongoc_find_and_modify_opts_t`.
    private let _options: OpaquePointer

    /// Cleans up internal state.
    deinit {
        mongoc_find_and_modify_opts_destroy(self._options)
    }

    fileprivate init() {
        self._options = mongoc_find_and_modify_opts_new()
    }

    /// Initializes a new `FindAndModifyOptions` with the given settings.
    ///
    /// - Throws: `InvalidArgumentError` if any of the options are invalid.
    // swiftlint:disable:next cyclomatic_complexity
    internal init(
        arrayFilters: [Document]? = nil,
        bypassDocumentValidation: Bool? = nil,
        collation: Document?,
        maxTimeMS: Int?,
        projection: Document?,
        remove: Bool? = nil,
        returnDocument: ReturnDocument? = nil,
        sort: Document?,
        upsert: Bool? = nil,
        writeConcern: WriteConcern?
    ) throws {
        self._options = mongoc_find_and_modify_opts_new()

        if let bypass = bypassDocumentValidation,
            !mongoc_find_and_modify_opts_set_bypass_document_validation(self._options, bypass) {
            throw InvalidArgumentError(message: "Error setting bypassDocumentValidation to \(bypass)")
        }

        if let fields = projection {
            try fields.withBSONPointer { fieldsPtr in
                guard mongoc_find_and_modify_opts_set_fields(self._options, fieldsPtr) else {
                    throw InvalidArgumentError(message: "Error setting fields to \(fields)")
                }
            }
        }

        // build a mongoc_find_and_modify_flags_t
        var flags = MONGOC_FIND_AND_MODIFY_NONE.rawValue
        if remove == true { flags |= MONGOC_FIND_AND_MODIFY_REMOVE.rawValue }
        if upsert == true { flags |= MONGOC_FIND_AND_MODIFY_UPSERT.rawValue }
        if returnDocument == .after { flags |= MONGOC_FIND_AND_MODIFY_RETURN_NEW.rawValue }
        let mongocFlags = mongoc_find_and_modify_flags_t(rawValue: flags)

        if mongocFlags != MONGOC_FIND_AND_MODIFY_NONE
            && !mongoc_find_and_modify_opts_set_flags(self._options, mongocFlags) {
            let remStr = String(describing: remove)
            let upsStr = String(describing: upsert)
            let retStr = String(describing: returnDocument)
            throw InvalidArgumentError(
                message:
                "Error setting flags to \(flags); remove=\(remStr), upsert=\(upsStr), returnDocument=\(retStr)"
            )
        }

        if let sort = sort {
            try sort.withBSONPointer { sortPtr in
                guard mongoc_find_and_modify_opts_set_sort(self._options, sortPtr) else {
                    throw InvalidArgumentError(message: "Error setting sort to \(sort)")
                }
            }
        }

        // build an "extra" document of fields without their own setters
        var extra = Document()
        if let filters = arrayFilters {
            try extra.setValue(for: "arrayFilters", to: .array(filters.map { .document($0) }))
        }
        if let coll = collation { try extra.setValue(for: "collation", to: .document(coll)) }

        // note: mongoc_find_and_modify_opts_set_max_time_ms() takes in a
        // uint32_t, but it should be a positive 64-bit integer, so we
        // set maxTimeMS by directly appending it instead. see CDRIVER-1329
        if let maxTime = maxTimeMS {
            guard maxTime > 0 else {
                throw InvalidArgumentError(message: "maxTimeMS must be positive, but got value \(maxTime)")
            }
            try extra.setValue(for: "maxTimeMS", to: .int64(Int64(maxTime)))
        }

        if let wc = writeConcern {
            do {
                try extra.setValue(for: "writeConcern", to: .document(try BSONEncoder().encode(wc)))
            } catch {
                throw InternalError(message: "Error encoding WriteConcern \(wc): \(error)")
            }
        }

        if !extra.isEmpty {
            try extra.withBSONPointer { extraPtr in
                guard mongoc_find_and_modify_opts_append(self._options, extraPtr) else {
                    throw InvalidArgumentError(message: "Error appending extra fields \(extra)")
                }
            }
        }
    }

    /// Sets the `update` value on a `mongoc_find_and_modify_opts_t`. We need to have this separate from the
    /// initializer because its value comes from the API methods rather than their options types.
    fileprivate func setUpdate(_ update: Document) throws {
        try update.withBSONPointer { updatePtr in
            guard mongoc_find_and_modify_opts_set_update(self._options, updatePtr) else {
                throw InvalidArgumentError(message: "Error setting update to \(update)")
            }
        }
    }

    fileprivate func setSession(_ session: ClientSession?) throws {
        guard let session = session else {
            return
        }
        var doc = Document()
        try session.append(to: &doc)

        try doc.withBSONPointer { docPtr in
            guard mongoc_find_and_modify_opts_append(self._options, docPtr) else {
                throw InternalError(message: "Couldn't read session information")
            }
        }
    }

    /// Executes the provided closure using a pointer to the underlying libmongoc options.
    fileprivate func withMongocOptions<T>(_ body: (OpaquePointer) throws -> T) rethrows -> T {
        try body(self._options)
    }
}

/// An operation corresponding to a "findAndModify" command.
internal struct FindAndModifyOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let filter: Document
    private let update: Document?
    private let options: FindAndModifyOptionsConvertible?

    internal init(
        collection: MongoCollection<T>,
        filter: Document,
        update: Document?,
        options: FindAndModifyOptionsConvertible?
    ) {
        self.collection = collection
        self.filter = filter
        self.update = update
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> T? {
        // we always need to send *something*, as findAndModify requires one of "remove"
        // or "update" to be set.
        let opts = try self.options?.toFindAndModifyOptions() ?? FindAndModifyOptions()
        if let session = session { try opts.setSession(session) }
        if let update = self.update { try opts.setUpdate(update) }

        var error = bson_error_t()

        let (success, reply) = self.collection.withMongocCollection(from: connection) { collPtr -> (Bool, Document) in
            self.filter.withBSONPointer { filterPtr in
                opts.withMongocOptions { optsPtr in
                    withStackAllocatedMutableBSONPointer { replyPtr in
                        let success = mongoc_collection_find_and_modify_with_opts(
                            collPtr,
                            filterPtr,
                            optsPtr,
                            replyPtr,
                            &error
                        )
                        return (success, Document(copying: replyPtr))
                    }
                }
            }
        }

        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }

        guard let value = try reply.getValue(for: "value")?.documentValue else {
            return nil
        }

        return try self.collection.decoder.decode(T.self, from: value)
    }
}
