import mongoc

/// An extension of `MongoCollection` encapsulating bulk write operations.
extension MongoCollection {
    /**
     * Execute multiple write operations.
     *
     * - Parameters:
     *   - requests: a `[WriteModel]` containing the writes to perform.
     *   - options: optional `BulkWriteOptions` to use while executing the operation.
     *
     * - Returns: a `BulkWriteResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if `requests` is empty.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `ServerError.bulkWriteError` if any error occurs while performing the writes.
     *   - `ServerError.commandError` if an error occurs that prevents the operation from being performed.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or the options to BSON.
     */
    @discardableResult
    public func bulkWrite(_ requests: [WriteModel],
                          options: BulkWriteOptions? = nil,
                          session: ClientSession? = nil) throws -> BulkWriteResult? {
        guard !requests.isEmpty else {
            throw UserError.invalidArgumentError(message: "requests cannot be empty")
        }

        let opts = try encodeOptions(options: options, session: session)
        let bulk = BulkWriteOperation(collection: self._collection, opts: opts, withEncoder: self.encoder)

        try requests.enumerated().forEach { index, model in
            try model.addToBulkWrite(bulk: bulk, index: index)
        }

        return try bulk.execute()
    }

    private struct DeleteModelOptions: Encodable {
        public let collation: Document?
    }

    /// A model for a `deleteOne` operation within a bulk write.
    public struct DeleteOneModel: WriteModel, Decodable {
        /// A `Document` representing the match criteria.
        public let filter: Document

        /// The collation to use.
        public let collation: Document?

        /**
         * Create a `deleteOne` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria.
         *   - collation: Specifies a collation to use.
         */
        public init(_ filter: Document, collation: Document? = nil) {
            self.filter = filter
            self.collation = collation
        }

        /**
         * Adds the `deleteOne` operation to a bulk write.
         *
         * - Throws:
         *   - `UserError.invalidArgumentError` if the options form an invalid combination.
         *   - `EncodingError` if an error occurs while encoding the options to BSON.
         */
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let opts = try bulk.encoder.encode(DeleteModelOptions(collation: self.collation))
            var error = bson_error_t()

