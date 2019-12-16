import MongoSwift

/// A MongoDB change stream.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
public class ChangeStream<T: Codable>: Sequence, IteratorProtocol {
    /// A `ResumeToken` associated with the most recent event seen by the change stream.
    public var resumeToken: ResumeToken? { fatalError("unimplemented") }

    /// The error that occurred while iterating the change stream, if one exists. This should be used to check
    /// for errors after `next()` returns `nil`.
    public var error: Error? { fatalError("unimplemented") }

    /**
     * Initializes a `ChangeStream`.
     * - Throws:
     *   - `CommandError` if an error occurred on the server when creating the `mongoc_change_stream_t`.
     *   - `InvalidArgumentError` if the `mongoc_change_stream_t` was created with invalid options.
     */
    internal init(wrapping changeStream: MongoSwift.ChangeStream<T>) throws {
        fatalError("unimplemented")
    }

    /// Closes the change stream if it hasn't been closed already.
    deinit {
        fatalError("unimplemented")
    }

    /// Returns the next `T` in the change stream or nil if there is no next value. Will block for a maximum of
    /// `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout
    /// if omitted.
    public func next() -> T? {
        fatalError("unimplemented")
    }

    /**
     * Returns the next `T` in this change stream or `nil`, or throws an error if one occurs -- compared to `next()`,
     * which returns `nil` and requires manually checking for an error afterward. Will block for a maximum of
     * `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout if
     * omitted.
     * - Returns: the next `T` in this change stream, or `nil` if at the end of the change stream cursor.
     * - Throws:
     *   - `CommandError` if an error occurs on the server while iterating the change stream cursor.
     *   - `LogicError` if this function is called and the session associated with this change stream is
     *     inactive.
     *   - `DecodingError` if an error occurs while decoding the server's response.
     */
    public func nextOrError() throws -> T? {
        fatalError("unimplemented")
    }
}
