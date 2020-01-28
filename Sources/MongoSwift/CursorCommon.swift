import NIO

/// A protocol describing the common behavior between cursor-like objects in the driver.
internal protocol Cursor {
    /// The decoded type iterated over by the cursor.
    associatedtype T: Codable

    /**
     * Indicates whether this cursor has the potential to return more data.
     *
     * This property is mainly useful if this cursor is tailable, since in that case `tryNext` may return more results
     * even after returning `nil`.
     *
     * If this cursor is non-tailable, it will always be dead as soon as either `tryNext` returns `nil` or an error.
     *
     * This cursor will be dead as soon as `next` returns `nil` or an error, regardless of the `CursorType`.
     */
    var isAlive: Bool { get }

    /**
     * Get the next `T` from the cursor.
     *
     * If this cursor is tailable, this method will continue retrying until a non-empty batch is returned or the cursor
     * is closed
     */
    func next() -> EventLoopFuture<T?>

    /**
     * Attempt to get the next `T` from the cursor, returning `nil` if there are no results.
     *
     * If this cursor is tailable and `isAlive` is true, this may be called multiple times to attempt to retrieve more
     * elements.
     *
     * If this cursor is a tailable await cursor, it will wait for results server side for a maximum of `maxAwaitTimeMS`
     * before evaluating to `nil`. This option can be configured via options passed to the method that created this
     * cursor (e.g. the `maxAwaitTimeMS` option on the `FindOptions` passed to `find`).
     */
    func tryNext() -> EventLoopFuture<T?>

    /**
     * Kills this cursor.
     *
     * This method MUST be called before this cursor goes out of scope to prevent leaking resources.
     * This method may be called even if there are unresolved futures created from other `Cursor` methods.
     *
     * This method should not fail.
     */
    func kill() -> EventLoopFuture<Void>
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
