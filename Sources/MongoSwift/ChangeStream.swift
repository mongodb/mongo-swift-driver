import CLibMongoC
import Foundation
import NIO

/// Direct wrapper of a `mongoc_change_stream_t`.
private struct MongocChangeStream: MongocCursorWrapper {
    internal let pointer: OpaquePointer

    internal static var isLazy: Bool { return false }

    fileprivate init(stealing ptr: OpaquePointer) {
        self.pointer = ptr
    }

    internal func errorDocument(bsonError: inout bson_error_t, replyPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        return mongoc_change_stream_error_document(self.pointer, &bsonError, replyPtr)
    }

    internal func next(outPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        return mongoc_change_stream_next(self.pointer, outPtr)
    }

    internal func more() -> Bool {
        return true
    }

    internal func destroy() {
        mongoc_change_stream_destroy(self.pointer)
    }
}

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
public class ChangeStream<T: Codable>: CursorProtocol {
    internal typealias Element = T

    /// The client this change stream descended from.
    private let client: MongoClient

    /// Decoder for decoding documents into type `T`.
    private let decoder: BSONDecoder

    /// The cursor this change stream is wrapping.
    private let wrappedCursor: Cursor<MongocChangeStream>

    /// Process an event before returning it to the user, or does nothing and returns nil if the provided event is nil.
    private func processEvent(_ event: Document?) throws -> T? {
        guard let event = event else {
            return nil
        }
        return try self.processEvent(event)
    }

    /// Process an event before returning it to the user.
    private func processEvent(_ event: Document) throws -> T {
        // Update the resumeToken with the `_id` field from the document.
        guard let resumeToken = event["_id"]?.documentValue else {
            throw InternalError(message: "_id field is missing from the change stream document.")
        }
        self.resumeToken = ResumeToken(resumeToken)
        return try self.decoder.decode(T.self, from: event)
    }

    internal init(
        stealing changeStreamPtr: OpaquePointer,
        connection: Connection,
        client: MongoClient,
        session: ClientSession?,
        decoder: BSONDecoder,
        options: ChangeStreamOptions?
    ) throws {
        let mongocChangeStream = MongocChangeStream(stealing: changeStreamPtr)
        self.wrappedCursor = try Cursor(
            mongocCursor: mongocChangeStream,
            connection: connection,
            session: session,
            type: .tailableAwait
        )
        self.client = client
        self.decoder = decoder

        // TODO: SWIFT-519 - Starting 4.2, update resumeToken to startAfter (if set).
        // startAfter takes precedence over resumeAfter.
        if let resumeAfter = options?.resumeAfter {
            self.resumeToken = resumeAfter
        }
    }

    /// Indicates whether this change stream has the potential to return more data.
    public func isAlive() -> EventLoopFuture<Bool> {
        return self.client.operationExecutor.execute {
            self.wrappedCursor.isAlive
        }
    }

    /// The `ResumeToken` associated with the most recent event seen by the change stream.
    public internal(set) var resumeToken: ResumeToken?

    /**
     * Get the next `T` from this change stream.
     *
     * This method will continue polling until an event is returned from the server, an error occurs,
     * or the change stream is killed. Each attempt to retrieve results will wait for a maximum of `maxAwaitTimeMS`
     * (specified on the `ChangeStreamOptions` passed  to the method that created this change stream) before trying
     * again.
     *
     * A thread from the driver's internal thread pool will be occupied until the returned future is completed, so
     * performance degradation is possible if the number of polling change streams is too close to the total number of
     * threads in the thread pool. To configure the total number of threads in the pool, set the
     * `ClientOptions.threadPoolSize` option during client creation.
     *
     * Note: You *must not* call any change stream methods besides `kill` and `isAlive` while the future returned from
     * this method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *   An `EventLoopFuture<T?>` evaluating to the next `T` in this change stream, `nil` if the change stream is
     *   exhausted, or an error if one occurred. The returned future will not resolve until one of those conditions is
     *   met, potentially after multiple requests to the server.
     *
     *   If the future evaluates to an error, it is likely one of the following:
     *     - `CommandError` if an error occurs while fetching more results from the server.
     *     - `LogicError` if this function is called after the change stream has died.
     *     - `LogicError` if this function is called and the session associated with this change stream is inactive.
     *     - `DecodingError` if an error occurs decoding the server's response.
     */
    public func next() -> EventLoopFuture<T?> {
        return self.client.operationExecutor.execute {
            try self.processEvent(self.wrappedCursor.next())
        }
    }