            guard mongoc_bulk_operation_remove_one_with_opts(
                bulk.bulk, self.filter._bson, opts._bson, &error) else {
                throw parseMongocError(error) // Should be invalidArgumentError
            }
        }
    }

    /// A model for a `deleteMany` operation within a bulk write.
    public struct DeleteManyModel: WriteModel, Decodable {
        /// A `Document` representing the match criteria.
        public let filter: Document

        /// The collation to use.
        public let collation: Document?

        /**
         * Create a `deleteMany` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria.
         *   - collation: Specifies a collation to use.
         */
        public init(_ filter: Document, collation: Document? = nil) {
            self.filter = filter
            self.collation = collation
        }

        /**
         * Adds the `deleteMany` operation to a bulk write.
         *
         * - Throws:
         *   - `UserError.invalidArgumentError` if the options form an invalid combination.
         *   - `EncodingError` if an error occurs while encoding the options to BSON.
         */
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            var error = bson_error_t()
            let opts = try bulk.encoder.encode(DeleteModelOptions(collation: self.collation))

            guard mongoc_bulk_operation_remove_many_with_opts(bulk.bulk, self.filter._bson, opts._bson, &error) else {
                throw parseMongocError(error) // should be invalidArgumentError
            }
        }
    }

    /// A model for an `insertOne` operation within a bulk write.
    public struct InsertOneModel: WriteModel, Decodable {
        /// The `CollectionType` to insert.
        public let document: CollectionType

        /**
         * Create an `insertOne` operation for a bulk write.
         *
         * - Parameters:
         *   - document: The `CollectionType` to insert.
         */
        public init(_ document: CollectionType) {
            self.document = document
        }

        /**
         * Adds the `insertOne` operation to a bulk write.
         *
         * - Throws:
         *   - `EncodingError` if an error occurs while encoding the `CollectionType` to BSON.
         *   - `UserError.invalidArgumentError` if the options form an invalid combination.
         */
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let document = try bulk.encoder.encode(self.document).withID()
            var error = bson_error_t()
            guard mongoc_bulk_operation_insert_with_opts(bulk.bulk, document._bson, nil, &error) else {
                throw parseMongocError(error) // should be invalidArgumentError
            }

            guard let insertedId = try document.getValue(for: "_id") else {
                // we called `withID()`, so this should be present.
                fatalError("Failed to get value for _id from document")
            }

            bulk.insertedIds[index] = insertedId
        }
    }

    private struct ReplaceOneModelOptions: Encodable {
        public let collation: Document?
        public let upsert: Bool?
    }

    /// A model for a `replaceOne` operation within a bulk write.
    public struct ReplaceOneModel: WriteModel, Decodable {
        /// A `Document` representing the match criteria.
        public let filter: Document

        /// The `CollectionType` to use as the replacement value.
        public let replacement: CollectionType

        /// The collation to use.
        public let collation: Document?

        /// When `true`, creates a new document if no document matches the query.
        public let upsert: Bool?

        /**
         * Create a `replaceOne` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria.
         *   - replacement: The `CollectionType` to use as the replacement value.
         *   - collation: Specifies a collation to use.
         *   - upsert: When `true`, creates a new document if no document matches the query.
         */
        public init(filter: Document, replacement: CollectionType, collation: Document? = nil, upsert: Bool? = nil) {
            self.filter = filter
            self.replacement = replacement
            self.collation = collation
            self.upsert = upsert
        }

        /**
         * Adds the `replaceOne` operation to a bulk write.
         *
         * - Throws:
         *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
         *   - `UserError.invalidArgumentError` if the options form an invalid combination.
         */
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let replacement = try bulk.encoder.encode(self.replacement)
            let opts = try bulk.encoder.encode(ReplaceOneModelOptions(collation: self.collation, upsert: self.upsert))
            var error = bson_error_t()

            guard mongoc_bulk_operation_replace_one_with_opts(bulk.bulk,
                                                              self.filter._bson,
                                                              replacement._bson,
                                                              opts._bson,
                                                              &error) else {
                throw parseMongocError(error) // should be invalidArgumentError
            }
        }
    }

    private struct UpdateModelOptions: Encodable {
        public let arrayFilters: [Document]?
        public let collation: Document?
        public let upsert: Bool?
    }

    /// A model for an `updateOne` operation within a bulk write.
    public struct UpdateOneModel: WriteModel, Decodable {
        /// A `Document` representing the match criteria.
        public let filter: Document

        /// A `Document` containing update operators.
        public let update: Document

        /// A set of filters specifying to which array elements an update should apply.
        public let arrayFilters: [Document]?

        /// A collation to use.
        public let collation: Document?

        /// When `true`, creates a new document if no document matches the query.
        public let upsert: Bool?

        /**
         * Create an `updateOne` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria.
         *   - update: A `Document` containing update operators.
         *   - arrayFilters: A set of filters specifying to which array elements an update should apply.
         *   - collation: Specifies a collation to use.
         *   - upsert: When `true`, creates a new document if no document matches the query.
         */
        public init(filter: Document,
                    update: Document,
                    arrayFilters: [Document]? = nil,
                    collation: Document? = nil,
                    upsert: Bool? = nil) {
            self.filter = filter
            self.update = update
            self.arrayFilters = arrayFilters
            self.collation = collation
            self.upsert = upsert
        }

        /**
         * Adds the `updateOne` operation to a bulk write.
         *
         * - Throws:
         *   - `EncodingError` if an error occurs while encoding the options to BSON.
         *   - `UserError.invalidArgumentError` if the options form an invalid combination.
         */
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let opts = try bulk.encoder.encode(UpdateModelOptions(arrayFilters: self.arrayFilters,
                                                                  collation: self.collation,
                                                                  upsert: self.upsert))
            var error = bson_error_t()

            guard mongoc_bulk_operation_update_one_with_opts(bulk.bulk,
                                                             self.filter._bson,
                                                             self.update._bson,
                                                             opts._bson,
                                                             &error) else {
                throw parseMongocError(error) // should be invalidArgumentError
            }
        }
    }

    /// A model for an `updateMany` operation within a bulk write.
    public struct UpdateManyModel: WriteModel, Decodable {
        /// A `Document` representing the match criteria.
        public let filter: Document

        /// A `Document` containing update operators.
        public let update: Document

        /// A set of filters specifying to which array elements an update should apply.
        public let arrayFilters: [Document]?

        /// A collation to use.
        public let collation: Document?

        /// When `true`, creates a new document if no document matches the query.
        public let upsert: Bool?

        /**
         * Create a `updateMany` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria.
         *   - update: A `Document` containing update operators.
         *   - arrayFilters: A set of filters specifying to which array elements an update should apply.
         *   - collation: Specifies a collation to use.
         *   - upsert: When `true`, creates a new document if no document matches the query.
         */
        public init(filter: Document,
                    update: Document,
                    arrayFilters: [Document]? = nil,
                    collation: Document? = nil,
                    upsert: Bool? = nil) {
            self.filter = filter
            self.update = update
            self.arrayFilters = arrayFilters
            self.collation = collation
            self.upsert = upsert
        }

        /**
         * Adds the `updateMany` operation to a bulk write.
         *
         * - Throws:
         *   - `EncodingError` if an error occurs while encoding the options to BSON.
         *   - `UserError.invalidArgumentError` if the options form an invalid combination.
         */
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let opts = try bulk.encoder.encode(UpdateModelOptions(arrayFilters: self.arrayFilters,
                                                                  collation: self.collation,
                                                                  upsert: self.upsert))
            var error = bson_error_t()

            guard mongoc_bulk_operation_update_many_with_opts(bulk.bulk,
                                                              self.filter._bson,
                                                              self.update._bson,
                                                              opts._bson,
                                                              &error) else {
                throw parseMongocError(error) // should be invalidArgumentError
            }
        }
    }
}

