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
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` to BSON.
     */
    @discardableResult
    public func insertOne(
        _ value: CollectionType,
        options: InsertOneOptions? = nil,
        session: ClientSession? = nil
    ) throws -> InsertOneResult? {
        fatalError("unimplemented")
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
     *   - `ServerError.bulkWriteError` if an error occurs while performing any of the writes.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func insertMany(
        _ values: [CollectionType],
        options: InsertManyOptions? = nil,
        session: ClientSession? = nil
    ) throws -> InsertManyResult? {
        fatalError("unimplemented")
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
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func replaceOne(
        filter: Document,
        replacement: CollectionType,
        options: ReplaceOptions? = nil,
        session: ClientSession? = nil
    ) throws -> UpdateResult? {
        fatalError("unimplemented")
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
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateOne(
        filter: Document,
        update: Document,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) throws -> UpdateResult? {
        fatalError("unimplemented")
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
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateMany(
        filter: Document,
        update: Document,
        options: UpdateOptions? = nil,
        session: ClientSession? = nil
    ) throws -> UpdateResult? {
        fatalError("unimplemented")
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
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteOne(
        _ filter: Document,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) throws -> DeleteResult? {
        fatalError("unimplemented")
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
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteMany(
        _ filter: Document,
        options: DeleteOptions? = nil,
        session: ClientSession? = nil
    ) throws -> DeleteResult? {
        fatalError("unimplemented")
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
     *   - `UserError.invalidArgumentError` if `requests` is empty.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `ServerError.bulkWriteError` if any error occurs while performing the writes. This includes errors that would
     *     typically be thrown as `RuntimeError`s or `ServerError.commandError`s elsewhere.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or the options to BSON.
     */
    @discardableResult
    public func bulkWrite(
        _ requests: [WriteModel<T>],
        options: BulkWriteOptions? = nil,
        session: ClientSession? = nil
    ) throws -> BulkWriteResult? {
        fatalError("unimplemented")
    }
}
