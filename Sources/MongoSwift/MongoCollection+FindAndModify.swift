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
     * - Throws: 
     *   - `MongoError.commandError` if there are any errors executing the command.
     *   - A `DecodingError` if the deleted document cannot be decoded to a `CollectionType` value
     */
    @discardableResult
    public func findOneAndDelete(_ filter: Document, options: FindOneAndDeleteOptions? = nil) throws -> CollectionType? {
        throw MongoError.commandError(message: "Unimplemented command")
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
     * - Throws: 
     *   - `MongoError.commandError` if there are any errors executing the command.
     *   - An `EncodingError` if `replacement` cannot be encoded to a `Document`
     *   - A `DecodingError` if the replaced document cannot be decoded to a `CollectionType` value
     */
    @discardableResult
    public func findOneAndReplace(filter: Document, replacement: CollectionType,
                                  options: FindOneAndDeleteOptions? = nil) throws -> CollectionType? {
        throw MongoError.commandError(message: "Unimplemented command")
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
     * - Throws: 
     *   - `MongoError.commandError` if there are any errors executing the command.
     *   - A `DecodingError` if the updated document cannot be decoded to a `CollectionType` value
     */
    @discardableResult
    public func findOneAndUpdate(filter: Document, update: Document,
                                 options: FindOneAndUpdateOptions? = nil) throws -> CollectionType? {
        throw MongoError.commandError(message: "Unimplemented command")
    }
}

/// Indicates which document to return in a find and modify operation.
public enum ReturnDocument: Encodable {
    /// Indicates to return the document before the update, replacement, or insert occured.
    case before

    ///  Indicates to return the document after the update, replacement, or insert occured.
    case after

    public func encode(to encoder: Encoder) throws {
        // fill in later on
    }
}

/// Options to use when executing a `findOneAndDelete` command on a `MongoCollection`. 
public struct FindOneAndDeleteOptions: Encodable {
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
}

/// Options to use when executing a `findOneAndReplace` command on a `MongoCollection`. 
public struct FindOneAndReplaceOptions: Encodable {
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
}

/// Options to use when executing a `findOneAndUpdate` command on a `MongoCollection`. 
public struct FindOneAndUpdateOptions: Encodable {
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
}
