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
        let bulk = mongoc_collection_create_bulk_operation_with_opts(self._collection, opts?.data)!
        defer { mongoc_bulk_operation_destroy(bulk) }

        var insertedIds = [Int: BsonValue?]()

        for (index, model) in requests.enumerated() {
            switch model {
            case let deleteOrUpdate as DeleteOrUpdateWriteModel:
                try deleteOrUpdate.addToBulkWrite(bulk: bulk)

            case let insert as InsertOneModel:
                insertedIds[index] = try insert.addToBulkWrite(bulk: bulk)

            default:
                let type = Swift.type(of: model)
                throw MongoError.invalidArgument(message: "Unsupported operation in requests[\(index)]: \(type)")
            }
        }

        let reply = Document()
        var error = bson_error_t()

        if mongoc_bulk_operation_execute(bulk, reply.data, &error) == 0 {
            // TODO: Throw MongoError.bulkWriteError with unpacked errors and attached BulkWriteResult
            throw MongoError.commandError(message: toErrorString(error))
        }

        return BulkWriteResult(reply: reply, insertedIds: insertedIds)
    }

    private struct DeleteModelOptions: Encodable {
        public let collation: Document?
    }

    /// A model for a `deleteOne` operation within a bulk write.
    public struct DeleteOneModel: DeleteOrUpdateWriteModel {
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
        fileprivate func addToBulkWrite(bulk: OpaquePointer) throws {
            let opts = try BsonEncoder().encode(options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_remove_one_with_opts(bulk, filter.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }
        }
    }

    /// A model for a `deleteMany` operation within a bulk write.
    public struct DeleteManyModel: DeleteOrUpdateWriteModel {
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
        fileprivate func addToBulkWrite(bulk: OpaquePointer) throws {
            let opts = try BsonEncoder().encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_remove_many_with_opts(bulk, filter.data, opts.data, &error) else {
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

        /// Adds the `insertOne` operation to a bulk write and returns its `_id`
        fileprivate func addToBulkWrite(bulk: OpaquePointer) throws -> BsonValue? {
            let encoder = BsonEncoder()

            let document = try encoder.encode(self.document)
            if !document.keys.contains("_id") {
                try ObjectId().encode(to: document.storage, forKey: "_id")
            }

            var error = bson_error_t()

            guard mongoc_bulk_operation_insert_with_opts(bulk, document.data, nil, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }

            return document["_id"]
        }
    }

    private struct ReplaceOneModelOptions: Encodable {
        public let collation: Document?
        public let upsert: Bool?
    }

    /// A model for a `replaceOne` operation within a bulk write.
    public struct ReplaceOneModel: DeleteOrUpdateWriteModel {
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
        fileprivate func addToBulkWrite(bulk: OpaquePointer) throws {
            let encoder = BsonEncoder()
            let replacement = try encoder.encode(self.replacement)
            let opts = try encoder.encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_replace_one_with_opts(bulk, filter.data, replacement.data, opts.data, &error) else {
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
    public struct UpdateOneModel: DeleteOrUpdateWriteModel {
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
        fileprivate func addToBulkWrite(bulk: OpaquePointer) throws {
            let opts = try BsonEncoder().encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_update_one_with_opts(bulk, filter.data, update.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }
        }
    }

    /// A model for an `updateMany` operation within a bulk write.
    public struct UpdateManyModel: DeleteOrUpdateWriteModel {
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
        fileprivate func addToBulkWrite(bulk: OpaquePointer) throws {
            let opts = try BsonEncoder().encode(self.options)
            var error = bson_error_t()

            guard mongoc_bulk_operation_update_many_with_opts(bulk, filter.data, update.data, opts.data, &error) else {
                throw MongoError.invalidArgument(message: toErrorString(error))
            }
        }
    }
}

/// A protocol indicating write operations that can be batched together using `MongoCollection.bulkWrite`.
public protocol WriteModel {}

private protocol DeleteOrUpdateWriteModel: WriteModel {
    func addToBulkWrite(bulk: OpaquePointer) throws
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
    public init(bypassDocumentValidation: Bool? = nil, ordered: Bool = true, writeConcern: WriteConcern? = nil) {
        self.ordered = ordered
        self.bypassDocumentValidation = bypassDocumentValidation
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

    /**
     * Create a BulkWriteResult operation from a reply and map of inserted IDs.
     *
     * Note: we forgo using a Decodable initializer because we still need to
     * build a map for `upsertedIds` and explicitly add `insertedIds`.
     *
     * - Parameters:
     *   - reply: A `Document` result from `mongoc_bulk_operation_execute()`
     *   - insertedIds: Map of inserted IDs
     */
    fileprivate init(reply: Document, insertedIds: [Int: BsonValue?]) {
        self.deletedCount = reply["nRemoved"] as! Int
        self.insertedCount = reply["nInserted"] as! Int
        self.insertedIds = insertedIds
        self.matchedCount = reply["nMatched"] as! Int
        self.modifiedCount = reply["nModified"] as! Int
        self.upsertedCount = reply["nUpserted"] as! Int

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
    }
}
