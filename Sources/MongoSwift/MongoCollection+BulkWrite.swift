import CLibMongoC
import NIO

/// An extension of `MongoCollection` encapsulating bulk write operations.
extension MongoCollection {
    /**
     * Execute multiple write operations.
     *
     * - Parameters:
     *   - requests: a `[WriteModel]` containing the writes to perform.
     *   - options: optional `BulkWriteOptions` to use while executing the operation.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<BulkWriteResult?>`. On success, the future contains either a `BulkWriteResult`, or
     *    contains `nil` if the write concern is unacknowledged.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `InvalidArgumentError` if `requests` is empty.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `BulkWriteError` if any error occurs while performing the writes. This includes errors that would
     *       typically be propagated as `RuntimeError`s or `CommandError`s elsewhere.
     *    - `EncodingError` if an error occurs while encoding the `CollectionType` or the options to BSON.
     */
    public func bulkWrite(
        _ requests: [WriteModel<T>],
        options: BulkWriteOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<BulkWriteResult?> {
        guard !requests.isEmpty else {
            return self._client.operationExecutor
                .makeFailedFuture(InvalidArgumentError(message: "requests cannot be empty"))
        }
        let operation = BulkWriteOperation(collection: self, models: requests, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }
}

/// Enum encompassing operations that can be run as part of a `bulkWrite`.
public enum WriteModel<CollectionType: Codable> {
    /// A `deleteOne`.
    /// Parameters:
    /// - A `BSONDocument` representing the match criteria.
    /// - `options`: Optional `DeleteModelOptions`.
    case deleteOne(BSONDocument, options: DeleteModelOptions? = nil)
    /// A `deleteMany`.
    /// Parameters:
    /// - A `BSONDocument` representing the match criteria.
    /// - `options`: Optional `DeleteModelOptions`.
    case deleteMany(BSONDocument, options: DeleteModelOptions? = nil)
    /// An `insertOne`.
    /// Parameters:
    /// - A `T` to insert.
    case insertOne(CollectionType)
    /// A `replaceOne`.
    /// Parameters:
    /// - `filter`: A `BSONDocument` representing the match criteria.
    /// - `replacement`: A `T` to use as the replacement value.
    /// - `options`: Optional `ReplaceOneModelOptions`.
    case replaceOne(filter: BSONDocument, replacement: CollectionType, options: ReplaceOneModelOptions? = nil)
    /// An `updateOne`.
    /// Parameters:
    /// - `filter`: A `BSONDocument` representing the match criteria.
    /// - `update`: A `BSONDocument` containing update operators.
    /// - `options`: Optional `UpdateModelOptions`.
    case updateOne(filter: BSONDocument, update: BSONDocument, options: UpdateModelOptions? = nil)
    /// An `updateMany`.
    /// Parameters:
    /// - `filter`: A `BSONDocument` representing the match criteria.
    /// - `update`: A `BSONDocument` containing update operators.
    /// - `options`: Optional `UpdateModelOptions`.
    case updateMany(filter: BSONDocument, update: BSONDocument, options: UpdateModelOptions? = nil)

    /// Adds this model to the provided `mongoc_bulk_t`, using the provided encoder for encoding options and
    /// `CollectionType` values if needed. If this is an `insertOne`, returns the `_id` field of the inserted
    /// document; otherwise, returns nil.
    fileprivate func addToBulkWrite(_ bulk: OpaquePointer, encoder: BSONEncoder) throws -> BSON? {
        var error = bson_error_t()
        let success: Bool
        var res: BSON?
        switch self {
        case let .deleteOne(filter, options):
            let opts = try encoder.encode(options)
            success = filter.withBSONPointer { filterPtr in
                withOptionalBSONPointer(to: opts) { optsPtr in
                    mongoc_bulk_operation_remove_one_with_opts(bulk, filterPtr, optsPtr, &error)
                }
            }

        case let .deleteMany(filter, options):
            let opts = try encoder.encode(options)
            success = filter.withBSONPointer { filterPtr in
                withOptionalBSONPointer(to: opts) { optsPtr in
                    mongoc_bulk_operation_remove_many_with_opts(bulk, filterPtr, optsPtr, &error)
                }
            }

        case let .insertOne(value):
            let document = try encoder.encode(value).withID()
            success = document.withBSONPointer { docPtr in
                mongoc_bulk_operation_insert_with_opts(bulk, docPtr, nil, &error)
            }

            guard let insertedID = try document.getValue(for: "_id") else {
                // we called `withID()`, so this should be present.
                fatalError("Failed to get value for _id from document")
            }
            res = insertedID

        case let .replaceOne(filter, replacement, options):
            let replacement = try encoder.encode(replacement)
            let opts = try encoder.encode(options)
            success = filter.withBSONPointer { filterPtr in
                replacement.withBSONPointer { replacementPtr in
                    withOptionalBSONPointer(to: opts) { optsPtr in
                        mongoc_bulk_operation_replace_one_with_opts(bulk, filterPtr, replacementPtr, optsPtr, &error)
                    }
                }
            }

        case let .updateOne(filter, update, options):
            let opts = try encoder.encode(options)
            success = filter.withBSONPointer { filterPtr in
                update.withBSONPointer { updatePtr in
                    withOptionalBSONPointer(to: opts) { optsPtr in
                        mongoc_bulk_operation_update_one_with_opts(bulk, filterPtr, updatePtr, optsPtr, &error)
                    }
                }
            }

        case let .updateMany(filter, update, options):
            let opts = try encoder.encode(options)
            success = filter.withBSONPointer { filterPtr in
                update.withBSONPointer { updatePtr in
                    withOptionalBSONPointer(to: opts) { optsPtr in
                        mongoc_bulk_operation_update_many_with_opts(bulk, filterPtr, updatePtr, optsPtr, &error)
                    }
                }
            }
        }

        guard success else {
            throw extractMongoError(error: error) // should be invalidArgumentError
        }

        return res
    }
}

/// Options to use with a `WriteModel.deleteOne` or `WriteModel.deleteMany`.
public struct DeleteModelOptions: Codable {
    /// The collation to use.
    public var collation: BSONDocument?

    /// Initializer allowing any/all options to be omitted or optional.
    public init(collation: BSONDocument? = nil) {
        self.collation = collation
    }
}

/// Options to use with a `WriteModel.replaceOne`.
public struct ReplaceOneModelOptions: Codable {
    /// The collation to use.
    public var collation: BSONDocument?
    /// When `true`, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// Initializer allowing any/all options to be omitted or optional.
    public init(collation: BSONDocument? = nil, upsert: Bool? = nil) {
        self.collation = collation
        self.upsert = upsert
    }
}

/// Options to use with a `WriteModel.updateOne` or `WriteModel.updateMany`.
public struct UpdateModelOptions: Codable {
    /// A set of filters specifying to which array elements an update should apply.
    public var arrayFilters: [BSONDocument]?
    /// The collation to use.
    public var collation: BSONDocument?
    /// When `true`, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// Initializer allowing any/all options to be omitted or optional.
    public init(arrayFilters: [BSONDocument]? = nil, collation: BSONDocument? = nil, upsert: Bool? = nil) {
        self.arrayFilters = arrayFilters
        self.collation = collation
        self.upsert = upsert
    }
}

/// An operation corresponding to a "bulkWrite" command on a collection.
internal struct BulkWriteOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let models: [WriteModel<T>]
    internal let options: BulkWriteOptions?

    fileprivate let encoder: BSONEncoder

    fileprivate init(collection: MongoCollection<T>, models: [WriteModel<T>], options: BulkWriteOptions?) {
        self.collection = collection
        self.models = models
        self.options = options
        self.encoder = collection.encoder
    }

    /**
     * Executes the bulk write operation and returns a `BulkWriteResult` or
     * `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `CommandError` if an error occurs that prevents the operation from executing.
     *   - `BulkWriteError` if an error occurs while performing the writes.
     */
    internal func execute(using connection: Connection, session: ClientSession?) throws -> BulkWriteResult? {
        let opts = try encodeOptions(options: options, session: session)
        var insertedIDs: [Int: BSON] = [:]

        if session?.inTransaction == true && self.options?.writeConcern != nil {
            throw InvalidArgumentError(
                message: "Cannot specify a write concern on an individual helper in a " +
                    "transaction. Instead specify it when starting the transaction."
            )
        }

        return try self.collection.withMongocCollection(from: connection) { collPtr in
            let bulk: OpaquePointer = withOptionalBSONPointer(to: opts) { optsPtr in
                guard let bulk = mongoc_collection_create_bulk_operation_with_opts(collPtr, optsPtr) else {
                    fatalError("failed to initialize mongoc_bulk_operation_t")
                }
                return bulk
            }
            defer { mongoc_bulk_operation_destroy(bulk) }

            try self.models.enumerated().forEach { index, model in
                if let res = try model.addToBulkWrite(bulk, encoder: self.encoder) {
                    insertedIDs[index] = res
                }
            }

            var error = bson_error_t()
            let (serverID, reply) = withStackAllocatedMutableBSONPointer { replyPtr -> (UInt32, BSONDocument) in
                let serverID = mongoc_bulk_operation_execute(bulk, replyPtr, &error)
                let reply = BSONDocument(copying: replyPtr)
                return (serverID, reply)
            }

            var writeConcernAcknowledged: Bool
            if session?.inTransaction == true {
                // Bulk write operations in transactions must get their write concern from the session, not from
                // the `BulkWriteOptions` passed to the `bulkWrite` helper. `libmongoc` surfaces this
                // implementation detail by nulling out the write concern stored on the bulk write. To sidestep
                // this, we can only call `mongoc_bulk_operation_get_write_concern` out of a transaction.
                //
                // In a transaction, default to writeConcernAcknowledged = true. This is acceptable because
                // transactions do not support unacknowledged writes.
                writeConcernAcknowledged = true
            } else {
                let writeConcern = WriteConcern(copying: mongoc_bulk_operation_get_write_concern(bulk))
                writeConcernAcknowledged = writeConcern.isAcknowledged
            }

            let result: BulkWriteResult? = writeConcernAcknowledged
                ? try BulkWriteResult(reply: reply, insertedIDs: insertedIDs)
                : nil

            guard serverID != 0 else {
                throw extractBulkWriteError(
                    for: self,
                    error: error,
                    reply: reply,
                    partialResult: result
                )
            }

            return result
        }
    }
}

/// Options to use when performing a bulk write operation on a `MongoCollection`.
public struct BulkWriteOptions: Codable {
    /// If `true`, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /**
     * If `true` (the default), operations will be executed serially in order
     * and a write error will abort execution of the entire bulk write. If
     * `false`, operations may execute in an arbitrary order and execution will
     * not stop after encountering a write error (i.e. multiple errors may be
     * reported after all operations have been attempted).
     */
    public var ordered: Bool

