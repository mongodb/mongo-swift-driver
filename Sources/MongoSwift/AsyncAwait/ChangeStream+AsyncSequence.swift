#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)
/// Extension to `ChangeStream` to support async/await APIs.
extension ChangeStream: AsyncSequence, AsyncIteratorProtocol {
    public typealias AsyncIterator = ChangeStream

    public __consuming func makeAsyncIterator() -> ChangeStream<T> {
        self
    }

    // TODO: SWIFT-1415 Make this a property rather than a method.
    /**
     * Indicates whether this change stream has the potential to return more data.
     *
     * This change stream will be dead after `next()` returns `nil`, but it may still be alive after `tryNext()`
     * returns `nil`.
     *
     * After either of `next()` or `tryNext()` throw a non-`DecodingError` error, this change stream will be dead.
     *  It may still be alive after either returns a `DecodingError`, however.
     */
    public func isAlive() async throws -> Bool {
        try await self.isAlive().get()
    }

    /**
     * Get the next `T` from this change stream.
     *
     * This method will continue polling until an event is returned from the server, an error occurs,
     * or the current `Task` is cancelled. Each attempt to retrieve results will wait for a maximum of `maxAwaitTimeMS`
     * (specified on the `ChangeStreamOptions` passed to the method that created this change stream) before trying
     * again.
     *
     * We recommend to run change streams in their own `Task`s, and to terminate them by cancelling their `Task`s.
     *
     * - Note: a thread from the driver's internal thread pool will be occupied until the returned future is completed,
     *   so performance degradation is possible if the number of polling change streams is too close to the total
     *   number of threads in the thread pool. To configure the total number of threads in the pool, set the
     *   `MongoClientOptions.threadPoolSize` option during client creation.
     *
     * - Warning: You *must not* call any change stream methods besides `isAlive()` while awaiting the result of this
     *    method. Doing so will result in undefined behavior.
     *
     * - Returns:
     *   The next `T` in this change stream, or `nil` if the change stream is exhausted or the current `Task` is
     *   cancelled. This method will not return until one of those conditions is met, potentially after multiple
     *   requests to the server.
     *
     *   If an error is thrown, it is likely one of the following:
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the change stream has been exhausted.
     *     - `MongoError.LogicError` if this function is called and the session associated with this change stream has
     *       been ended.
     *     - `DecodingError` if an error occurs decoding the server's response to a `T`.
     */
    public func next() async throws -> T? {
        while try await self.isAlive() {
            if Task.isCancelled {
                return nil
            }
            if let doc = try await self.tryNext() {
                return doc
            }
        }

        return nil
    }

    /**
     * Attempt to get the next `T` from the change stream, returning `nil` if there are no results.
     *
     * The change stream will wait server-side for a maximum of `maxAwaitTimeMS` (specified on the
     * `ChangeStreamOptions` passed to the method that created this change stream) before returning `nil`.
     *
     * This method may be called repeatedly while `isAlive()` is true to retrieve new data.
     *
     * - Warning: You *must not* call any change stream methods besides `isAlive()` while awaiting the result of this
     *   method. Doing so will result in undefined behavior.
     *
     * - Returns:
     *    The next `T` in this change stream, or `nil` if there is no new data.
     *
     *   If an error is thrown, it is likely one of the following:
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the change stream has been exhausted.
     *     - `MongoError.LogicError` if this function is called and the session associated with this change stream has
     *           been ended.
     *     - `DecodingError` if an error occurs decoding the server's response to a `T`.
     */
    public func tryNext() async throws -> T? {
        try await self.tryNext().get()
    }

    /**
     * Consolidate the currently available results of the change stream into an array of type `T`.
     *
     * Since `toArray` will only fetch the currently available results, it may return more data if it is called again
     * while the change stream is still alive.
     *
     * - Warning: You *must not* call any change stream methods besides `isAlive()` while awaiting the result of this
     *    method. Doing so will result in undefined behavior.
     *
     * - Returns:
     *    An `T` containing the results currently available in this change stream.
     *
     *   If an error is thrown, it is likely one of the following:
     *      - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *      - `MongoError.LogicError` if this function is called after the change stream has been exhausted.
     *      - `MongoError.LogicError` if this function is called and the session associated with this change stream has
     *         been ended.
     *      - `DecodingError` if an error occurs decoding the server's responses to `T`s.
     */
    public func toArray() async throws -> [T] {
        try await self.toArray().get()
    }
}
#endif
