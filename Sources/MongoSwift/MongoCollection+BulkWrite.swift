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
        if requests.isEmpty {
            throw MongoError.invalidArgument(message: "requests cannot be empty")
        }

        let opts = try BsonEncoder().encode(options)
        let bulk = BulkWriteOperation(collection: self._collection, opts: opts?.data)

        try requests.enumerated().forEach { (index, model) in
            try model.addToBulkWrite(bulk: bulk, index: index)
        }

        return try bulk.execute()
    }

    private struct DeleteModelOptions: Encodable {
        public let collation: Document?
    }

    /// A model for a `deleteOne` operation within a bulk write.
    public struct DeleteOneModel: WriteModel {
        private let filter: Document
        private let options: DeleteModelOptions

        /**
         * Create a `deleteOne` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria
         *   - collation: Specifies a collation to use
         */
        public init(_ filter: Document, collation: Document? = nil) {
            self.filter = filter
            self.options = DeleteModelOptions(collation: collation)
        }

        /// Adds the `deleteOne` operation to a bulk write
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let opts = try BsonEncoder().encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_remove_one_with_opts(bulk.bulk, self.filter.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }
        }
    }

    /// A model for a `deleteMany` operation within a bulk write.
    public struct DeleteManyModel: WriteModel {
        private let filter: Document
        private let options: DeleteModelOptions

        /**
         * Create a `deleteMany` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria
         *   - collation: Specifies a collation to use
         */
        public init(_ filter: Document, collation: Document? = nil) {
            self.filter = filter
            self.options = DeleteModelOptions(collation: collation)
        }

        /// Adds the `deleteMany` operation to a bulk write
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let opts = try BsonEncoder().encode(options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_remove_many_with_opts(bulk.bulk, self.filter.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }
        }
    }

    /// A model for an `insertOne` operation within a bulk write.
    public struct InsertOneModel: WriteModel {
        private let document: CollectionType

        /**
         * Create an `insertOne` operation for a bulk write.
         *
         * - Parameters:
         *   - document: The `CollectionType` to insert
         */
        public init(_ document: CollectionType) {
            self.document = document
        }

        /// Adds the `insertOne` operation to a bulk write
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let document = try BsonEncoder().encode(self.document)
            if !document.hasKey("_id") {
                try ObjectId().encode(to: document.storage, forKey: "_id")
            }

            var error = bson_error_t()

            guard mongoc_bulk_operation_insert_with_opts(bulk.bulk, document.data, nil, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }

            bulk.insertedIds[index] = document["_id"]
        }
    }

    private struct ReplaceOneModelOptions: Encodable {
        public let collation: Document?
        public let upsert: Bool?
    }

    /// A model for a `replaceOne` operation within a bulk write.
    public struct ReplaceOneModel: WriteModel {
        private let filter: Document
        private let replacement: CollectionType
        private let options: ReplaceOneModelOptions

        /**
         * Create a `replaceOne` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria
         *   - replacement: The `CollectionType` to use as the replacement value
         *   - collation: Specifies a collation to use
         *   - upsert: When `true`, creates a new document if no document matches the query
         */
        public init(filter: Document, replacement: CollectionType, collation: Document? = nil, upsert: Bool? = nil) {
            self.filter = filter
            self.replacement = replacement
            self.options = ReplaceOneModelOptions(collation: collation, upsert: upsert)
        }

        /// Adds the `replaceOne` operation to a bulk write
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let encoder = BsonEncoder()
            let replacement = try encoder.encode(self.replacement)
            let opts = try encoder.encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_replace_one_with_opts(bulk.bulk, self.filter.data, replacement.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }
        }
    }

    private struct UpdateModelOptions: Encodable {
        public let arrayFilters: [Document]?
        public let collation: Document?
        public let upsert: Bool?
    }

    /// A model for an `updateOne` operation within a bulk write.
    public struct UpdateOneModel: WriteModel {
        private let filter: Document
        private let update: Document
        private let options: UpdateModelOptions

        /**
         * Create an `updateOne` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria
         *   - update: A `Document` containing update operators
         *   - arrayFilters: A set of filters specifying to which array elements an update should apply
         *   - collation: Specifies a collation to use
         *   - upsert: When `true`, creates a new document if no document matches the query
         */
        public init(filter: Document, update: Document, arrayFilters: [Document]? = nil, collation: Document? = nil,
                    upsert: Bool? = nil) {
            self.filter = filter
            self.update = update
            self.options = UpdateModelOptions(arrayFilters: arrayFilters, collation: collation, upsert: upsert)
        }

        /// Adds the `updateOne` operation to a bulk write
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let opts = try BsonEncoder().encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_update_one_with_opts(bulk.bulk, self.filter.data, self.update.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }
        }
    }

    /// A model for an `updateMany` operation within a bulk write.
    public struct UpdateManyModel: WriteModel {
        private let filter: Document
        private let update: Document
        private let options: UpdateModelOptions

        /**
         * Create a `updateMany` operation for a bulk write.
         *
         * - Parameters:
         *   - filter: A `Document` representing the match criteria
         *   - update: A `Document` containing update operators
         *   - arrayFilters: A set of filters specifying to which array elements an update should apply
         *   - collation: Specifies a collation to use
         *   - upsert: When `true`, creates a new document if no document matches the query
         */
        public init(filter: Document, update: Document, arrayFilters: [Document]? = nil, collation: Document? = nil,
                    upsert: Bool? = nil) {
            self.filter = filter
            self.update = update
            self.options = UpdateModelOptions(arrayFilters: arrayFilters, collation: collation, upsert: upsert)
        }

        /// Adds the `updateMany` operation to a bulk write
        public func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws {
            let opts = try BsonEncoder().encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_update_many_with_opts(bulk.bulk, self.filter.data, self.update.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
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
     *   - bulk: A `BulkWriteOperation`
     *   - index: Index of the operation within the `MongoCollection.bulkWrite` `requests` array
     */
    func addToBulkWrite(bulk: BulkWriteOperation, index: Int) throws
}

/// A class encapsulating a `mongoc_bulk_operation_t`.
public class BulkWriteOperation {
    fileprivate var bulk: OpaquePointer?
    fileprivate var insertedIds: [Int: BsonValue?] = [:]

    /// Indicates whether this bulk operation used an acknowledged write concern.
    private var isAcknowledged: Bool {
        let wc = WriteConcern(mongoc_bulk_operation_get_write_concern(self.bulk))
        return wc.isAcknowledged
    }

    /// Initializes the object from a `mongoc_collection_t` and `bson_t`.
    fileprivate init(collection: OpaquePointer?, opts: UnsafePointer<bson_t>?) {
        self.bulk = mongoc_collection_create_bulk_operation_with_opts(collection, opts)!
    }

    /// Executes the bulk write operation and returns a `BulkWriteResult` or
    /// `nil` is the write concern is unacknowledged
    fileprivate func execute() throws -> BulkWriteResult? {
        let reply = Document()
        var error = bson_error_t()

        let serverId = mongoc_bulk_operation_execute(self.bulk, reply.data, &error)
        let result = try BulkWriteResult(reply: reply, insertedIds: self.insertedIds)

        guard serverId != 0 else {
            throw MongoError.bulkWriteError(code: error.code, message: toErrorString(error),
                                            result: (self.isAcknowledged ? result : nil),
                                            writeErrors: result.writeErrors,
                                            writeConcernError: result.writeConcernError)
        }

        return self.isAcknowledged ? result : nil
    }

    deinit {
        guard let bulk = self.bulk else {
            return
        }
        mongoc_bulk_operation_destroy(bulk)
        self.bulk = nil
    }
}

/// Options to use when performing a bulk write operation on a `MongoCollection`.
public struct BulkWriteOptions: Encodable {
    /// If `true`, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /**
     * If `true` (the default), operations will be executed serially in order
     * and a write error will abort execution of the entire bulk write. If
     * `false`, operations may execute in an arbitrary order and execution will
     * not stop after encountering a write error (i.e. multiple errors may be
     * reported after all operations have been attempted).
     */
    public let ordered: Bool

    /// An optional WriteConcern to use for the bulk write.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, ordered: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.ordered = ordered ?? true
        self.writeConcern = writeConcern
    }
}

/// The result of a bulk write operation on a `MongoCollection`.
public struct BulkWriteResult {
    /// Number of documents deleted.
    public let deletedCount: Int

    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the operation to the id of the inserted document.
    public let insertedIds: [Int: BsonValue?]

    /// Number of documents matched for update.
    public let matchedCount: Int

    /// Number of documents modified.
    public let modifiedCount: Int

    /// Number of documents upserted.
    public let upsertedCount: Int

    /// Map of the index of the operation to the id of the upserted document.
    public let upsertedIds: [Int: BsonValue?]

    fileprivate var writeErrors: [WriteError] = []
    fileprivate var writeConcernError: WriteConcernError?

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
     */
    fileprivate init(reply: Document, insertedIds: [Int: BsonValue?]) throws {
        self.deletedCount = reply["nRemoved"] as? Int ?? 0
        self.insertedCount = reply["nInserted"] as? Int ?? 0
        self.insertedIds = insertedIds
        self.matchedCount = reply["nMatched"] as? Int ?? 0
        self.modifiedCount = reply["nModified"] as? Int ?? 0
        self.upsertedCount = reply["nUpserted"] as? Int ?? 0

        var upsertedIds = [Int: BsonValue?]()

        if let upserted = reply["upserted"] as? [Document] {
            for upsert in upserted {
                guard let index = upsert["index"] as? Int else {
                    throw MongoError.typeError(message: "Could not cast upserted index to `Int`")
                }
                upsertedIds[index] = upsert["_id"]
            }
        }

        self.upsertedIds = upsertedIds

        if let writeErrors = reply["writeErrors"] as? [Document] {
            self.writeErrors = try writeErrors.map { try BsonDecoder().decode(WriteError.self, from: $0) }
        }

        if let writeConcernErrors = reply["writeConcernErrors"] as? [Document], writeConcernErrors.indices.contains(0) {
            self.writeConcernError = try BsonDecoder().decode(WriteConcernError.self, from: writeConcernErrors[0])
        }
    }
}

/// A struct to represent a write error resulting from an executed bulk write.
public struct WriteError: Codable {
    /// The index of the request that errored.
    public let index: Int

    /// An integer value identifying the error.
    public let code: Int

    /// A description of the error.
    public let message: String

    private enum CodingKeys: String, CodingKey {
        case index
        case code
        case message = "errmsg"
    }
}

/// A struct to represent a write concern error resulting from an executed bulk write.
public struct WriteConcernError: Codable {
    /// An integer value identifying the write concern error.
    public let code: Int

    /// A document identifying the write concern setting related to the error.
    public let info: Document

    ///  A description of the error.
    public let message: String

    private enum CodingKeys: String, CodingKey {
        case code
        case info = "errInfo"
        case message = "errmsg"
    }
}
