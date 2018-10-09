import libmongoc

/// An extension of `MongoCollection` encapsulating write operations.
extension MongoCollection {
    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it.
     *
     * - Parameters:
     *   - value: A `CollectionType` value to encode and insert
     *   - options: Optional `InsertOneOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to perform the insert. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func insertOne(_ value: CollectionType, options: InsertOneOptions? = nil) throws -> InsertOneResult? {
        let encoder = BsonEncoder()
        let document = try encoder.encode(value)
        if !document.hasKey("_id") {
            try ObjectId().encode(to: document.storage, forKey: "_id")
        }
        let opts = try encoder.encode(options)
        var error = bson_error_t()
        if !mongoc_collection_insert_one(self._collection, document.data, opts?.data, nil, &error) {
            // TODO SWIFT-139: include writeErrors and writeConcernErrors from reply in the error
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return InsertOneResult(insertedId: document["_id"])
    }

    /**
     * Encodes the provided values to BSON and inserts them. If any values are
     * missing identifiers, the driver will generate them.
     *
     * - Parameters:
     *   - values: The `CollectionType` values to insert
     *   - options: optional `InsertManyOptions` to use while executing the operation
     *
     * - Returns: an `InsertManyResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.invalidArgument` if `values` is empty
     *   - `MongoError.insertManyError` if any error occurs while performing the writes
     */
    @discardableResult
    public func insertMany(_ values: [CollectionType], options: InsertManyOptions? = nil) throws -> InsertManyResult? {
        if values.isEmpty {
            throw MongoError.invalidArgument(message: "values cannot be empty")
        }

        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let documents = try values.map { try encoder.encode($0) }
        var insertedIds: [Int: BsonValue?] = [:]

        try documents.enumerated().forEach { (index, document) in
            if !document.keys.contains("_id") {
                try ObjectId().encode(to: document.storage, forKey: "_id")
            }
            insertedIds[index] = document["_id"]
        }

        var docPointers = documents.map { UnsafePointer($0.data) }
        let reply = Document()
        var error = bson_error_t()

        let success = mongoc_collection_insert_many(self._collection, &docPointers, values.count, opts?.data, reply.data, &error)
        let result = try InsertManyResult(reply: reply, insertedIds: insertedIds)
        let isAcknowledged = self.isAcknowledged(options?.writeConcern)

        guard success else {
            throw MongoError.insertManyError(code: error.code, message: toErrorString(error),
                                            result: (isAcknowledged ? result : nil),
                                            writeErrors: result.writeErrors,
                                            writeConcernError: result.writeConcernError)
        }

        return isAcknowledged ? result : nil
    }

    /**
     * Replaces a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - replacement: The replacement value, a `CollectionType` value to be encoded and inserted
     *   - options: Optional `ReplaceOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to replace a document. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func replaceOne(filter: Document, replacement: CollectionType,
                           options: ReplaceOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let replacementDoc = try encoder.encode(replacement)
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_replace_one(
            self._collection, filter.data, replacementDoc.data, opts?.data, reply.data, &error) {
            // TODO SWIFT-139: include writeErrors and writeConcernError from reply in the error
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try BsonDecoder().decode(UpdateResult.self, from: reply)
    }

    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to a matching document
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to update a document. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func updateOne(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_update_one(
            self._collection, filter.data, update.data, opts?.data, reply.data, &error) {
            // TODO SWIFT-139: include writeErrors and writeConcernError from reply in the error
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try BsonDecoder().decode(UpdateResult.self, from: reply)
    }

    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to matching documents
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to update multiple documents. If the write
     *            concern is unacknowledged, nil is returned
     */
    @discardableResult
    public func updateMany(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_update_many(
            self._collection, filter.data, update.data, opts?.data, reply.data, &error) {
            // TODO SWIFT-139: include writeErrors and writeConcernErrors from reply in the error
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try BsonDecoder().decode(UpdateResult.self, from: reply)
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func deleteOne(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_delete_one(
            self._collection, filter.data, opts?.data, reply.data, &error) {
             // TODO SWIFT-139: include writeErrors and writeConcernErrors from reply in the error
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try BsonDecoder().decode(DeleteResult.self, from: reply)
    }

    /**
     * Deletes multiple documents
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func deleteMany(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_delete_many(
            self._collection, filter.data, opts?.data, reply.data, &error) {
            // TODO SWIFT-139: include writeErrors and writeConcernErrors from reply in the error
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try BsonDecoder().decode(DeleteResult.self, from: reply)
    }

    /**
     * Returns whether the operation's write concern is acknowledged. If `nil`,
     * the collection's write concern will be considered.
     *
     * - Parameters:
     *   - writeConcern: `WriteConcern` from the operation's options struct
     *
     * - Returns: Whether the operation will use an acknowledged write concern
     */
    fileprivate func isAcknowledged(_ writeConcern: WriteConcern?) -> Bool {
        /* If the collection's write concern is also `nil` it is the default. We
         * can safely assume it is acknowledged, since the server requires that
         * getLastErrorDefaults is acknowledged by at least one member. */
        guard let wc = writeConcern ?? self.writeConcern else {
            return true
        }

        return wc.isAcknowledged
    }
}

// Write command options structs

/// Options to use when executing an `insertOne` command on a `MongoCollection`.
public struct InsertOneOptions: Encodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// An optional WriteConcern to use for the command.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing bypassDocumentValidation to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a multi-document insert operation on a `MongoCollection`.
public struct InsertManyOptions: Encodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /**
     * If true, when an insert fails, return without performing the remaining
     * writes. If false, when a write fails, continue with the remaining writes,
     * if any. Defaults to true.
     */
    public let ordered: Bool

    /// An optional WriteConcern to use for the command.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, ordered: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.ordered = ordered ?? true
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing an `update` command on a `MongoCollection`. 
public struct UpdateOptions: Encodable {
    /// A set of filters specifying to which array elements an update should apply.
    public let arrayFilters: [Document]?

    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional WriteConcern to use for the command.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(arrayFilters: [Document]? = nil, bypassDocumentValidation: Bool? = nil, collation: Document? = nil,
                upsert: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.arrayFilters = arrayFilters
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `replace` command on a `MongoCollection`. 
public struct ReplaceOptions: Encodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(bypassDocumentValidation: Bool? = nil, collation: Document? = nil, upsert: Bool? = nil,
                writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `delete` command on a `MongoCollection`. 
public struct DeleteOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

     /// Convenience initializer allowing collation to be omitted or optional
    public init(collation: Document? = nil, writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.writeConcern = writeConcern
    }
}

// Write command results structs

/// The result of an `insertOne` command on a `MongoCollection`. 
public struct InsertOneResult {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BsonValue?
}

/// The result of a multi-document insert operation on a `MongoCollection`.
public struct InsertManyResult {
    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the document in `values` to the value of its ID
    public let insertedIds: [Int: BsonValue?]

    fileprivate var writeErrors: [WriteError] = []
    fileprivate var writeConcernError: WriteConcernError?

    /**
     * Create an `InsertManyResult` from a reply and map of inserted IDs.
     *
     * Note: we forgo using a Decodable initializer because we still need to
     * explicitly add `insertedIds`.
     *
     * - Parameters:
     *   - reply: A `Document` result from `mongoc_collection_insert_many()`
     *   - insertedIds: Map of inserted IDs
     */
    fileprivate init(reply: Document, insertedIds: [Int: BsonValue?]) throws {
        self.insertedCount = reply["insertedCount"] as? Int ?? 0
        self.insertedIds = insertedIds

        if let writeErrors = reply["writeErrors"] as? [Document] {
            self.writeErrors = try writeErrors.map { try BsonDecoder().decode(WriteError.self, from: $0) }
        }

        if let writeConcernErrors = reply["writeConcernErrors"] as? [Document], writeConcernErrors.indices.contains(0) {
            self.writeConcernError = try BsonDecoder().decode(WriteConcernError.self, from: writeConcernErrors[0])
        }
    }
}

/// The result of a `delete` command on a `MongoCollection`. 
public struct DeleteResult: Decodable {
    /// The number of documents that were deleted.
    public let deletedCount: Int
}

/// The result of an `update` operation a `MongoCollection`.
public struct UpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents that were modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: AnyBsonValue?

    /// The number of documents that were upserted.
    public let upsertedCount: Int
}
