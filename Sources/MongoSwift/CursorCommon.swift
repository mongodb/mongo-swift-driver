import NIO

/// A protocol describing the common behavior between cursor-like objects in the driver.
internal protocol Cursor {
    /// The decoded type iterated over by the cursor.
    associatedtype T: Codable

    /**
     * Get the next `T` from the cursor.
     *
     * If this cursor is tailable, this method will continue retrying until a non-empty batch is returned or the cursor
     * is closed
     */
    func next() -> EventLoopFuture<T?>

    /**
     * Attempt to get the next `T` from the cursor, returning nil if there are no results.
     *
     * If this cursor is tailable and `isAlive` is true, this may be called multiple times to attempt to retrieve more
     * elements.
     *
     * If this cursor is a tailable await cursor, the cursor will wait server side for a maximum of `maxAwaitTimeMS`
     * before returning an empty batch. This option can be configured via whatever method generated this
     * cursor (e.g. `watch`).
     */
    func tryNext() -> EventLoopFuture<T?>
}

extension EventLoopFuture {
    /// Run the provided callback after this future succeeds, preserving the succeeded value.
    internal func afterSuccess(f: @escaping (Value) -> EventLoopFuture<Void>) -> EventLoopFuture<Value> {
        return self.flatMap { value in
            f(value).and(value: value)
        }.map { _, value in
            value
        }
    }
}
