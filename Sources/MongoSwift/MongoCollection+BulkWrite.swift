import libmongoc

/// An extension of `MongoCollection` encapsulating bulk write operations.
extension MongoCollection {
    /**
     * Execute multiple write operations.
     *
     * - Parameters:
     *   - requests: a `[WriteModel]` containing the writes to perform
     *   - options: optional `BulkWriteOptions` to use while executing the operation
     *
     * - Returns: a `BulkWriteResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.invalidArgument` if `requests` is empty
     *   - `MongoError.bulkWriteError` if any error occurs while performing the writes
     */
    @discardableResult
    public func bulkWrite(_ requests: [WriteModel], options: BulkWriteOptions? = nil) throws -> BulkWriteResult? {
        throw MongoError.commandError(message: "Unimplemented command")
    }
}

/// Options to use when performing a bulk write operation on a `MongoCollection`.
public struct BulkWriteOptions: Encodable {
    /// If `true` (the default), when an insert fails, return without performing the remaining writes.
    /// If `false`, when a write fails, continue with the remaining writes, if any.
    public var ordered: Bool = true

    /// If `true`, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?
}

/// A protocol indicating write types that can be batched together using `MongoCollection.bulkWrite`.
public protocol WriteModel: Encodable {}

/// A model for an `insertOne` command.
public struct InsertOneModel: WriteModel {
    /// The `Document` to insert.
    public let document: Document
}

/// A model for a `deleteOne` command.
public struct DeleteOneModel: WriteModel {
    /// A `Document` representing the match criteria.
    public let filter: Document

    /// Specifies a collation to use.
    public let collation: Document?
}

/// A model for a `deleteMany` command.
public struct DeleteManyModel: WriteModel {
    /// A `Document` representing the match criteria.
    public let filter: Document

    /// Specifies a collation to use.
    public let collation: Document?
}

/// A model for a `replaceOne` command.
public struct ReplaceOneModel: WriteModel {
    /// A `Document` representing the match criteria.
    public let filter: Document

    /// The `Document` with which to replace the matched document.
    public let replacement: Document

    /// Specifies a collation to use.
    public let collation: Document?

    /// When `true`, creates a new document if no document matches the query.
    public let upsert: Bool?
}

/// A model for an `updateOne` command.
public struct UpdateOneModel: WriteModel {
    /// A `Document` representing the match criteria.
    public let filter: Document

    /// A `Document` containing update operators.
    public let update: Document

    /// A set of filters specifying to which array elements an update should apply.
    public let arrayFilters: [Document]?

    /// Specifies a collation to use.
    public let collation: Document?

    /// When `true`, creates a new document if no document matches the query.
    public let upsert: Bool?
}

/// A model for an `updateMany` command.
public struct UpdateManyModel: WriteModel {
    /// A `Document` representing the match criteria.
    public let filter: Document

    /// A `Document` containing update operators.
    public let update: Document

    /// A set of filters specifying to which array elements an update should apply.
    public let arrayFilters: [Document]?

    /// Specifies a collation to use.
    public let collation: Document?

    /// When `true`, creates a new document if no document matches the query.
    public let upsert: Bool?
}

/// The result of a bulk write operation on a `MongoCollection`.
public struct BulkWriteResult: Decodable {
    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the operation to the id of the inserted document.
    public let insertedIds: [Int: AnyBsonValue]

    /// Number of documents matched for update.
    public let matchedCount: Int

    /// Number of documents modified.
    public let modifiedCount: Int

    /// Number of documents deleted.
    public let deletedCount: Int

    /// Number of documents upserted.
    public let upsertedCount: Int

    /// Map of the index of the operation to the id of the upserted document.
    public let upsertedIds: [Int: AnyBsonValue]
}
