import CLibMongoC
import NIO

/// An extension of `MongoCollection` encapsulating write operations.
extension MongoCollection {
    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it.
     *
     * - Parameters:
     *   - value: A `CollectionType` value to encode and insert
     *   - options: Optional `InsertOneOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<InsertOneResult?>`. On success, contains the result of performing the insert, or contains
     *    `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.WriteError` if an error occurs while performing the command.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the `CollectionType` to BSON.
     */
    public func insertOne(
        _ value: CollectionType,
        options: InsertOneOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<InsertOneResult?> {
        self.bulkWrite([.insertOne(value)], options: options?.toBulkWriteOptions(), session: session)
            .flatMapThrowing { try InsertOneResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Encodes the provided values to BSON and inserts them. If any values are
     * missing identifiers, the driver will generate them.
     *
     * - Parameters:
     *   - values: The `CollectionType` values to insert
     *   - options: optional `InsertManyOptions` to use while executing the operation
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<InsertManyResult?>`. On success, contains the result of performing the inserts, or
     *    contains `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.BulkWriteError` if an error occurs while performing any of the writes.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    public func insertMany(
        _ values: [CollectionType],
        options: InsertManyOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<InsertManyResult?> {
        self.bulkWrite(values.map { .insertOne($0) }, options: options, session: session)
            .flatMapThrowing { InsertManyResult(from: $0) }
    }

    /**
     * Replaces a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria
     *   - replacement: The replacement value, a `CollectionType` value to be encoded and inserted
     *   - options: Optional `ReplaceOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<UpdateResult?>`. On success, contains the result of performing the replacement, or
     *    contains `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.WriteError` if an error occurs while performing the command.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    public func replaceOne(
        filter: BSONDocument,
        replacement: CollectionType,
        options: ReplaceOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<UpdateResult?> {
        let modelOptions = ReplaceOneModelOptions(collation: options?.collation, upsert: options?.upsert)
        let model = WriteModel.replaceOne(filter: filter, replacement: replacement, options: modelOptions)
        return self.bulkWrite([model], options: options?.toBulkWriteOptions(), session: session)
            .flatMapThrowing { try UpdateResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria
     *   - update: A `BSONDocument` representing the update to be applied to a matching document
     *   - options: Optional `UpdateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<UpdateResult?>`. On success, contains the result of performing the update, or contains
     *    `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.WriteError` if an error occurs while performing the command.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func updateOne(
        filter: BSONDocument,
        update: BSONDocument,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<UpdateResult?> {
        let modelOptions = UpdateModelOptions(
            arrayFilters: options?.arrayFilters,
            collation: options?.collation,
            upsert: options?.upsert
        )
        let model: WriteModel<CollectionType> = .updateOne(filter: filter, update: update, options: modelOptions)
        return self.bulkWrite([model], options: options?.toBulkWriteOptions(), session: session)
            .flatMapThrowing { try UpdateResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria
     *   - update: A `BSONDocument` representing the update to be applied to matching documents
     *   - options: Optional `UpdateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<UpdateResult?>`. On success, contains the result of performing the update, or contains
     *    `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.WriteError` if an error occurs while performing the command.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func updateMany(
        filter: BSONDocument,
        update: BSONDocument,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<UpdateResult?> {
        let modelOptions = UpdateModelOptions(
            arrayFilters: options?.arrayFilters,
            collation: options?.collation,
            upsert: options?.upsert
        )
        let model: WriteModel<CollectionType> = .updateMany(filter: filter, update: update, options: modelOptions)
        return self.bulkWrite([model], options: options?.toBulkWriteOptions(), session: session)
            .flatMapThrowing { try UpdateResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<DeleteResult?>`. On success, contains the result of performing the deletion, or contains
     *    `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.WriteError` if an error occurs while performing the command.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func deleteOne(
        _ filter: BSONDocument,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<DeleteResult?> {
        let modelOptions = DeleteModelOptions(collation: options?.collation)
        let model: WriteModel<CollectionType> = .deleteOne(filter, options: modelOptions)
        return self.bulkWrite([model], options: options?.toBulkWriteOptions(), session: session)
            .flatMapThrowing { try DeleteResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Deletes all matching documents from the collection.
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<DeleteResult?>`. On success, contains the result of performing the deletions, or contains
     *    `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.WriteError` if an error occurs while performing the command.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func deleteMany(
        _ filter: BSONDocument,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<DeleteResult?> {
        let modelOptions = DeleteModelOptions(collation: options?.collation)
        let model: WriteModel<CollectionType> = .deleteMany(filter, options: modelOptions)
        return self.bulkWrite([model], options: options?.toBulkWriteOptions(), session: session)
            .flatMapThrowing { try DeleteResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }
}

/// Protocol indicating that an options type can be converted to a BulkWriteOptions.
private protocol BulkWriteOptionsConvertible {
    var bypassDocumentValidation: Bool? { get }
    var writeConcern: WriteConcern? { get }
    func toBulkWriteOptions() -> BulkWriteOptions
}

/// Default implementation of the protocol.
private extension BulkWriteOptionsConvertible {
    func toBulkWriteOptions() -> BulkWriteOptions {
        BulkWriteOptions(
            bypassDocumentValidation: self.bypassDocumentValidation,
            writeConcern: self.writeConcern
        )
    }
}

// Write command options structs

/// Options to use when executing an `insertOne` command on a `MongoCollection`.
public struct InsertOneOptions: Codable, BulkWriteOptionsConvertible {
    /// If true, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// An optional WriteConcern to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing bypassDocumentValidation to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a multi-document insert operation on a `MongoCollection`.
public typealias InsertManyOptions = BulkWriteOptions

/// Options to use when executing an `update` command on a `MongoCollection`.
public struct UpdateOptions: Codable, BulkWriteOptionsConvertible {
    /// A set of filters specifying to which array elements an update should apply.
    public var arrayFilters: [BSONDocument]?

    /// If true, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public var collation: BSONDocument?

    /// When true, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional WriteConcern to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        arrayFilters: [BSONDocument]? = nil,
        bypassDocumentValidation: Bool? = nil,
        collation: BSONDocument? = nil,
        upsert: Bool? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.arrayFilters = arrayFilters
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `replace` command on a `MongoCollection`.
public struct ReplaceOptions: Codable, BulkWriteOptionsConvertible {
    /// If true, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public var collation: BSONDocument?

    /// When true, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        bypassDocumentValidation: Bool? = nil,
        collation: BSONDocument? = nil,
        upsert: Bool? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `delete` command on a `MongoCollection`.
public struct DeleteOptions: Codable, BulkWriteOptionsConvertible {
    /// Specifies a collation.
    public var collation: BSONDocument?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing collation to be omitted or optional
    public init(collation: BSONDocument? = nil, writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.writeConcern = writeConcern
    }

    /// This is a requirement of the BulkWriteOptionsConvertible protocol.
    /// Since it does not apply to deletions, we just set it to nil.
    internal var bypassDocumentValidation: Bool? { nil }
}

// Write command results structs

/// The result of an `insertOne` command on a `MongoCollection`.
public struct InsertOneResult: Decodable {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedID: BSON

    private enum CodingKeys: String, CodingKey {
        case insertedID = "insertedId"
    }

    internal init?(from result: BulkWriteResult?) throws {
        guard let result = result else {
            return nil
        }
        guard let id = result.insertedIDs[0] else {
            throw MongoError.InternalError(message: "BulkWriteResult missing _id for inserted document")
        }
        self.insertedID = id
    }
}

/// The result of a multi-document insert operation on a `MongoCollection`.
public struct InsertManyResult {
    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the document in `values` to the value of its ID
    public let insertedIDs: [Int: BSON]

    /// Internal initializer used for converting from a `BulkWriteResult` optional to an `InsertManyResult` optional.
    internal init?(from result: BulkWriteResult?) {
        guard let result = result else {
            return nil
        }
        self.insertedCount = result.insertedCount
        self.insertedIDs = result.insertedIDs
    }
}

/// The result of a `delete` command on a `MongoCollection`.
public struct DeleteResult: Decodable {
    /// The number of documents that were deleted.
    public let deletedCount: Int

    internal init?(from result: BulkWriteResult?) throws {
        guard let result = result else {
            return nil
        }
        self.deletedCount = result.deletedCount
    }
}

/// The result of an `update` operation on a `MongoCollection`.
public struct UpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents that were modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    public let upsertedID: BSON?

    /// The number of documents that were upserted.
    public let upsertedCount: Int

    internal init?(from result: BulkWriteResult?) throws {
        guard let result = result else {
            return nil
        }
        self.matchedCount = result.matchedCount
        self.modifiedCount = result.modifiedCount
        self.upsertedCount = result.upsertedCount
        if result.upsertedCount == 1 {
            guard let id = result.upsertedIDs[0] else {
                throw MongoError.InternalError(message: "BulkWriteResult missing _id for upserted document")
            }
            self.upsertedID = id
        } else {
            self.upsertedID = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case matchedCount, modifiedCount, upsertedID = "upsertedId", upsertedCount
    }
}
