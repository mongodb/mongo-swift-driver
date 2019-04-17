import mongoc

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
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` to BSON.
     */
    @discardableResult
    public func insertOne(_ value: CollectionType, options: InsertOneOptions? = nil) throws -> InsertOneResult? {
        let operation = InsertOneOperation(collection: self, value: value, options: options)
        return try operation.execute()
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
     *   - `ServerError.bulkWriteError` if an error occurs while performing any of the writes.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func insertMany(_ values: [CollectionType], options: InsertManyOptions? = nil) throws -> InsertManyResult? {
        guard !values.isEmpty else {
            throw UserError.invalidArgumentError(message: "values cannot be empty")
        }

        let result = try self.bulkWrite(values.map { InsertOneModel($0) }, options: BulkWriteOptions(from: options))
        return InsertManyResult(from: result)
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
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func replaceOne(filter: Document,
                           replacement: CollectionType,
                           options: ReplaceOptions? = nil) throws -> UpdateResult? {
        let operation = UpdateOperation(collection: self,
                                        filter: filter,
                                        update: try self.encoder.encode(replacement),
                                        options: options,
                                        type: .replaceOne)
        return try operation.execute()
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
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateOne(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let operation = UpdateOperation(collection: self,
                                        filter: filter,
                                        update: update,
                                        options: options,
                                        type: .updateOne)
        return try operation.execute()
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
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateMany(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let operation = UpdateOperation(collection: self,
                                        filter: filter,
                                        update: update,
                                        options: options,
                                        type: .updateMany)
        return try operation.execute()
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
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteOne(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let operation = DeleteOperation(collection: self, filter: filter, options: options, type: .deleteOne)
        return try operation.execute()
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
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteMany(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let operation = DeleteOperation(collection: self, filter: filter, options: options, type: .deleteMany)
        return try operation.execute()
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
    internal func isAcknowledged(_ writeConcern: WriteConcern?) -> Bool {
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

// Write command results structs

/// The result of a multi-document insert operation on a `MongoCollection`.
public struct InsertManyResult {
    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the document in `values` to the value of its ID
    public let insertedIds: [Int: BSONValue]

    /// Internal initializer used for converting from a `BulkWriteResult` optional to an `InsertManyResult` optional.
    internal init?(from result: BulkWriteResult?) {
        guard let result = result else {
            return nil
        }

        self.insertedCount = result.insertedCount
        self.insertedIds = result.insertedIds
    }
}
