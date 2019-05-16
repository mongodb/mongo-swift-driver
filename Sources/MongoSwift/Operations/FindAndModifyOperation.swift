import mongoc

/// A class wrapping a `mongoc_find_and_modify_opts_t`, for use with `MongoCollection.findAndModify`
internal class FindAndModifyOptions {
    /// an `OpaquePointer` to a `mongoc_find_and_modify_opts_t`
    fileprivate var _options: OpaquePointer?

    /// Cleans up internal state.
    deinit {
        guard let options = self._options else {
            return
        }
        mongoc_find_and_modify_opts_destroy(options)
        self._options = nil
    }

    fileprivate init() {
        self._options = mongoc_find_and_modify_opts_new()
    }

    /// Initializes a new `FindAndModifyOptions` with the given settings.
    ///
    /// - Throws: `UserError.invalidArgumentError` if any of the options are invalid.
    // swiftlint:disable:next cyclomatic_complexity
    internal init(arrayFilters: [Document]? = nil,
                  bypassDocumentValidation: Bool? = nil,
                  collation: Document?,
                  maxTimeMS: Int64?,
                  projection: Document?,
                  remove: Bool? = nil,
                  returnDocument: ReturnDocument? = nil,
                  sort: Document?,
                  upsert: Bool? = nil,
                  writeConcern: WriteConcern?) throws {
        self._options = mongoc_find_and_modify_opts_new()

        if let bypass = bypassDocumentValidation,
        !mongoc_find_and_modify_opts_set_bypass_document_validation(self._options, bypass) {
            throw UserError.invalidArgumentError(message: "Error setting bypassDocumentValidation to \(bypass)")
        }

        if let fields = projection {
            guard mongoc_find_and_modify_opts_set_fields(self._options, fields._bson) else {
                throw UserError.invalidArgumentError(message: "Error setting fields to \(fields)")
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
            throw UserError.invalidArgumentError(message:
                "Error setting flags to \(flags); remove=\(remStr), upsert=\(upsStr), returnDocument=\(retStr)")
        }

        if let sort = sort {
            guard mongoc_find_and_modify_opts_set_sort(self._options, sort._bson) else {
                throw UserError.invalidArgumentError(message: "Error setting sort to \(sort)")
            }
        }

        // build an "extra" document of fields without their own setters
        var extra = Document()
        if let filters = arrayFilters { try extra.setValue(for: "arrayFilters", to: filters) }
        if let coll = collation { try extra.setValue(for: "collation", to: coll) }

        // note: mongoc_find_and_modify_opts_set_max_time_ms() takes in a
        // uint32_t, but it should be a positive 64-bit integer, so we
        // set maxTimeMS by directly appending it instead. see CDRIVER-1329
        if let maxTime = maxTimeMS {
            guard maxTime > 0 else {
                throw UserError.invalidArgumentError(message: "maxTimeMS must be positive, but got value \(maxTime)")
            }
            try extra.setValue(for: "maxTimeMS", to: maxTime)
        }

        if let wc = writeConcern {
            do {
                try extra.setValue(for: "writeConcern", to: try BSONEncoder().encode(wc))
            } catch {
                throw RuntimeError.internalError(message: "Error encoding WriteConcern \(wc): \(error)")
            }
        }

        guard extra.isEmpty || mongoc_find_and_modify_opts_append(self._options, extra._bson) else {
            throw UserError.invalidArgumentError(message: "Error appending extra fields \(extra)")
        }
    }

    /// Sets the `update` value on a `mongoc_find_and_modify_opts_t`. We need to have this separate from the
    /// initializer because its value comes from the API methods rather than their options types.
    fileprivate func setUpdate(_ update: Document) throws {
        guard mongoc_find_and_modify_opts_set_update(self._options, update._bson) else {
            throw UserError.invalidArgumentError(message: "Error setting update to \(update)")
        }
    }

    fileprivate func setSession(_ session: ClientSession?) throws {
        guard let session = session else {
            return
        }
        var doc = Document()
        try session.append(to: &doc)

        guard mongoc_find_and_modify_opts_append(self._options, doc._bson) else {
            throw RuntimeError.internalError(message: "Couldn't read session information")
        }
    }
}

/// An operation corresponding to a "findAndModify" command.
internal struct FindAndModifyOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let filter: Document
    private let update: Document?
    private let options: FindAndModifyOptionsConvertible?
    private let session: ClientSession?

    internal init(collection: MongoCollection<T>,
                  filter: Document,
                  update: Document?,
                  options: FindAndModifyOptionsConvertible?,
                  session: ClientSession?) {
        self.collection = collection
        self.filter = filter
        self.update = update
        self.options = options
        self.session = session
    }

    internal func execute() throws -> T? {
        // we always need to send *something*, as findAndModify requires one of "remove"
        // or "update" to be set.
        let opts = try self.options?.asFindAndModifyOptions() ?? FindAndModifyOptions()
        if let session = self.session { try opts.setSession(session) }
        if let update = self.update { try opts.setUpdate(update) }

        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_collection_find_and_modify_with_opts(self.collection._collection,
                                                        self.filter._bson,
                                                        opts._options,
                                                        replyPtr,
                                                        &error)
        }
        guard success else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }

        guard let value = try reply.getValue(for: "value") as? Document else {
            return nil
        }

        return try self.collection.decoder.decode(T.self, from: value)
    }
}
