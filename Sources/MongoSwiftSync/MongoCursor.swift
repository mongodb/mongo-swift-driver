import MongoSwift

/// A MongoDB cursor.
public class MongoCursor<T: Codable>: Sequence, IteratorProtocol {
    /// The error that occurred while iterating this cursor, if one exists. This should be used to check for errors
    /// after `next()` returns `nil`.
    public var error: Error? { fatalError("unimplemented") }

    /**
     * Indicates whether this cursor has the potential to return more data. This property is mainly useful for
     * tailable cursors, where the cursor may be empty but contain more results later on. For non-tailable cursors,
     * the cursor will always be dead as soon as `next()` returns `nil`, or as soon as `nextOrError()` returns `nil` or
     * throws an error.
     */
    public var isAlive: Bool { fatalError("unimplemented") }

    /// Returns the ID used by the server to track the cursor. `nil` until mongoc actually talks to the server by
    /// iterating the cursor, and `nil` after mongoc has fetched all the results from the server.
    public var id: Int64? { fatalError("unimplemented") }

    /**
     * Initializes a new `MongoCursor` instance. Not meant to be instantiated directly by a user. When `forceIO` is
     * true, this initializer will force a connection to the server if one is not already established.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(wrapping cursor: MongoSwift.MongoCursor<T>) throws {
        fatalError("unimplemented")
    }

    /// Closes the cursor if it hasn't been closed already.
    deinit {
        fatalError("unimplemented")
    }

    /**
     * Returns the next `Document` in this cursor or `nil`, or throws an error if one occurs -- compared to `next()`,
     * which returns `nil` and requires manually checking for an error afterward.
     * - Returns: the next `Document` in this cursor, or `nil` if at the end of the cursor
     * - Throws:
     *   - `CommandError` if an error occurs on the server while iterating the cursor.
     *   - `LogicError` if this function is called after the cursor has died.
     *   - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *   - `DecodingError` if an error occurs decoding the server's response.
     */
    public func nextOrError() throws -> T? {
        fatalError("unimplemented")
    }

    /// Returns the next `Document` in this cursor, or `nil`. After this function returns `nil`, the caller should use
    /// the `.error` property to check for errors. For tailable cursors, users should also check `isAlive` after this
    /// method returns `nil`, to determine if the cursor has the potential to return any more data in the future.
    public func next() -> T? {
        fatalError("unimplemented")
    }
}
