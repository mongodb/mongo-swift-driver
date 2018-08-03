import libmongoc

/// An extension of `MongoCollection` encapsulating find and modify operations.
extension MongoCollection {
    /**
     * Finds a single document and deletes it, returning the original.
     *
     * - Parameters:
     *   - filter: `Document` representing the match criteria
     *   - options: Optional `FindOneAndDeleteOptions` to use when executing the command
     *
     * - Returns: The deleted document, represented as a `CollectionType`, or `nil` if no document was deleted.
     *
     * - Throws: 
     *   - `MongoError.invalidArgument` if any of the provided options are invalid
     *   - `MongoError.commandError` if there are any errors executing the command.
     *   - A `DecodingError` if the deleted document cannot be decoded to a `CollectionType` value
     */
    @discardableResult
    public func findOneAndDelete(_ filter: Document,
                                 options: FindOneAndDeleteOptions? = nil) throws -> CollectionType? {
        // we need to always send options here in order to ensure the `remove` flag is set
        let opts = options ?? FindOneAndDeleteOptions()
        return try self.findAndModify(filter: filter, options: opts)
    }

    /**
     * Finds a single document and replaces it, returning either the original or the replaced document.
     * 
     * - Parameters:
     *   - filter: `Document` representing the match criteria
     *   - replacement: a `CollectionType` to replace the found document
     *   - options: Optional `FindOneAndReplaceOptions` to use when executing the command
     *
     * - Returns: A `CollectionType`, representing either the original document or its replacement,
     *      depending on selected options, or `nil` if there was no match.
     *
     * - Throws: 
     *   - `MongoError.invalidArgument` if any of the provided options are invalid
     *   - `MongoError.commandError` if there are any errors executing the command.
     *   - An `EncodingError` if `replacement` cannot be encoded to a `Document`
     *   - A `DecodingError` if the replaced document cannot be decoded to a `CollectionType` value
     */
    @discardableResult
    public func findOneAndReplace(filter: Document, replacement: CollectionType,
                                  options: FindOneAndReplaceOptions? = nil) throws -> CollectionType? {
        let update = try BsonEncoder().encode(replacement)
        return try self.findAndModify(filter: filter, update: update, options: options)
    }

    /**
     * Finds a single document and updates it, returning either the original or the updated document.
     * 
     * - Parameters:
     *   - filter: `Document` representing the match criteria
     *   - update: a `Document` containing updates to apply
     *   - options: Optional `FindOneAndUpdateOptions` to use when executing the command
     *
     * - Returns: A `CollectionType` representing either the original or updated document,
     *      depending on selected options, or `nil` if there was no match.
     *
     * - Throws:
     *   - `MongoError.invalidArgument` if any of the provided options are invalid
     *   - `MongoError.commandError` if there are any errors executing the command.
     *   - A `DecodingError` if the updated document cannot be decoded to a `CollectionType` value
     */
    @discardableResult
    public func findOneAndUpdate(filter: Document, update: Document,
                                 options: FindOneAndUpdateOptions? = nil) throws -> CollectionType? {
        return try self.findAndModify(filter: filter, update: update, options: options)
    }

    /// A private helper method for findAndModify operations to use
    private func findAndModify(filter: Document, update: Document? = nil,
                               options: FindAndModifyOptionsConvertible? = nil) throws -> CollectionType? {

        // encode provided options, or create empty ones. we always need
        // to send *something*, as findAndModify requires one of "remove"
        // or "update" to be set. 
        let opts = try options?.asOpts() ?? FindAndModifyOptions()

        if let update = update { try opts.setUpdate(update) }

        let reply = Document()
        var error = bson_error_t()

        if !mongoc_collection_find_and_modify_with_opts(self._collection, filter.data,
                                                        opts._options, reply.data, &error) {
            // TODO SWIFT-144: replace with more descriptive error type(s)
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard let value = reply["value"] as? Document else { return nil }

        return try BsonDecoder().decode(CollectionType.self, from: value)
    }
}

/// Indicates which document to return in a find and modify operation.
public enum ReturnDocument {
    /// Indicates to return the document before the update, replacement, or insert occured.
    case before
    ///  Indicates to return the document after the update, replacement, or insert occured.
    case after
}

/// Indicates that an options type can be represented as a `FindAndModifyOptions`
private protocol FindAndModifyOptionsConvertible {
    /// Converts `self` to a `FindAndModifyOptions`
    func asOpts() throws -> FindAndModifyOptions
}

/// Options to use when executing a `findOneAndDelete` command on a `MongoCollection`. 
public struct FindOneAndDeleteOptions: FindAndModifyOptionsConvertible {
    /// Specifies a collation to use.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// Limits the fields to return for the matching document.
    public let projection: Document?

    /// Determines which document the operation modifies if the query selects multiple documents.
    public let sort: Document?

    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

    fileprivate func asOpts() throws -> FindAndModifyOptions {
        return try FindAndModifyOptions(collation: collation, maxTimeMS: maxTimeMS, projection: projection,
                                        remove: true, sort: sort, writeConcern: writeConcern)
    }

