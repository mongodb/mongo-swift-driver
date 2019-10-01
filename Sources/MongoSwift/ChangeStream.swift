import mongoc

internal let ClosedChangeStreamError =
    UserError.logicError(message: "Cannot advance a completed or failed change stream.")

/// A token used for manually resuming a change stream. Pass this to the `resumeAfter` field of
/// `ChangeStreamOptions` to resume or start a change stream where a previous one left off.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/#resume-a-change-stream
public struct ResumeToken: Codable, Equatable {
    private let resumeToken: Document

    internal init(_ resumeToken: Document) {
        self.resumeToken = resumeToken
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.resumeToken)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.resumeToken = try container.decode(Document.self)
    }
}

/// A MongoDB ChangeStream.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
public class ChangeStream<T: Codable>: Sequence, IteratorProtocol {
    /// Enum for tracking the state of a change stream.
    internal enum State {
        /// Indicates that the change stream is still open. Stores a pointer to the `mongoc_change_stream_t`, along
        /// with the source connection, client, and possibly session to ensure they are kept alive as long
        /// as the change stream is.
        case open(changeStream: OpaquePointer, connection: Connection, client: MongoClient, session: ClientSession?)
        case closed
    }

    /// The state of this change stream.
    internal private(set) var state: State

    /// A `ResumeToken` associated with the most recent event seen by the change stream.
    public internal(set) var resumeToken: ResumeToken?

    /// Decoder for decoding documents into type `T`.
    internal let decoder: BSONDecoder

    /// The error that occurred while iterating the change stream, if one exists. This should be used to check
    /// for errors after `next()` returns `nil`.
    public private(set) var error: Error?

    /**
     * Initializes a `ChangeStream`.
     * - Throws:
     *   - `ServerError.commandError` if an error occurred on the server when creating the `mongoc_change_stream_t`.
     *   - `UserError.invalidArgumentError` if the `mongoc_change_stream_t` was created with invalid options.
     */
    internal init(changeStream: OpaquePointer,
                  connection: Connection,
                  client: MongoClient,
                  session: ClientSession?,
                  decoder: BSONDecoder,
                  options: ChangeStreamOptions?
                  ) throws {
        self.state = .open(changeStream: changeStream, connection: connection, client: client, session: session)
        self.decoder = decoder

        // TODO: SWIFT-519 - Starting 4.2, update resumeToken to startAfter (if set).
        // startAfter takes precedence over resumeAfter.
        if let resumeAfter = options?.resumeAfter {
            self.resumeToken = resumeAfter
        }

        if let err = self.getChangeStreamError() {
            throw err
        }
    }

    /// Cleans up internal state.
    private func close() {
        guard case let .open(changeStream, connection, client, session) = self.state else {
            return
        }
        mongoc_change_stream_destroy(changeStream)
        // If the change stream was created with a session, then the session owns the connection.
        if session == nil {
            client.connectionPool.checkIn(connection)
        }
        self.state = .closed
    }

    /// Closes the cursor if it hasn't been closed already.
    deinit {
        self.close()
    }

    /**
     * Retrieves any error that occured in mongoc or on the server while iterating the change stream. Returns nil if
     * this change stream is already closed, or if no error occurred.
     *  - Errors:
     *    - `DecodingError` if an error occurs while decoding the server's response.
     */
    private func getChangeStreamError() -> Error? {
        guard case let .open(changeStream, _, _, _) = self.state else {
            return nil
        }

        var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            replyPtr.deinitialize(count: 1)
            replyPtr.deallocate()
        }

        var error = bson_error_t()
        guard mongoc_change_stream_error_document(changeStream, &error, replyPtr) else {
            return nil
        }

        // If a reply is present, it implies the error occurred on the server. This *should* always be a commandError,
        // but we will still parse the mongoc error to cover all cases.
        if let docPtr = replyPtr.pointee {
            // we have to copy because libmongoc owns the pointer.
            let reply = Document(copying: docPtr)
            return extractMongoError(error: error, reply: reply)
        }

        // Otherwise, the only feasible error is that the user tried to advance a dead change stream cursor,
        // which is a logic error. We will still parse the mongoc error to cover all cases.
        return extractMongoError(error: error)
    }

    /// Returns the next `T` in the change stream or nil if there is no next value. Will block for a maximum of
    /// `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout
    /// if omitted.
    public func next() -> T? {
        // We already closed the mongoc change stream, either because we reached the end or encountered an error.
        guard case let .open(_, connection, _, session) = self.state else {
            self.error = ClosedChangeStreamError
            return nil
        }
        do {
            let operation = NextOperation(target: .changeStream(self))
            guard let out = try operation.execute(using: connection, session: session) else {
                self.error = self.getChangeStreamError()
                if self.error != nil {
                    self.close()
                }
                return nil
            }
            return out
        } catch {
            self.error = error
            self.close()
            return nil
        }
    }

    /**
     * Returns the next `T` in this change stream or `nil`, or throws an error if one occurs -- compared to `next()`,
     * which returns `nil` and requires manually checking for an error afterward. Will block for a maximum of
     * `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout if
     * omitted.
     * - Returns: the next `T` in this change stream, or `nil` if at the end of the change stream cursor.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while iterating the change stream cursor.
     *   - `UserError.logicError` if this function is called and the session associated with this change stream is
     *     inactive.
     *   - `DecodingError` if an error occurs while decoding the server's response.
     */
    public func nextOrError() throws -> T? {
        if let next = self.next() {
            return next
        }

        if let error = self.error {
            throw error
        }
        return nil
    }
}
