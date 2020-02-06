import MongoSwift

/// An extension of `MongoCollection` encapsulating find and modify operations.
extension MongoCollection {
    /**
     * Finds a single document and deletes it, returning the original.
     *
     * - Parameters:
     *   - filter: `Document` representing the match criteria
     *   - options: Optional `FindOneAndDeleteOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: The deleted document, represented as a `CollectionType`, or `nil` if no document was deleted.
     *
     * - Throws:
     *   - `InvalidArgumentError` if any of the provided options are invalid.
     *   - `LogicError` if the provided session is inactive.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `WriteError` if an error occurs while executing the command.
     *   - `DecodingError` if the deleted document cannot be decoded to a `CollectionType` value.
     */
    @discardableResult
    public func findOneAndDelete(
        _ filter: Document,
        options: FindOneAndDeleteOptions? = nil,
        session: ClientSession? = nil
    ) throws -> CollectionType? {
        return try self.asyncColl.findOneAndDelete(filter, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Finds a single document and replaces it, returning either the original or the replaced document.
     *
     * - Parameters:
     *   - filter: `Document` representing the match criteria
     *   - replacement: a `CollectionType` to replace the found document
     *   - options: Optional `FindOneAndReplaceOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `CollectionType`, representing either the original document or its replacement,
     *      depending on selected options, or `nil` if there was no match.
     *
     * - Throws:
     *   - `InvalidArgumentError` if any of the provided options are invalid.
     *   - `LogicError` if the provided session is inactive.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `WriteError` if an error occurs while executing the command.
     *   - `DecodingError` if the replaced document cannot be decoded to a `CollectionType` value.
     *   - `EncodingError` if `replacement` cannot be encoded to a `Document`.
     */
    @discardableResult
    public func findOneAndReplace(
        filter: Document,
        replacement: CollectionType,
        options: FindOneAndReplaceOptions? = nil,
        session: ClientSession? = nil
    ) throws -> CollectionType? {
        return try self.asyncColl.findOneAndReplace(
            filter: filter,
            replacement: replacement,
            options: options,
            session: session?.asyncSession
        )
        .wait()
    }

    /**
     * Finds a single document and updates it, returning either the original or the updated document.
     *
     * - Parameters:
     *   - filter: `Document` representing the match criteria
     *   - update: a `Document` containing updates to apply
     *   - options: Optional `FindOneAndUpdateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `CollectionType` representing either the original or updated document,
     *      depending on selected options, or `nil` if there was no match.
     *
     * - Throws:
     *   - `InvalidArgumentError` if any of the provided options are invalid.
     *   - `LogicError` if the provided session is inactive.
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `WriteError` if an error occurs while executing the command.
     *   - `DecodingError` if the updated document cannot be decoded to a `CollectionType` value.
     */
    @discardableResult
    public func findOneAndUpdate(
        filter: Document,
        update: Document,
        options: FindOneAndUpdateOptions? = nil,
        session: ClientSession? = nil
    ) throws -> CollectionType? {
        return try self.asyncColl.findOneAndUpdate(
            filter: filter,
            update: update,
            options: options,
            session: session?.asyncSession
        )
        .wait()
    }
}
