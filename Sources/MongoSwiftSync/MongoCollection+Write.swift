import MongoSwift

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
     * - Returns: The optional result of attempting to perform the insert. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
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
    ) throws -> InsertOneResult? {
        return try self.asyncColl.insertOne(value, options: options, session: session?.asyncSession).wait()
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
     * - Returns: an `InsertManyResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `BulkWriteError` if an error occurs while performing any of the writes.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func insertMany(
        _ values: [CollectionType],
        options: InsertManyOptions? = nil,
        session: ClientSession? = nil
    ) throws -> InsertManyResult? {
        return try self.asyncColl.insertMany(values, options: options, session: session?.asyncSession).wait()
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
     * - Returns: The optional result of attempting to replace a document. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func replaceOne(
        filter: Document,
        replacement: CollectionType,
        options: ReplaceOptions? = nil,
        session: ClientSession? = nil
    ) throws -> UpdateResult? {
        return try self.asyncColl.replaceOne(filter: filter,
                                             replacement: replacement,
                                             options: options,
                                             session: session?.asyncSession)
                                            .wait()
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
     * - Returns: The optional result of attempting to update a document. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateOne(
        filter: Document,
        update: Document,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) throws -> UpdateResult? {
        return try self.asyncColl.updateOne(filter: filter,
                                            update: update,
                                            options: options,
                                            session: session?.asyncSession)
                                            .wait()
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
     * - Returns: The optional result of attempting to update multiple documents. If the write
     *            concern is unacknowledged, nil is returned
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateMany(
        filter: Document,
        update: Document,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) throws -> UpdateResult? {
        return try self.asyncColl.updateMany(filter: filter,
                                             update: update,
                                             options: options,
                                             session: session?.asyncSession)
                                            .wait()
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteOne(
        _ filter: Document,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) throws -> DeleteResult? {
        return try self.asyncColl.deleteOne(filter, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Deletes multiple documents
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `WriteError` if an error occurs while performing the command.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteMany(
        _ filter: Document,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) throws -> DeleteResult? {
        return try self.asyncColl.deleteMany(filter, options: options, session: session?.asyncSession).wait()
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
     *   - `InvalidArgumentError` if `requests` is empty.
     *   - `LogicError` if the provided session is inactive.
     *   - `BulkWriteError` if any error occurs while performing the writes. This includes errors that would
     *     typically be thrown as `RuntimeError`s or `CommandError`s elsewhere.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or the options to BSON.
     */
    @discardableResult
    public func bulkWrite(
        _ requests: [WriteModel<T>],
        options: BulkWriteOptions? = nil,
        session: ClientSession? = nil
    ) throws -> BulkWriteResult? {
        return try self.asyncColl.bulkWrite(requests, options: options, session: session?.asyncSession).wait()
    }
}
