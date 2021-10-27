#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)
/// Extension to `MongoCollection` to support async/await write APIs.
extension MongoCollection {
    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be generated
     * for it.
     *
     * - Parameters:
     *   - value: A `CollectionType` value to encode and insert.
     *   - options: Optional `InsertOneOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An `InsertOneResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` to BSON.
     */
    @discardableResult
    public func insertOne(
        _ value: CollectionType,
        options: InsertOneOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> InsertOneResult? {
        try await self.insertOne(value, options: options, session: session).get()
    }

    /**
     * Encodes the provided values to BSON and inserts them. If any values are missing identifiers, the driver will
     * generate them.
     *
     * - Parameters:
     *   - values: The `CollectionType` values to insert.
     *   - options: optional `InsertManyOptions` to use while executing the operation.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An `InsertManyResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.BulkWriteError` if an error occurs while performing any of the writes.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func insertMany(
        _ values: [CollectionType],
        options: InsertManyOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> InsertManyResult? {
        try await self.insertMany(values, options: options, session: session).get()
    }

    /**
     * Replaces a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria.
     *   - replacement: The replacement value, a `CollectionType` value to be encoded and inserted.
     *   - options: Optional `ReplaceOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An `UpdateResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func replaceOne(
        filter: BSONDocument,
        replacement: CollectionType,
        options: ReplaceOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> UpdateResult? {
        try await self.replaceOne(
            filter: filter,
            replacement: replacement,
            options: options,
            session: session
        )
        .get()
    }

    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria.
     *   - update: A `BSONDocument` representing the update to be applied to a matching document.
     *   - options: Optional `UpdateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An `UpdateResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateOne(
        filter: BSONDocument,
        update: BSONDocument,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> UpdateResult? {
        try await self.updateOne(
            filter: filter,
            update: update,
            options: options,
            session: session
        )
        .get()
    }

    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria.
     *   - pipeline: A `[BSONDocument]` representing the aggregation pipeline to be applied to a matching document.
     *   - options: Optional `UpdateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An `UpdateResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateOne(
        filter: BSONDocument,
        pipeline: [BSONDocument],
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> UpdateResult? {
        try await self.updateOne(
            filter: filter,
            pipeline: pipeline,
            options: options,
            session: session
        )
        .get()
    }

    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria.
     *   - update: A `BSONDocument` representing the update to be applied to matching documents.
     *   - options: Optional `UpdateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An `UpdateResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateMany(
        filter: BSONDocument,
        update: BSONDocument,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> UpdateResult? {
        try await self.updateMany(
            filter: filter,
            update: update,
            options: options,
            session: session
        )
        .get()
    }

    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria.
     *   - pipeline: A `[BSONDocument]` representing the aggregation pipeline to be applied to matching documents.
     *   - options: Optional `UpdateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An `UpdateResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateMany(
        filter: BSONDocument,
        pipeline: [BSONDocument],
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> UpdateResult? {
        try await self.updateMany(
            filter: filter,
            pipeline: pipeline,
            options: options,
            session: session
        )
        .get()
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` representing the match criteria.
     *   - options: Optional `DeleteOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `DeleteResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteOne(
        _ filter: BSONDocument,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> DeleteResult? {
        try await self.deleteOne(filter, options: options, session: session).get()
    }

    /**
     * Deletes multiple documents
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `DeleteResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteMany(
        _ filter: BSONDocument,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> DeleteResult? {
        try await self.deleteMany(filter, options: options, session: session).get()
    }

    /**
     * Execute multiple write operations.
     *
     * - Parameters:
     *   - requests: a `[WriteModel]` containing the writes to perform.
     *   - options: optional `BulkWriteOptions` to use while executing the operation.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: a `BulkWriteResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if `requests` is empty.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.BulkWriteError` if any error occurs while performing the writes. This includes errors that would
     *     typically be thrown as `RuntimeError`s or `MongoError.CommandError`s elsewhere.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or the options to BSON.
     */
    @discardableResult
    public func bulkWrite(
        _ requests: [WriteModel<T>],
        options: BulkWriteOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> BulkWriteResult? {
        try await self.bulkWrite(requests, options: options, session: session).get()
    }
}
#endif
