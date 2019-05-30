import mongoc

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
     *   - `UserError.invalidArgumentError` if any of the provided options are invalid.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `ServerError.writeError` if an error occurs while executing the command.
     *   - `DecodingError` if the deleted document cannot be decoded to a `CollectionType` value.
     */
    @discardableResult
    public func findOneAndDelete(_ filter: Document,
                                 options: FindOneAndDeleteOptions? = nil,
                                 session: ClientSession? = nil) throws -> CollectionType? {
        // we need to always send options here in order to ensure the `remove` flag is set
        let opts = options ?? FindOneAndDeleteOptions()
        return try self.findAndModify(filter: filter, options: opts, session: session)
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
     *   - `UserError.invalidArgumentError` if any of the provided options are invalid.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `ServerError.writeError` if an error occurs while executing the command.
     *   - `DecodingError` if the replaced document cannot be decoded to a `CollectionType` value.
     *   - `EncodingError` if `replacement` cannot be encoded to a `Document`.
     */
    @discardableResult
    public func findOneAndReplace(filter: Document,
                                  replacement: CollectionType,
                                  options: FindOneAndReplaceOptions? = nil,
                                  session: ClientSession? = nil) throws -> CollectionType? {
        let update = try self.encoder.encode(replacement)
        return try self.findAndModify(filter: filter, update: update, options: options, session: session)
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
     *   - `UserError.invalidArgumentError` if any of the provided options are invalid.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `ServerError.writeError` if an error occurs while executing the command.
     *   - `DecodingError` if the updated document cannot be decoded to a `CollectionType` value.
     */
    @discardableResult
    public func findOneAndUpdate(filter: Document,
                                 update: Document,
                                 options: FindOneAndUpdateOptions? = nil,
                                 session: ClientSession? = nil) throws -> CollectionType? {
        return try self.findAndModify(filter: filter, update: update, options: options, session: session)
    }

    /**
     * A private helper method for findAndModify operations to use.
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if any of the provided options are invalid.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `ServerError.writeError` if an error occurs while executing the command.
     *   - `DecodingError` if the updated document cannot be decoded to a `CollectionType` value.
     */
    private func findAndModify(filter: Document,
                               update: Document? = nil,
                               options: FindAndModifyOptionsConvertible? = nil,
                               session: ClientSession?) throws -> CollectionType? {
        let operation = FindAndModifyOperation(collection: self,
                                               filter: filter,
                                               update: update,
                                               options: options,
                                               session: session)
        return try operation.execute()
    }
}

/// Indicates which document to return in a find and modify operation.
public enum ReturnDocument: String, Decodable {
    /// Indicates to return the document before the update, replacement, or insert occurred.
    case before = "Before"
    ///  Indicates to return the document after the update, replacement, or insert occurred.
    case after = "After"
}

/// Indicates that an options type can be represented as a `FindAndModifyOptions`
internal protocol FindAndModifyOptionsConvertible {
    /// Converts `self` to a `FindAndModifyOptions`
    ///
    /// - Throws: `UserError.invalidArgumentError` if any of the options are invalid.
    func asFindAndModifyOptions() throws -> FindAndModifyOptions
}

/// Options to use when executing a `findOneAndDelete` command on a `MongoCollection`.
public struct FindOneAndDeleteOptions: FindAndModifyOptionsConvertible, Decodable {
    /// Specifies a collation to use.
    public var collation: Document?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// Limits the fields to return for the matching document.
    public var projection: Document?

    /// Determines which document the operation modifies if the query selects multiple documents.
    public var sort: Document?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    internal func asFindAndModifyOptions() throws -> FindAndModifyOptions {
        return try FindAndModifyOptions(collation: collation,
                                        maxTimeMS: maxTimeMS,
                                        projection: projection,
                                        remove: true,
                                        sort: sort,
                                        writeConcern: writeConcern)
    }

    /// Convenience initializer allowing any/all parameters to be omitted/optional
    public init(collation: Document? = nil,
                maxTimeMS: Int64? = nil,
                projection: Document? = nil,
                sort: Document? = nil,
                writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.projection = projection
        self.sort = sort
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `findOneAndReplace` command on a `MongoCollection`.
public struct FindOneAndReplaceOptions: FindAndModifyOptionsConvertible, Decodable {
    /// If `true`, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation to use.
    public var collation: Document?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// Limits the fields to return for the matching document.
    public var projection: Document?

    /// When `ReturnDocument.After`, returns the replaced or inserted document rather than the original.
    public var returnDocument: ReturnDocument?

    /// Determines which document the operation modifies if the query selects multiple documents.
    public var sort: Document?

    /// When `true`, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    internal func asFindAndModifyOptions() throws -> FindAndModifyOptions {
        return try FindAndModifyOptions(bypassDocumentValidation: bypassDocumentValidation,
                                        collation: collation,
                                        maxTimeMS: maxTimeMS,
                                        projection: projection,
                                        returnDocument: returnDocument,
                                        sort: sort,
                                        upsert: upsert,
                                        writeConcern: writeConcern)
    }

    /// Convenience initializer allowing any/all parameters to be omitted/optional.
    public init(bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil,
                maxTimeMS: Int64? = nil,
                projection: Document? = nil,
                returnDocument: ReturnDocument? = nil,
                sort: Document? = nil,
                upsert: Bool? = nil,
                writeConcern: WriteConcern? = nil) {
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
public struct FindOneAndUpdateOptions: FindAndModifyOptionsConvertible, Decodable {
    /// A set of filters specifying to which array elements an update should apply.
    public var arrayFilters: [Document]?

    /// If `true`, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation to use.
    public var collation: Document?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// Limits the fields to return for the matching document.
    public var projection: Document?

    /// When`ReturnDocument.After`, returns the updated or inserted document rather than the original.
    public var returnDocument: ReturnDocument?

    /// Determines which document the operation modifies if the query selects multiple documents.
    public var sort: Document?

    /// When `true`, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    internal func asFindAndModifyOptions() throws -> FindAndModifyOptions {
        return try FindAndModifyOptions(arrayFilters: arrayFilters,
                                        bypassDocumentValidation: bypassDocumentValidation,
                                        collation: collation,
                                        maxTimeMS: maxTimeMS,
                                        projection: projection,
                                        returnDocument: returnDocument,
                                        sort: sort,
                                        upsert: upsert,
                                        writeConcern: writeConcern)
    }

    /// Convenience initializer allowing any/all parameters to be omitted/optional.
    public init(arrayFilters: [Document]? = nil,
                bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil,
                maxTimeMS: Int64? = nil,
                projection: Document? = nil,
                returnDocument: ReturnDocument? = nil,
                sort: Document? = nil,
                upsert: Bool? = nil,
                writeConcern: WriteConcern? = nil) {
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
