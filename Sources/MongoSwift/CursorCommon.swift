import NIO

/// The entity on which the `next` operation is called.
internal enum CursorObject<T: Codable> {
    /// Indicates the `next` call will be on a cursor.
    case cursor(MongoCursor<T>)

    /// Indicates the `next` call will be on a change stream.
    case changeStream(ChangeStream<T>)
}

/// Async equivalents of a few of the standard `Sequence` protocol's methods.
internal protocol AsyncSequence {
    associatedtype Element

    /// Returns the next element in the sequence, or `nil` once the end of the
    /// sequence has been reached.
    func next() -> EventLoopFuture<Element?>

    /// Executes the provided closure for each element in the cursor.
    // func forEach(body: @escaping (Result<Element, Error>) -> Void)

    /// Returns all of the elements in this cursor.
    func all() -> EventLoopFuture<[Element]>
}
