#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)
/// Extension to `MongoCollection` to support async/await find and modify APIs.
extension MongoCollection {
    /**
     * Finds a single document and deletes it, returning the original.
     *
     * - Parameters:
     *   - filter: a `BSONDocument` representing the match criteria.
     *   - options: Optional `FindOneAndDeleteOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: The deleted document, represented as a `CollectionType`, or `nil` if no document was deleted.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if any of the provided options are invalid.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.WriteError` if an error occurs while executing the command.
     *   - `DecodingError` if the deleted document cannot be decoded to a `CollectionType` value.
     */
    @discardableResult
    public func findOneAndDelete(
        _ filter: BSONDocument,
        options: FindOneAndDeleteOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> CollectionType? {
        try await self.findOneAndDelete(filter, options: options, session: session).get()
    }

    /**
     * Finds a single document and replaces it, returning either the original or the replaced document.
     *
     * - Parameters:
     *   - filter: a `BSONDocument` representing the match criteria.
     *   - replacement: a `CollectionType` to replace the found document.
     *   - options: Optional `FindOneAndReplaceOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `CollectionType`, representing either the original document or its replacement,
     *      depending on selected options, or `nil` if there was no match.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if any of the provided options are invalid.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.WriteError` if an error occurs while executing the command.
     *   - `DecodingError` if the replaced document cannot be decoded to a `CollectionType` value.
     *   - `EncodingError` if `replacement` cannot be encoded to a `BSONDocument`.
     */
    @discardableResult
    public func findOneAndReplace(
        filter: BSONDocument,
        replacement: CollectionType,
        options: FindOneAndReplaceOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> CollectionType? {
        try await self.findOneAndReplace(
            filter: filter,
            replacement: replacement,
            options: options,
            session: session
        )
        .get()
    }

    /**
     * Finds a single document and updates it, returning either the original or the updated document.
     *
     * - Parameters:
     *   - filter: a `BSONDocument` representing the match criteria.
     *   - update: a `BSONDocument` containing updates to apply.
     *   - options: Optional `FindOneAndUpdateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `CollectionType` representing either the original or updated document,
     *      depending on selected options, or `nil` if there was no match.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if any of the provided options are invalid.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.WriteError` if an error occurs while executing the command.
     *   - `DecodingError` if the updated document cannot be decoded to a `CollectionType` value.
     */
    @discardableResult
    public func findOneAndUpdate(
        filter: BSONDocument,
        update: BSONDocument,
        options: FindOneAndUpdateOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> CollectionType? {
        try await self.findOneAndUpdate(
            filter: filter,
            update: update,
            options: options,
            session: session
        )
        .get()
    }

    /**
     * Finds a single document and updates it, returning either the original or the updated document.
     *
     * - Parameters:
     *   - filter: a `BSONDocument` representing the match criteria.
     *   - pipeline: an array of `BSONDocument` containing the aggregation pipeline to apply.
     *   - options: Optional `FindOneAndUpdateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `CollectionType` representing either the original or updated document,
     *      depending on selected options, or `nil` if there was no match.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if any of the provided options are invalid.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.WriteError` if an error occurs while executing the command.
     *   - `DecodingError` if the updated document cannot be decoded to a `CollectionType` value.
     */
    @discardableResult
    public func findOneAndUpdate(
        filter: BSONDocument,
        pipeline: [BSONDocument],
        options: FindOneAndUpdateOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> CollectionType? {
        try await self.findOneAndUpdate(
            filter: filter,
            pipeline: pipeline,
            options: options,
            session: session
        )
        .get()
    }
}
#endif
