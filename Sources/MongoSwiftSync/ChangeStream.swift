import MongoSwift

/// A MongoDB change stream.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
public class ChangeStream<T: Codable>: Sequence, IteratorProtocol {
    /// A `ResumeToken` associated with the most recent event seen by the change stream.
    public var resumeToken: ResumeToken? {
        return self.asyncChangeStream.resumeToken
    }

    /// Indicates whether this change stream has the potential to return more data.
    public var isAlive: Bool {
        return self.asyncChangeStream.isAlive
    }

    private let asyncChangeStream: MongoSwift.ChangeStream<T>

    /// The client this change strem descended from.
    private let client: MongoClient

    /**
     * Initializes a `ChangeStream`.
     */
    internal init(wrapping changeStream: MongoSwift.ChangeStream<T>, client: MongoClient) {
        self.asyncChangeStream = changeStream
        self.client = client
    }

    /// Closes the change stream if it hasn't been closed already.
    deinit {
        try? self.asyncChangeStream.close().wait()
    }

    /// Returns the next `T` in the change stream or nil if there is no next value. Will block for a maximum of
    /// `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout
    /// if omitted.
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
     * Returns an array of type `T` from this change stream.
     * - Returns: an array of type `T`
     * - Throws:
     *   - `CommandError` if an error occurs while fetching more results from the server.
     *   - `LogicError` if this function is called after the change stream has died.
     *   - `LogicError` if this function is called and the session associated with this change stream is inactive.
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
