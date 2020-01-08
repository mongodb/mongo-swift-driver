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
     * - Returns: An `EventLoopFuture` containing an `InsertOneResult`, or containing `nil` if the write concern is
     *            unacknowledged.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` to BSON.
     */
    @discardableResult
    public func insertOne(
        _ value: CollectionType,
        options: InsertOneOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<InsertOneResult?> {
        return self.bulkWrite([.insertOne(value)], options: options?.asBulkWriteOptions(), session: session)
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
     * - Returns: An `EventLoopFuture` containing an `InsertManyResult`, or containing `nil` if the write concern is
     *            unacknowledged.
     *
     * - Throws:
     *   - `BulkWriteError` if an error occurs while performing any of the writes.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    public func insertMany(
        _ values: [CollectionType],
        options: InsertManyOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<InsertManyResult?> {
        return self.bulkWrite(values.map { .insertOne($0) }, options: options, session: session)
            .flatMapThrowing { InsertManyResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Replaces a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - replacement: The replacement value, a `CollectionType` value to be encoded and inserted
     *   - options: Optional `ReplaceOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `EventLoopFuture` containing an `UpdateResult`, or containing `nil` if the write concern is
     *            unacknowledged.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    public func replaceOne(
        filter: Document,
        replacement: CollectionType,
        options: ReplaceOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<UpdateResult?> {
        let modelOptions = ReplaceOneModelOptions(collation: options?.collation, upsert: options?.upsert)
        let model = WriteModel.replaceOne(filter: filter, replacement: replacement, options: modelOptions)
        return self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            .flatMapThrowing { try UpdateResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to a matching document
     *   - options: Optional `UpdateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `EventLoopFuture` containing an `UpdateResult`, or containing `nil` if the write concern is
     *            unacknowledged.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func updateOne(
        filter: Document,
        update: Document,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<UpdateResult?> {
        let modelOptions = UpdateModelOptions(
            arrayFilters: options?.arrayFilters,
            collation: options?.collation,
            upsert: options?.upsert
        )
        let model: WriteModel<CollectionType> = .updateOne(filter: filter, update: update, options: modelOptions)
        return self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            .flatMapThrowing { try UpdateResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to matching documents
     *   - options: Optional `UpdateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `EventLoopFuture` containing an `UpdateResult`, or containing `nil` if the write concern is
     *            unacknowledged.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func updateMany(
        filter: Document,
        update: Document,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<UpdateResult?> {
        let modelOptions = UpdateModelOptions(
            arrayFilters: options?.arrayFilters,
            collation: options?.collation,
            upsert: options?.upsert
        )
        let model: WriteModel<CollectionType> = .updateMany(filter: filter, update: update, options: modelOptions)
        return self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            .flatMapThrowing { try UpdateResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `EventLoopFuture` containing a `DeleteResult`, or containing `nil` if the write concern is
     *            unacknowledged.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func deleteOne(
        _ filter: Document,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<DeleteResult?> {
        let modelOptions = DeleteModelOptions(collation: options?.collation)
        let model: WriteModel<CollectionType> = .deleteOne(filter, options: modelOptions)
        return self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            .flatMapThrowing { try DeleteResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }

    /**
     * Deletes multiple documents
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `EventLoopFuture` containing a `DeleteResult`, or containing `nil` if the write concern is
     *            unacknowledged.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func deleteMany(
        _ filter: Document,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<DeleteResult?> {
        let modelOptions = DeleteModelOptions(collation: options?.collation)
        let model: WriteModel<CollectionType> = .deleteMany(filter, options: modelOptions)
        return self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            .flatMapThrowing { try DeleteResult(from: $0) }
            .flatMapErrorThrowing { throw convertBulkWriteError($0) }
    }
}

/// Protocol indicating that an options type can be converted to a BulkWriteOptions.
private protocol BulkWriteOptionsConvertible {
    var bypassDocumentValidation: Bool? { get }
    var writeConcern: WriteConcern? { get }
    func asBulkWriteOptions() -> BulkWriteOptions
}

/// Default implementation of the protocol.
private extension BulkWriteOptionsConvertible {
    func asBulkWriteOptions() -> BulkWriteOptions {
        return BulkWriteOptions(
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
    public var arrayFilters: [Document]?

    /// If true, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public var collation: Document?

    /// When true, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional WriteConcern to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        arrayFilters: [Document]? = nil,
        bypassDocumentValidation: Bool? = nil,
        collation: Document? = nil,
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
    public var collation: Document?

    /// When true, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        bypassDocumentValidation: Bool? = nil,
        collation: Document? = nil,
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
    public var collation: Document?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing collation to be omitted or optional
    public init(collation: Document? = nil, writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.writeConcern = writeConcern
    }

    /// This is a requirement of the BulkWriteOptionsConvertible protocol.
    /// Since it does not apply to deletions, we just set it to nil.
    internal var bypassDocumentValidation: Bool? { return nil }
}

// Write command results structs

/// The result of an `insertOne` command on a `MongoCollection`.
public struct InsertOneResult: Decodable {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BSON

    internal init?(from result: BulkWriteResult?) throws {
        guard let result = result else {
            return nil
        }
        guard let id = result.insertedIds[0] else {
            throw InternalError(message: "BulkWriteResult missing _id for inserted document")
        }
        self.insertedId = id
    }
}

/// The result of a multi-document insert operation on a `MongoCollection`.
public struct InsertManyResult {
    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the document in `values` to the value of its ID
    public let insertedIds: [Int: BSON]

    /// Internal initializer used for converting from a `BulkWriteResult` optional to an `InsertManyResult` optional.
    internal init?(from result: BulkWriteResult?) {
        guard let result = result else {
            return nil
        }
        self.insertedCount = result.insertedCount
        self.insertedIds = result.insertedIds
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
    public let upsertedId: BSON?

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
            guard let id = result.upsertedIds[0] else {
                throw InternalError(message: "BulkWriteResult missing _id for upserted document")
            }
            self.upsertedId = id
        } else {
            self.upsertedId = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case matchedCount, modifiedCount, upsertedId, upsertedCount
    }
}
