import mongoc

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
    /// A `ResumeToken` associated with the most recent event seen by the change stream.
    public private(set) var resumeToken: ResumeToken?

    /// A `MongoClient` stored to make sure the source client stays valid until the change stream is destroyed.
    private let client: MongoClient

    /// A `Connection` stored to make sure the client connection stays valid until the change stream is destroyed.
    private let connection: Connection

    /// A `ClientSession` stored to make sure the session stays valid until the change stream is destroyed.
    private let session: ClientSession?

    /// A reference to the `mongoc_change_stream_t` pointer.
    private let changeStream: OpaquePointer

    /// Decoder for decoding documents into type `T`.
    private let decoder: BSONDecoder

    /// Used for storing Swift errors.
    private var swiftError: Error?

    /**
     * The error that occurred while iterating the change stream, if one exists. This should be used to check
     * for errors after `next()` returns `nil`.
     *  - Errors:
     *    - `DecodingError` if an error occurs while decoding the server's response.
     */
    public var error: Error? {
        if let err = self.swiftError {
            return err
        }

        var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            replyPtr.deinitialize(count: 1)
            replyPtr.deallocate()
        }

        var error = bson_error_t()
        guard mongoc_change_stream_error_document(self.changeStream, &error, replyPtr) else {
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
        // If an error exists, refuse iterating the change stream to avoid overwriting the original error.
        guard self.error == nil else {
            return nil
        }
        // Allocate space for a reference to a BSON pointer.
        let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }

        guard mongoc_change_stream_next(self.changeStream, out) else {
            return nil
        }

        guard let pointee = out.pointee else {
            fatalError("The change stream was advanced, but the document is nil.")
        }

        // we have to copy because libmongoc owns the pointer.
        let doc = Document(copying: pointee)

        // Update the resumeToken with the `_id` field from the document.
        guard let resumeToken = doc["_id"] as? Document else {
            self.swiftError =
                    RuntimeError.internalError(message: "_id field is missing from the change stream document.")
            return nil
        }
        self.resumeToken = ResumeToken(resumeToken)

        do {
            return try decoder.decode(T.self, from: doc)
        } catch {
            self.swiftError = error
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

    /**
     * Initializes a `ChangeStream`.
     * - Throws:
     *   - `ServerError.commandError` if an error occurred on the server when creating the `mongoc_change_stream_t`.
     *   - `UserError.invalidArgumentError` if the `mongoc_change_stream_t` was created with invalid options.
     */
    internal init(options: ChangeStreamOptions?,
                  client: MongoClient,
                  decoder: BSONDecoder,
                  session: ClientSession?,
                  initializer: (Connection) -> OpaquePointer) throws {
        self.connection = try session?.getConnection(forUseWith: client) ?? client.connectionPool.checkOut()
        self.changeStream = initializer(self.connection)

        // TODO: SWIFT-519 - Starting 4.2, update resumeToken to startAfter (if set).
        // startAfter takes precedence over resumeAfter.
        if let resumeAfter = options?.resumeAfter {
            self.resumeToken = resumeAfter
        }
        self.client = client
        self.session = session
        self.decoder = decoder
        self.swiftError = nil

        if let err = self.error {
            throw err
        }
    }

    /// Cleans up internal state.
    deinit {
        mongoc_change_stream_destroy(self.changeStream)
        // If the change stream was created with a session, then the session owns the connection.
        if self.session == nil {
            self.client.connectionPool.checkIn(self.connection)
        }
    }
}