    /// Convenience initializer allowing any/all parameters to be omitted/optional
    public init(collation: Document? = nil, maxTimeMS: Int64? = nil, projection: Document? = nil, sort: Document? = nil,
                writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.projection = projection
        self.sort = sort
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `findOneAndReplace` command on a `MongoCollection`. 
public struct FindOneAndReplaceOptions: FindAndModifyOptionsConvertible {
    /// If `true`, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation to use.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// Limits the fields to return for the matching document.
    public let projection: Document?

    /// When `ReturnDocument.After`, returns the replaced or inserted document rather than the original.
    public let returnDocument: ReturnDocument?

    /// Determines which document the operation modifies if the query selects multiple documents.
    public let sort: Document?

    /// When `true`, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

    fileprivate func asOpts() throws -> FindAndModifyOptions {
        return try FindAndModifyOptions(bypassDocumentValidation: bypassDocumentValidation, collation: collation,
                                        maxTimeMS: maxTimeMS, projection: projection, returnDocument: returnDocument,
                                        sort: sort, upsert: upsert, writeConcern: writeConcern)
    }

    /// Convenience initializer allowing any/all parameters to be omitted/optional
    public init(bypassDocumentValidation: Bool? = nil, collation: Document? = nil, maxTimeMS: Int64? = nil,
                projection: Document? = nil, returnDocument: ReturnDocument? = nil, sort: Document? = nil,
                upsert: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.projection = projection
        self.returnDocument = returnDocument
        self.sort = sort
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `findOneAndUpdate` command on a `MongoCollection`. 
public struct FindOneAndUpdateOptions: FindAndModifyOptionsConvertible {
    /// A set of filters specifying to which array elements an update should apply.
    public let arrayFilters: [Document]?

    /// If `true`, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation to use.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// Limits the fields to return for the matching document.
    public let projection: Document?

    /// When`ReturnDocument.After`, returns the updated or inserted document rather than the original.
    public let returnDocument: ReturnDocument?

    /// Determines which document the operation modifies if the query selects multiple documents.
    public let sort: Document?

    /// When `true`, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

    fileprivate func asOpts() throws -> FindAndModifyOptions {
        return try FindAndModifyOptions(arrayFilters: arrayFilters, bypassDocumentValidation: bypassDocumentValidation,
                                        collation: collation, maxTimeMS: maxTimeMS, projection: projection,
                                        returnDocument: returnDocument, sort: sort, upsert: upsert,
                                        writeConcern: writeConcern)
    }

    /// Convenience initializer allowing any/all parameters to be omitted/optional
    public init(arrayFilters: [Document]? = nil, bypassDocumentValidation: Bool? = nil, collation: Document? = nil,
                maxTimeMS: Int64? = nil, projection: Document? = nil, returnDocument: ReturnDocument? = nil,
                sort: Document? = nil, upsert: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.arrayFilters = arrayFilters
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.projection = projection
        self.returnDocument = returnDocument
        self.sort = sort
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// A class wrapping a `mongoc_find_and_modify_opts_t`, for use with `MongoCollection.findAndModify`
private class FindAndModifyOptions {
    // an `OpaquePointer` to a `mongoc_find_and_modify_opts_t`
    var _options: OpaquePointer?

    init() {
        self._options = mongoc_find_and_modify_opts_new()
    }

    // swiftlint:disable:next cyclomatic_complexity
    init(arrayFilters: [Document]? = nil, bypassDocumentValidation: Bool? = nil, collation: Document?,
         maxTimeMS: Int64?, projection: Document?, remove: Bool? = nil, returnDocument: ReturnDocument? = nil,
         sort: Document?, upsert: Bool? = nil, writeConcern: WriteConcern?) throws {
        self._options = mongoc_find_and_modify_opts_new()

        if let bypass = bypassDocumentValidation,
        !mongoc_find_and_modify_opts_set_bypass_document_validation(self._options, bypass) {
            throw MongoError.invalidArgument(message: "Error setting bypassDocumentValidation to \(bypass)")
        }

        if let fields = projection, !mongoc_find_and_modify_opts_set_fields(self._options, fields.data) {
            throw MongoError.invalidArgument(message: "Error setting fields to \(fields)")
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
            throw MongoError.invalidArgument(message:
                "Error setting flags to \(flags); remove=\(remStr), upsert=\(upsStr), returnDocument=\(retStr)")
        }

        if let sort = sort, !mongoc_find_and_modify_opts_set_sort(self._options, sort.data) {
            throw MongoError.invalidArgument(message: "Error setting sort to \(sort)")
        }

        // build an "extra" document of fields without their own setters
        var extra = Document()
        if let filters = arrayFilters { extra["arrayFilters"] = filters }
        if let coll = collation { extra["collation"] = coll }

        // note: mongoc_find_and_modify_opts_set_max_time_ms() takes in a 
        // uint32_t, but it should be a positive 64-bit integer, so we
        // set maxTimeMS by directly appending it instead. see CDRIVER-1329
        if let maxTime = maxTimeMS {
            guard maxTime > 0 else {
                throw MongoError.invalidArgument(message: "maxTimeMS must be positive, but got value \(maxTime)")
            }
            extra["maxTimeMS"] = maxTime
        }

        if let wc = writeConcern {
            do {
                extra["writeConcern"] = try BsonEncoder().encode(wc)
            } catch {
                throw MongoError.invalidArgument(message: "Error encoding WriteConcern \(wc): \(error)")
            }
        }

        if extra.keys.count > 0 && !mongoc_find_and_modify_opts_append(self._options, extra.data) {
            throw MongoError.invalidArgument(message: "Error appending extra fields \(extra)")
        }
    }

    /// Sets the `update` value on a `mongoc_find_and_modify_opts_t`. We need to have this separate from the 
    /// initializer because its value comes from the API methods rather than their options types.
    fileprivate func setUpdate(_ update: Document) throws {
        if !mongoc_find_and_modify_opts_set_update(self._options, update.data) {
            throw MongoError.invalidArgument(message: "Error setting update to \(update)")
        }
    }

    deinit {
        guard let options = self._options else { return }
        mongoc_find_and_modify_opts_destroy(options)
        self._options = nil
    }
}
