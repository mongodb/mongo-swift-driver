import MongoSwift

/// A MongoDB change stream.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
public class ChangeStream<T: Codable>: CursorProtocol {
    private let asyncChangeStream: MongoSwift.ChangeStream<T>

    /// The client this change stream descended from.
    private let client: MongoClient

    internal init(wrapping changeStream: MongoSwift.ChangeStream<T>, client: MongoClient) {
        self.asyncChangeStream = changeStream
        self.client = client
    }

    /// Kills the change stream if it hasn't been killed already.
    deinit {
        self.kill()
    }

    /// The `ResumeToken` associated with the most recent event seen by the change stream.
    public var resumeToken: ResumeToken? {
        self.asyncChangeStream.resumeToken
    }

    /**
     * Indicates whether this change stream has the potential to return more data.
     *
     * This change stream will be dead if `next` returns `nil` or an error. It will also be dead if `tryNext` returns
     * an error, but will still be alive if `tryNext` returns `nil`.
     */
    public func isAlive() -> Bool {
        do {
            return try self.asyncChangeStream.isAlive().wait()
        } catch {
            return false
        }
    }

    /**
     * Get the next `T` from this change stream.
     *
     * This method will block until an event is returned from the server, an error occurred, or the change stream is
     * killed. Each attempt to retrieve results will wait server-side for a maximum of `maxAwaitTimeMS` (specified on
     * the `ChangeStreamOptions` passed  to the method that created this change stream) before making another request.
     *
     * A thread from the pool will be occupied by this method until it returns, so performance degradation is possible
     * if the number of polling change streams is too close to the total number of threads in the thread pool. To
     * configure the total number of threads in the pool, set the `MongoClientOptions.threadPoolSize` option on client
     * creation.
     *
     * - Returns:
     *   A `Result<T, Error>?` containing the next `T` in this change stream or an error if one occurred, or `nil` if
     *   the change stream is exhausted. This method will block until one of those conditions is met, potentially after
     *   multiple requests to the server.
     *
     *   If the result contains an error, it is likely one of the following:
     *     - `CommandError` if an error occurs while fetching more results from the server.
     *     - `LogicError` if this function is called after the change stream has died.
     *     - `LogicError` if this function is called and the session associated with this change stream is inactive.
     *     - `DecodingError` if an error occurs decoding the server's response.
     */
    public func next() -> Result<T, Error>? {
        do {
            guard let result = try self.asyncChangeStream.next().wait() else {
                return nil
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /**
     * Attempt to get the next `T` from this change stream, returning `nil` if there are no results.
     *
     * The change stream will wait server-side for a maximum of `maxAwaitTimeMS` (specified on the
     * `ChangeStreamOptions` passed to the method that created this change stream) before returning `nil`.
     *
     * This method may be called repeatedly while `isAlive` is true to retrieve new data.
     *
     * - Returns:
     *    A `Result<T, Error>?` containing the next `T` in this change stream, an error if one occurred, or `nil` if
     *    there was no data.
     *
     *    If the result is an error, it is likely one of the following:
     *      - `CommandError` if an error occurs while fetching more results from the server.
     *      - `LogicError` if this function is called after the change stream has died.
     *      - `LogicError` if this function is called and the session associated with this change stream is inactive.
     *      - `DecodingError` if an error occurs decoding the server's response.
     */
    public func tryNext() -> Result<T, Error>? {
        do {
            guard let result = try self.asyncChangeStream.tryNext().wait() else {
                return nil
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /**
     * Kill this change stream.
     *
     * This method may be called from another thread safely even if this change stream is blocked retrieving results.
     * This is mainly useful for freeing a thread that the change stream is blocking with a long running operation.
     *
     * This method is automatically called in the `deinit` of `ChangeStream`, so it is not necessary to call it
     * manually.
     *
     * This method will have no effect if the change stream is already dead.
     */
    public func kill() {
        try? self.asyncChangeStream.kill().wait()
    }
}
