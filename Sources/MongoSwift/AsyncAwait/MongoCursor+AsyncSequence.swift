#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)
/// Extension to `MongoCursor` to support async/await APIs.
extension MongoCursor: AsyncSequence, AsyncIteratorProtocol {
    public typealias AsyncIterator = MongoCursor

    public typealias Element = T

    public __consuming func makeAsyncIterator() -> MongoCursor<T> {
        self
    }

    // TODO: SWIFT-1415 Make this a property rather than a method.
    /**
     * Indicates whether this cursor has the potential to return more data.
     *
     * This method is mainly useful if this cursor is tailable, since in that case `tryNext()` may return more results
     * even after returning `nil`.
     *
     * If this cursor is non-tailable, it will always be dead after either `tryNext()` returns `nil` or a
     * non-`DecodingError` error.
     *
     * This cursor will be dead after `next()` returns `nil` or throws a non-`DecodingError` error, regardless of the
     * cursor type.
     *
     * This cursor may still be alive after `next()` or `tryNext()` throws a `DecodingError`.
     */
    public func isAlive() async throws -> Bool {
        try await self.isAlive().get()
    }

    /**
     * Returns the next `T` in this cursor, or `nil` if the cursor is exhausted or the current `Task` is cancelled.
     *
     * If this cursor is tailable, this method will continue polling until a non-empty batch is returned from the
     * server, or until the `Task` it is running in is cancelled.  For this reason, we recommend to run tailable
     * cursors in their own `Task`s, and to terminate the cursor if/when needed by canceling the `Task`.
     *
     * - Warning: You *must not* call any cursor methods besides `isAlive()` while awaiting the result of this method.
     *   Doing so will result in undefined behavior.
     *
     * - Returns:
     *   The next `T` in this cursor, or `nil` if the cursor is exhausted or the current `Task` is cancelled.
     *
     *   If an error is thrown, it is likely one of the following:
     *   - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *   - `MongoError.LogicError` if this function is called after the cursor has been exhausted.
     *   - `MongoError.LogicError` if this function is called and the session associated with this cursor has been
     *         ended.
     *   - `DecodingError` if an error occurs decoding the server's response to a `T`.
     */
    public func next() async throws -> T? {
        while try await self.isAlive() {
            if Task.isCancelled {
                return nil
            }
            if let doc = try await self.tryNext() {
                return doc
            }
            await Task.yield()
        }

        return nil
    }

    /**
     * Attempt to get the next `T` from the cursor, returning `nil` if there are no results.
     *
     * If this cursor is tailable, this method may be called repeatedly while `isAlive()` returns true to retrieve new
     * data.
     *
     * If this cursor is a tailable await cursor, it will wait for results server side for a maximum of `maxAwaitTimeMS`
     * before evaluating to `nil`. This option can be configured via options passed to the method that created this
     * cursor (e.g. the `maxAwaitTimeMS` option on the `FindOptions` passed to `find`).
     *
     * - Warning: You *must not* call any cursor methods besides `isAlive()` while awaiting the result of this method.
     *   Doing so will result in undefined behavior.
     *
     * - Returns:
     *    The next `T` in this cursor, or `nil` if there is no new data.
     *
     *   If an error is thrown, it is likely one of the following:
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the cursor has been exhausted.
     *     - `MongoError.LogicError` if this function is called and the session associated with this cursor has been
     *           ended.
     *     - `DecodingError` if an error occurs decoding the server's response to a `T`.
     */
    public func tryNext() async throws -> T? {
        try await self.tryNext().get()
    }

    /**
     * Consolidate the currently available results of the cursor into an array of type `T`.
     *
     * If this cursor is not tailable, this method will exhaust it.
     *
     * If this cursor is tailable, `toArray` will only fetch the currently available results, and it
     * may return more data if it is called again while the cursor is still alive.
     *
     * - Warning: You *must not* call any cursor methods besides `isAlive()` while awaiting the result of this method.
     *   Doing so will result in undefined behavior.
     *
     * - Returns:
     *    An `T` containing the results currently available in this cursor.
     *
     *   If an error is thrown, it is likely one of the following:
     *      - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *      - `MongoError.LogicError` if this function is called after the cursor has been exhausted.
     *      - `MongoError.LogicError` if this function is called and the session associated with this cursor has been
     *        ended.
     *      - `DecodingError` if an error occurs decoding the server's responses to `T`s.
     */
    public func toArray() async throws -> [T] {
        try await self.toArray().get()
    }
}
#endif
