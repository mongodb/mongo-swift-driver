#if compiler(>=5.5) && canImport(_Concurrency)
/// Extension to `MongoCollection` to support async/await APIs.
@available(macOS 10.15.0, *)
extension MongoCollection {
    /**
     * Drops this collection from its parent database.
     * - Parameters:
     *   - options: An optional `DropCollectionOptions` to use when executing this command.
     *   - session: An optional `ClientSession` to use when executing this command.
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     */
    public func drop(options: DropCollectionOptions? = nil, session: ClientSession? = nil) async throws {
        try await self.drop(options: options, session: session).get()
    }

    /**
     * Renames this collection on the server. This method will return a handle to the renamed collection. The handle
     * which this method is invoked on will continue to refer to the old collection, which will then be empty.
     * The server will throw an error if the new name matches an existing collection unless the `dropTarget` option
     * is set to true.
     *
     * Note: This method is not supported on sharded collections.
     *
     * - Parameters:
     *   - to: A `String`, the new name for the collection.
     *   - options: Optional `RenameCollectionOptions` to use for the collection.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns:
     *    A copy of the target `MongoCollection` with the new name.
     *
     *    Throws:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func renamed(
        to newName: String,
        options: RenameCollectionOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> MongoCollection {
        try await self.renamed(to: newName, options: options, session: session).get()
    }
}
#endif