    /**
     * Attempt to get the next `T` from this change stream, returning `nil` if there are no results.
     *
     * The change stream will wait server-side for a maximum of `maxAwaitTimeMS` (specified on the `ChangeStreamOptions`
     * passed to the method that created this change stream) before returning `nil`.
     *
     * This method may be called repeatedly while `isAlive` is true to retrieve new data.
     *
     * Note: You *must not* call any change stream methods besides `kill` and `isAlive` while the future returned from
     * this method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *    An `EventLoopFuture<T?>` containing the next `T` in this change stream, an error if one occurred, or `nil` if
     *    there was no data.
     *
     *    If the future evaluates to an error, it is likely one of the following:
     *      - `CommandError` if an error occurs while fetching more results from the server.
     *      - `LogicError` if this function is called after the change stream has died.
     *      - `LogicError` if this function is called and the session associated with this change stream is inactive.
     *      - `DecodingError` if an error occurs decoding the server's response.
     */
    public func tryNext() -> EventLoopFuture<T?> {
        return self.client.operationExecutor.execute {
            try self.processEvent(self.wrappedCursor.tryNext())
        }
    }

    /**
     * Consolidate the currently available results of the change stream into an array of type `T`.
     *
     * Since `toArray` will only fetch the currently available results, it may return more data if it is called again
     * while the change stream is still alive.
     *
     * Note: You *must not* call any change stream methods besides `kill` and `isAlive` while the future returned from
     * this method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *    An `EventLoopFuture<[T]>` evaluating to the results currently available in this change stream, or an error.
     *
     *    If the future evaluates to an error, that error is likely one of the following:
     *      - `CommandError` if an error occurs while fetching more results from the server.
     *      - `LogicError` if this function is called after the change stream has died.
     *      - `LogicError` if this function is called and the session associated with this change stream is inactive.
     *      - `DecodingError` if an error occurs decoding the server's responses.
     */
    public func toArray() -> EventLoopFuture<[T]> {
        return self.client.operationExecutor.execute {
            try self.wrappedCursor.toArray().map(self.processEvent)
        }
    }

    /**
     * Calls the provided closure with each event in the change stream as it arrives.
     *
     * A thread from the driver's internal thread pool will be occupied until the returned future is completed, so
     * performance degradation is possible if the number of polling change streams is too close to the total number of
     * threads in the thread pool. To configure the total number of threads in the pool, set the
     * `ClientOptions.threadPoolSize` option during client creation.
     *
     * Note: You *must not* call any change stream methods besides `kill` and `isAlive` while the future returned from
     * this method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *     An `EventLoopFuture<Void>` which will complete once the change stream is closed or once an error is
     *     encountered.
     *
     *     If the future evaluates to an error, that error is likely one of the following:
     *     - `CommandError` if an error occurs while fetching more results from the server.
     *     - `LogicError` if this function is called after the change stream has died.
     *     - `LogicError` if this function is called and the session associated with this change stream is inactive.
     *     - `DecodingError` if an error occurs decoding the server's responses.
     */
    public func forEach(_ body: @escaping (T) throws -> Void) -> EventLoopFuture<Void> {
        return self.client.operationExecutor.execute {
            while let next = try self.processEvent(self.wrappedCursor.next()) {
                try body(next)
            }
        }
    }

    /**
     * Kill this change stream.
     *
     * This method MUST be called before this change stream goes out of scope to prevent leaking resources.
     * This method may be called even if there are unresolved futures created from other `ChangeStream` methods.
     * This method will have no effect if the change stream is already dead.
     *
     * - Returns:
     *   An `EventLoopFuture` that evaluates when the change stream has completed closing. This future should not fail.
     */
    @discardableResult
    public func kill() -> EventLoopFuture<Void> {
        return self.client.operationExecutor.execute {
            self.wrappedCursor.kill()
        }
    }
}
