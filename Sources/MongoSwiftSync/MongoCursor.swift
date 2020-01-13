import MongoSwift

/// A MongoDB cursor.
public class MongoCursor<T: Codable>: Sequence, IteratorProtocol {
    private let asyncCursor: MongoSwift.MongoCursor<T>
    private let client: MongoClient

    /**
     * Indicates whether this cursor has the potential to return more data. This property is mainly useful for
     * tailable cursors, where the cursor may be empty but contain more results later on. For non-tailable cursors,
     * the cursor will always be dead as soon as `next()` returns `nil` or a failed `Result`.
     */
    public var isAlive: Bool {
        return self.asyncCursor.isAlive
    }

    /// Returns the ID used by the server to track the cursor. `nil` once all results have been fetched from the server.
    public var id: Int64? {
        return self.asyncCursor.id
    }

    /**
     * Initializes a new `MongoCursor` instance. Not meant to be instantiated directly by a user. When `forceIO` is
     * true, this initializer will force a connection to the server if one is not already established.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(wrapping cursor: MongoSwift.MongoCursor<T>, client: MongoClient) {
        self.asyncCursor = cursor
        self.client = client
    }

    /// Closes the cursor if it hasn't been closed already.
    deinit {
        try? self.asyncCursor.close().wait()
    }

    /**
     * Returns a `Result` containing the next `T` in this cursor, or an error if one occurred.
     * Returns `nil` if the cursor is exhausted. For tailable cursors,
     * users should also check `isAlive` after this method returns `nil`,
     * to determine if the cursor has the potential to return any more data in the future.
     * - Returns: `nil` if the end of the cursor has been reached, or a `Result`. On success, the
     *   `Result` contains the next `T`, and on failure contains:
     *   - `CommandError` if an error occurs while fetching more results from the server.
     *   - `LogicError` if this function is called after the cursor has died.
     *   - `LogicError` if this function is called and the session associated with this cursor is inactive.
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
     * Returns an array of type `T` from this cursor.
     * - Returns: an array of type `T`
     * - Throws:
     *   - `CommandError` if an error occurs while fetching more results from the server.
     *   - `LogicError` if this function is called after the cursor has died.
     *   - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *   - `DecodingError` if an error occurs decoding the server's response.
     */
    public func all() throws -> [T] {
        return try self.map {
            switch $0 {
            case let .success(t):
                return t
            case let .failure(error):
                throw error
            }
        }
    }
}