/// A protocol indicating write operations that can be batched together using `MongoCollection.bulkWrite`.
public protocol WriteModel {
    /**
     * Adds the operation to a bulk write.
     *
     * The `index` argument denotes the operation's order within the bulk write
     * and should match its index within the `requests` array parameter for
     * `MongoCollection.bulkWrite`.
     *
     * - Parameters:
     *   - bulk: A `BulkWriteOperation`.
     *   - index: Index of the operation within the `MongoCollection.bulkWrite` `requests` array.
     */
    func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws
}

/// A class encapsulating a `mongoc_bulk_operation_t`.
public class BulkWriteOperation: Operation {
    fileprivate var bulk: OpaquePointer?
    fileprivate var insertedIds: [Int: BSONValue] = [:]

    internal let opts: Document?

    /// Encoder from the `MongoCollection` this operation is derived from.
    internal let encoder: BSONEncoder

    /// Indicates whether this bulk operation used an acknowledged write concern.
    private var isAcknowledged: Bool {
        let wc = WriteConcern(from: mongoc_bulk_operation_get_write_concern(self.bulk))
        return wc.isAcknowledged
    }

    /// Initializes the object from a `mongoc_collection_t` and `bson_t`.
    fileprivate init(collection: OpaquePointer?, opts: Document?, withEncoder: BSONEncoder) {
        // documented as always returning a value.
        // swiftlint:disable:next force_unwrapping
        self.bulk = mongoc_collection_create_bulk_operation_with_opts(collection, opts?._bson)!
        self.opts = opts
        self.encoder = withEncoder
    }

    /**
     * Executes the bulk write operation and returns a `BulkWriteResult` or
     * `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `ServerError.commandError` if an error occurs that prevents the operation from executing.
     *   - `ServerError.bulkWriteError` if an error occurs while performing the writes.
     */
    internal func execute() throws -> BulkWriteResult? {
        var reply = Document()
        var error = bson_error_t()
        let serverId = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_bulk_operation_execute(self.bulk, replyPtr, &error)
        }

        let result = try BulkWriteResult(reply: reply, insertedIds: self.insertedIds)

        guard serverId != 0 else {
            throw getErrorFromReply(
                    bsonError: error,
                    from: reply,
                    forBulkWrite: self,
                    withResult: self.isAcknowledged ? result : nil)
        }