    /// An optional WriteConcern to use for the bulk write.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, ordered: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.ordered = ordered ?? true
        self.writeConcern = writeConcern
    }

    /// Internal initializer used to convert an `InsertManyOptions` optional to a `BulkWriteOptions` optional.
    internal init?(from insertManyOptions: InsertManyOptions?) {
        guard let options = insertManyOptions else {
            return nil
        }

        self.bypassDocumentValidation = options.bypassDocumentValidation
        self.ordered = options.ordered
        self.writeConcern = options.writeConcern
    }
}

/// The result of a bulk write operation on a `MongoCollection`.
public struct BulkWriteResult: Decodable {
    /// Number of documents deleted.
    public let deletedCount: Int

    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the operation to the id of the inserted document.
    public let insertedIDs: [Int: BSON]

    /// Number of documents matched for update.
    public let matchedCount: Int

    /// Number of documents modified.
    public let modifiedCount: Int

    /// Number of documents upserted.
    public let upsertedCount: Int

    /// Map of the index of the operation to the id of the upserted document.
    public let upsertedIDs: [Int: BSON]

    private enum CodingKeys: String, CodingKey {
        case deletedCount,
            insertedCount,
            insertedIDs = "insertedIds",
            matchedCount,
            modifiedCount,
            upsertedCount,
            upsertedIDs = "upsertedIds"
    }

