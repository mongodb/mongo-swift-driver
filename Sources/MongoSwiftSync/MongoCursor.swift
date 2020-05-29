import MongoSwift

/**
 * A MongoDB cursor.
 *
 * Note that the `next` method blocks until a result is received or the cursor is exhausted, so methods inherited from
 * `Sequence` that iterate over the entire sequence may block indefinitely when used on tailable cursors (e.g.
 * `reduce`).
 *
 * It is safe to `kill(...)` a `MongoCursor` from another thread while it is blocked waiting on results, however.
 */
public class MongoCursor<T: Codable>: CursorProtocol {
    private let asyncCursor: MongoSwift.MongoCursor<T>
    private let client: MongoClient

    /**
     * Indicates whether this cursor has the potential to return more data.
     *
     * This method is mainly useful if this cursor is tailable, since in that case `tryNext` may return more results
     * even after returning `nil`.
     *
     * If this cursor is non-tailable, it will always be dead after either `tryNext` returns `nil` or a
     * non-`DecodingError` error.
     *
     * This cursor will be dead after `next` returns `nil` or a non-`DecodingError` error, regardless of the
     * `MongoCursorType`.
     *
     * This cursor may still be alive after `next` or `tryNext` returns a `DecodingError`.
     */
    public func isAlive() -> Bool {
        do {
            return try self.asyncCursor.isAlive().wait()
        } catch {
            return false
        }
    }

    /// Returns the ID used by the server to track the cursor. `nil` once all results have been fetched from the server.
    public var id: Int64? {
        self.asyncCursor.id
    }

    /// Initializes a new `MongoCursor` instance from an async cursor. Not meant to be instantiated directly by a user.
    internal init(wrapping cursor: MongoSwift.MongoCursor<T>, client: MongoClient) {
        self.asyncCursor = cursor
        self.client = client
    }

    /**
     * Returns a `Result` containing the next `T` in this cursor, an error if one occurred, or `nil` if the cursor is
     * exhausted.
     *
     * If this cursor is tailable, this method will continue polling until a non-empty batch is returned from the server
     * or the cursor is closed.
     *
     * - Returns:
     *   A `Result<T, Error>?` containing the next `T` in this cursor on success, an error if one occurred, or `nil`
     *   if the cursor was exhausted.
     *
     *   On failure, there error returned is likely one of the following:
     *   - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *   - `MongoError.LogicError` if this function is called after the cursor has died.
     *   - `MongoError.LogicError` if this function is called and the session associated with this cursor is inactive.
     *   - `DecodingError` if an error occurs decoding the server's response.
     */
    public func next() -> Result<T, Error>? {
        do {
            return try self.asyncCursor.next().wait().map { .success($0) }
        } catch {
            return .failure(error)
        }
    }

    /**
     * Attempt to get the next `T` from the cursor, returning `nil` if there are no results.
     *
     * If this cursor is tailable, this method may be called repeatedly while `isAlive` is true to retrieve new data.
     *
     * If this cursor is a tailable await cursor, it will wait for results server side for a maximum of `maxAwaitTimeMS`
     * before returning `nil`. This option can be configured via options passed to the method that created this
     * cursor (e.g. the `maxAwaitTimeMS` option on the `FindOptions` passed to `find`).
     *
     * - Returns:
     *   A `Result<T, Error>?` containing the next `T` in this cursor on success, an error if one occurred, or `nil`
     *   if there were no results.
     *
     *   On failure, there error returned is likely one of the following:
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the cursor has died.
     *     - `MongoError.LogicError` if this function is called and the session associated with this cursor is inactive.
     *     - `DecodingError` if an error occurs decoding the server's response.
     */
    public func tryNext() -> Result<T, Error>? {
        do {
            return try self.asyncCursor.tryNext().wait().map { .success($0) }
        } catch {
            return .failure(error)
        }
    }

    /**
     * Returns an array of type `T` from the results of this cursor.
     *
     * If this cursor is tailable, this method will block until the cursor is closed or exhausted.
     *
     * - Returns: an array of type `T`
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *   - `MongoError.LogicError` if this function is called after the cursor has died.
     *   - `MongoError.LogicError` if this function is called and the session associated with this cursor is inactive.
     *   - `DecodingError` if an error occurs decoding the server's response.
     */
    internal func _all() throws -> [T] {
        try self.map {
            switch $0 {
            case let .success(t):
                return t
            case let .failure(error):
                throw error
            }
        }
    }

    /**
     * Kill this cursor.
     *
     * This method may be called from another thread safely even if this cursor is blocked retrieving results. This is
     * mainly useful for freeing a thread that a cursor is blocking via a long running operation.
     *
     * This method is automatically called in the `deinit` of `MongoCursor`, so it is not necessary to call it manually.
     */
    public func kill() {
        // The async cursor `close` method shouldn't ever fail, so we can safely ignore the error.
        try? self.asyncCursor.kill().wait()
    }

    /// Closes the cursor if it hasn't been closed already.
    deinit {
        self.kill()
    }
}