        return self.isAcknowledged ? result : nil
    }

    /// Cleans up internal state.
    deinit {
        guard let bulk = self.bulk else {
            return
        }
        mongoc_bulk_operation_destroy(bulk)
        self.bulk = nil
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
    public let insertedIds: [Int: BSONValue]

    /// Number of documents matched for update.
    public let matchedCount: Int

    /// Number of documents modified.
    public let modifiedCount: Int

    /// Number of documents upserted.
    public let upsertedCount: Int

    /// Map of the index of the operation to the id of the upserted document.
    public let upsertedIds: [Int: BSONValue]

    private enum CodingKeys: CodingKey {
        case deletedCount, insertedCount, insertedIds, matchedCount, modifiedCount, upsertedCount, upsertedIds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // None of the results must be present themselves, but at least one must.
        guard !container.allKeys.isEmpty else {
            throw DecodingError.valueNotFound(BulkWriteResult.self,
                                              DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "No results found"))
        }

        self.deletedCount = try container.decodeIfPresent(Int.self, forKey: .deletedCount) ?? 0
        self.matchedCount = try container.decodeIfPresent(Int.self, forKey: .matchedCount) ?? 0
        self.modifiedCount = try container.decodeIfPresent(Int.self, forKey: .modifiedCount) ?? 0

        let insertedIds =
                (try container.decodeIfPresent([Int: AnyBSONValue].self, forKey: .insertedIds) ?? [:])
                        .mapValues { $0.value }
        self.insertedIds = insertedIds
        self.insertedCount = try container.decodeIfPresent(Int.self, forKey: .insertedCount) ?? insertedIds.count

        let upsertedIds =
                (try container.decodeIfPresent([Int: AnyBSONValue].self, forKey: .upsertedIds) ?? [:])
                        .mapValues { $0.value }
        self.upsertedIds = upsertedIds
        self.upsertedCount = try container.decodeIfPresent(Int.self, forKey: .upsertedCount) ?? upsertedIds.count
    }

    /**
     * Create a `BulkWriteResult` from a reply and map of inserted IDs.
     *
     * Note: we forgo using a Decodable initializer because we still need to
     * build a map for `upsertedIds` and explicitly add `insertedIds`. While
     * `mongoc_bulk_operation_execute()` guarantees that `reply` will be
     * initialized, it doesn't guarantee that all fields will be set. On error,
     * we should expect fields to be missing and handle that gracefully.
     *
     * - Parameters:
     *   - reply: A `Document` result from `mongoc_bulk_operation_execute()`
     *   - insertedIds: Map of inserted IDs
     *
     * - Throws:
     *   - `RuntimeError.internalError` if an unexpected error occurs reading the reply from the server.
     */
    fileprivate init(reply: Document, insertedIds: [Int: BSONValue]) throws {
        // These values are converted to Int via BSONNumber because they're returned from libmongoc as BSON int32s,
        // which are retrieved from documents as Ints on 32-bit systems and Int32s on 64-bit ones. To retrieve them in a
        // cross-platform manner, we must convert them this way. Also, regardless of how they are stored in the
        // we want to use them as Ints.
        self.deletedCount = (try reply.getValue(for: "nRemoved") as? BSONNumber)?.intValue ?? 0
        self.insertedCount = (try reply.getValue(for: "nInserted") as? BSONNumber)?.intValue ?? 0
        self.insertedIds = insertedIds
        self.matchedCount = (try reply.getValue(for: "nMatched") as? BSONNumber)?.intValue ?? 0
        self.modifiedCount = (try reply.getValue(for: "nModified") as? BSONNumber)?.intValue ?? 0
        self.upsertedCount = (try reply.getValue(for: "nUpserted") as? BSONNumber)?.intValue ?? 0

        var upsertedIds = [Int: BSONValue]()

        if let upserted = try reply.getValue(for: "upserted") as? [Document] {
            for upsert in upserted {
                guard let index = (try upsert.getValue(for: "index") as? BSONNumber)?.intValue else {
                    throw RuntimeError.internalError(message: "Could not cast upserted index to `Int`")
                }
                upsertedIds[index] = upsert["_id"]
            }
        }

        self.upsertedIds = upsertedIds
    }

    /// Internal initializer used for testing purposes and error handling.
    internal init(
            deletedCount: Int? = nil,
            insertedCount: Int? = nil,
            insertedIds: [Int: BSONValue]? = nil,
            matchedCount: Int? = nil,
            modifiedCount: Int? = nil,
            upsertedCount: Int? = nil,
            upsertedIds: [Int: BSONValue]? = nil) {
        self.deletedCount = deletedCount ?? 0
        self.insertedCount = insertedCount ?? 0
        self.insertedIds = insertedIds ?? [:]
        self.matchedCount = matchedCount ?? 0
        self.modifiedCount = modifiedCount ?? 0
        self.upsertedCount = upsertedCount ?? 0
        self.upsertedIds = upsertedIds ?? [:]
    }
}
