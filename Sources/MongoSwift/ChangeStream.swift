import CLibMongoC
import Foundation
import NIO

internal let ClosedChangeStreamError =
    LogicError(message: "Cannot advance a completed or failed change stream.")

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

// sourcery: skipSyncExport
/// A MongoDB change stream.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
public class ChangeStream<T: Codable>: AsyncSequence {
    internal typealias Element = T

    /// Enum for tracking the state of a change stream.
    internal enum State {
        /// Indicates that the change stream is still open. Stores a pointer to the `mongoc_change_stream_t`, along
        /// with the source connection and possibly session to ensure they are kept alive as long
        /// as the change stream is.
        case open(
            changeStream: OpaquePointer,
            connection: Connection,
            session: ClientSession?
        )
        case closed
    }

    /// The state of this change stream.
    internal private(set) var state: State

    /// The client this change stream descended from.
    private let client: MongoClient

    /// Decoder for decoding documents into type `T`.
    internal let decoder: BSONDecoder

    /// Semaphore used to synchronize between polling the change stream continually and manually closing it.
    private var pollingSemaphore: DispatchSemaphore

    /// Indicates whether this change stream has the potential to return more data.
    public var isAlive: Bool {
        switch self.state {
        case .closed:
            return false
        case .open:
            return true
        }
    }

    /// A `ResumeToken` associated with the most recent event seen by the change stream.
    public internal(set) var resumeToken: ResumeToken?

    /**
     * Retrieves any error that occured in mongoc or on the server while iterating the change stream. Returns nil if
     * this change stream is already closed, or if no error occurred.
     *  - Errors:
     *    - `DecodingError` if an error occurs while decoding the server's response.
     */
    internal func getChangeStreamError() -> Error? {
        guard case let .open(changeStream, _, _) = self.state else {
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

    /// Poll the underlying mongoc_change_stream_t for the next change event.
    internal func fetchNextDocument() throws -> T? {
        guard case let .open(changeStreamPtr, _, _) = self.state else {
            throw ClosedChangeStreamError
        }

        let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }

        guard mongoc_change_stream_next(changeStreamPtr, out) else {
            if let error = self.getChangeStreamError() {
                self.blockingClose()
                throw error
            }
            return nil
        }
        guard let pointee = out.pointee else {
            fatalError("The change stream was advanced, but the document is nil")
        }

        // We have to copy because libmongoc owns the pointer.
        let doc = Document(copying: pointee)

        // Update the resumeToken with the `_id` field from the document.
        guard let resumeToken = doc["_id"]?.documentValue else {
            throw InternalError(message: "_id field is missing from the change stream document.")
        }
        self.resumeToken = ResumeToken(resumeToken)
        return try self.decoder.decode(T.self, from: doc)
    }

    /// Destroys the underlying mongoc change stream and closes the state in a blocking manner.
    private func blockingClose() {
        guard case let .open(changeStream, _, _) = self.state else {
            return
        }
        self.pollingSemaphore.wait()
        mongoc_change_stream_destroy(changeStream)
        self.state = .closed
        self.pollingSemaphore.signal()
    }

    /// Returns the next `T` in the change stream or nil if there is no next value. Will block for a maximum of
    /// `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout
    /// if omitted.
    public func next() -> EventLoopFuture<T?> {
        let operation = NextOperation(target: .changeStream(self))
        return self.client.executeOperationAsync(operation)
    }

    /// Returns all of the events seen by this change stream so far.
    public func all() -> EventLoopFuture<[T]> {
        let operation = AllOperation(target: .changeStream(self))
        return self.client.executeOperationAsync(operation)
    }

    /// Executes the provided closure against each event seen by the change stream.
    /// This will cause the stream to continuously poll for new events in the background. Once this method has been
    /// called, other methods that check for events (e.g. all, next, forEach) should not be used.
    public func forEach(body: @escaping (Result<T, Error>) -> Void) {
        self.pollingSemaphore.wait()

        guard self.isAlive else {
            self.pollingSemaphore.signal()
            return
        }

        self.next().whenComplete { result in
            switch result {
            case let .success(event):
                if let event = event {
                    body(.success(event))
                }
            case let .failure(error):
                body(.failure(error))
                return
            }
            self.pollingSemaphore.signal()
            self.forEach(body: body)
        }
    }

    /// Closes this change stream.
    /// This must be called when the change stream is no longer needed or else memory may be leaked.
    public func close() -> EventLoopFuture<Void> {
        return self.client.operationExecutor.execute {
            self.blockingClose()
        }
    }

    /**
     * Initializes a `ChangeStream`.
     */
    internal init(
        stealing changeStream: OpaquePointer,
        connection: Connection,
        client: MongoClient,
        session: ClientSession?,
        decoder: BSONDecoder,
        options: ChangeStreamOptions?
    ) {
        self.state = .open(changeStream: changeStream, connection: connection, session: session)
        self.client = client
        self.decoder = decoder
        self.pollingSemaphore = DispatchSemaphore(value: 1)

        // TODO: SWIFT-519 - Starting 4.2, update resumeToken to startAfter (if set).
        // startAfter takes precedence over resumeAfter.
        if let resumeAfter = options?.resumeAfter {
            self.resumeToken = resumeAfter
        }
    }

    deinit {
        assert(!self.isAlive, "change stream wasn't closed")
    }
}