    // The key names libmongoc uses for its bulk write results.
    private enum MongocKeys: String {
        case deletedCount = "nRemoved"
        case insertedCount = "nInserted"
        case matchedCount = "nMatched"
        case modifiedCount = "nModified"
        case upsertedCount = "nUpserted"
        case upserted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // None of the results must be present themselves, but at least one must.
        guard !container.allKeys.isEmpty else {
            throw DecodingError.valueNotFound(
                BulkWriteResult.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "No results found"
                )
            )
        }

        self.deletedCount = try container.decodeIfPresent(Int.self, forKey: .deletedCount) ?? 0
        self.matchedCount = try container.decodeIfPresent(Int.self, forKey: .matchedCount) ?? 0
        self.modifiedCount = try container.decodeIfPresent(Int.self, forKey: .modifiedCount) ?? 0

        let insertedIDs = try container.decodeIfPresent([Int: BSON].self, forKey: .insertedIDs) ?? [:]
        self.insertedIDs = insertedIDs
        self.insertedCount = try container.decodeIfPresent(Int.self, forKey: .insertedCount) ?? insertedIDs.count

        let upsertedIDs = try container.decodeIfPresent([Int: BSON].self, forKey: .upsertedIDs) ?? [:]
        self.upsertedIDs = upsertedIDs
        self.upsertedCount = try container.decodeIfPresent(Int.self, forKey: .upsertedCount) ?? upsertedIDs.count
    }

    /**
     * Create a `BulkWriteResult` from a reply and map of inserted IDs.
     *
     * Note: we forgo using a Decodable initializer because we still need to
     * build a map for `upsertedIDs` and explicitly add `insertedIDs`, and because
     * libmongoc uses a different naming convention for the field names than is expected.
     *
     * While `mongoc_bulk_operation_execute()` guarantees that `reply` will be
     * initialized, it doesn't guarantee that all fields will be set. On error,
     * we should expect fields to be missing and handle that gracefully.
     *
     * - Parameters:
     *   - reply: A `BSONDocument` result from `mongoc_bulk_operation_execute()`
     *   - insertedIDs: Map of inserted IDs
     *
     * - Throws:
     *   - `InternalError` if an unexpected error occurs reading the reply from the server.
     */
    fileprivate init?(reply: BSONDocument, insertedIDs: [Int: BSON]) throws {
        guard reply.keys.contains(where: { MongocKeys(rawValue: $0) != nil }) else {
            return nil
        }

        self.deletedCount = try reply.getValue(for: MongocKeys.deletedCount.rawValue)?.toInt() ?? 0
        self.insertedCount = try reply.getValue(for: MongocKeys.insertedCount.rawValue)?.toInt() ?? 0
        self.insertedIDs = insertedIDs
        self.matchedCount = try reply.getValue(for: MongocKeys.matchedCount.rawValue)?.toInt() ?? 0
        self.modifiedCount = try reply.getValue(for: MongocKeys.modifiedCount.rawValue)?.toInt() ?? 0
        self.upsertedCount = try reply.getValue(for: MongocKeys.upsertedCount.rawValue)?.toInt() ?? 0

        var upsertedIDs = [Int: BSON]()

        if let upserted = try reply.getValue(for: MongocKeys.upserted.rawValue)?.arrayValue {
            guard let upserted = upserted.toArrayOf(BSONDocument.self) else {
                throw InternalError(message: "\"upserted\" array did not contain only documents")
            }

            for upsert in upserted {
                guard let index = try upsert.getValue(for: "index")?.toInt() else {
                    throw InternalError(message: "Could not cast upserted index to `Int`")
                }
                upsertedIDs[index] = upsert["_id"]
            }
        }

        self.upsertedIDs = upsertedIDs
    }

    /// Internal initializer used for testing purposes and error handling.
    internal init(
        deletedCount: Int? = nil,
        insertedCount: Int? = nil,
        insertedIDs: [Int: BSON]? = nil,
        matchedCount: Int? = nil,
        modifiedCount: Int? = nil,
        upsertedCount: Int? = nil,
        upsertedIDs: [Int: BSON]? = nil
    ) {
        self.deletedCount = deletedCount ?? 0
        self.insertedCount = insertedCount ?? 0
        self.insertedIDs = insertedIDs ?? [:]
        self.matchedCount = matchedCount ?? 0
        self.modifiedCount = modifiedCount ?? 0
        self.upsertedCount = upsertedCount ?? 0
        self.upsertedIDs = upsertedIDs ?? [:]
    }
}
