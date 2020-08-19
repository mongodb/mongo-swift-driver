import CLibMongoC
import Foundation
import NIO

/// Direct wrapper of a `mongoc_change_stream_t`.
private struct MongocChangeStream: MongocCursorWrapper {
    internal let pointer: OpaquePointer

    internal static var isLazy: Bool { false }

    fileprivate init(stealing ptr: OpaquePointer) {
        self.pointer = ptr
    }

    internal func errorDocument(bsonError: inout bson_error_t, replyPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        mongoc_change_stream_error_document(self.pointer, &bsonError, replyPtr)
    }

    internal func next(outPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        mongoc_change_stream_next(self.pointer, outPtr)
    }

    internal func more() -> Bool {
        true
    }

    internal func destroy() {
        mongoc_change_stream_destroy(self.pointer)
    }
}

/// A token used for manually resuming a change stream. Pass this to the `resumeAfter` field of
/// `ChangeStreamOptions` to resume or start a change stream where a previous one left off.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/#resume-a-change-stream
public struct ResumeToken: Codable, Equatable {
    private let resumeToken: BSONDocument

    internal init(_ resumeToken: BSONDocument) {
        self.resumeToken = resumeToken
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.resumeToken)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.resumeToken = try container.decode(BSONDocument.self)
    }
}

// TODO: SWIFT-981: Remove this.
/// The key we use for storing a change stream's namespace in it's `userInfo`. This allows types
/// using the decoder e.g. `ChangeStreamEvent` to access the namespace even if it is not present in the raw
/// document the server returns. Ok to force unwrap as initialization never fails.
// swiftlint:disable:next force_unwrapping
internal let changeStreamNamespaceKey = CodingUserInfoKey(rawValue: "namespace")!

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
    private func processEvent(_ event: BSONDocument?) throws -> T? {
        guard let event = event else {
            return nil
        }
        return try self.processEvent(event)
    }

    /// Process an event before returning it to the user.
    private func processEvent(_ event: BSONDocument) throws -> T {
        // Update the resumeToken with the `_id` field from the document.
        guard let resumeToken = event["_id"]?.documentValue else {
            throw MongoError.InternalError(message: "_id field is missing from the change stream document.")
        }
        self.resumeToken = ResumeToken(resumeToken)
        return try self.decoder.decode(T.self, from: event)
    }

    internal init(
        stealing changeStreamPtr: OpaquePointer,
        connection: Connection,
        client: MongoClient,
        namespace: MongoNamespace,
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
        self.decoder = BSONDecoder(copies: decoder, options: nil)
        self.decoder.userInfo[changeStreamNamespaceKey] = namespace

        // TODO: SWIFT-519 - Starting 4.2, update resumeToken to startAfter (if set).
        // startAfter takes precedence over resumeAfter.
        if let resumeAfter = options?.resumeAfter {
            self.resumeToken = resumeAfter
        }
    }

    /**
     * Indicates whether this change stream has the potential to return more data.
     *
     * This change stream will be dead after `next` returns `nil`, but it may still be alive after `tryNext` returns
     * `nil`.
     *
     * After either of `next` or `tryNext` return a non-`DecodingError` error, this change stream will be dead. It may
     * still be alive after either returns a `DecodingError`, however.
     *
     * - Warning:
     *    If this change stream is alive when it goes out of scope, it will leak resources. To ensure it is dead
     *    before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     */
    public func isAlive() -> EventLoopFuture<Bool> {
        self.client.operationExecutor.execute {
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
     * `MongoClientOptions.threadPoolSize` option during client creation.
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
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the change stream has died.
     *     - `MongoError.LogicError` if this function is called and the session associated with this change stream is
     *       inactive.
     *     - `DecodingError` if an error occurs decoding the server's response.
     */
    public func next() -> EventLoopFuture<T?> {
        self.client.operationExecutor.execute {
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
     *      - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *      - `MongoError.LogicError` if this function is called after the change stream has died.
     *      - `MongoError.LogicError` if this function is called and the session associated with this change stream is
     *        inactive.
     *      - `DecodingError` if an error occurs decoding the server's response.
     */
    public func tryNext() -> EventLoopFuture<T?> {
        self.client.operationExecutor.execute {
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
     *      - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *      - `MongoError.LogicError` if this function is called after the change stream has died.
     *      - `MongoError.LogicError` if this function is called and the session associated with this change stream is
     *        inactive.
     *      - `DecodingError` if an error occurs decoding the server's responses.
     */
    public func toArray() -> EventLoopFuture<[T]> {
        self.client.operationExecutor.execute {
            try self.wrappedCursor.toArray().map(self.processEvent)
        }
    }

    /**
     * Calls the provided closure with each event in the change stream as it arrives.
     *
     * A thread from the driver's internal thread pool will be occupied until the returned future is completed, so
     * performance degradation is possible if the number of polling change streams is too close to the total number of
     * threads in the thread pool. To configure the total number of threads in the pool, set the
     * `MongoClientOptions.threadPoolSize` option during client creation.
     *
     * Note: You *must not* call any change stream methods besides `kill` and `isAlive` while the future returned from
     * this method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *     An `EventLoopFuture<Void>` which will complete once the change stream is closed or once an error is
     *     encountered.
     *
     *     If the future evaluates to an error, that error is likely one of the following:
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the change stream has died.
     *      - `MongoError.LogicError` if this function is called and the session associated with this change stream is
     *        inactive.
     *     - `DecodingError` if an error occurs decoding the server's responses.
     */
    public func forEach(_ body: @escaping (T) throws -> Void) -> EventLoopFuture<Void> {
        self.client.operationExecutor.execute {
            while let next = try self.processEvent(self.wrappedCursor.next()) {
                try body(next)
            }
        }
    }

    /**
     * Kill this change stream.
     *
     * This method MAY be called even if there are unresolved futures created from other `ChangeStream` methods.
     *
     * This method MAY be called if the change stream is already dead. It will have no effect.
     *
     * - Warning:
     *    If this change stream is alive when it goes out of scope, it will leak resources. To ensure it
     *    is dead before it leaves scope, invoke this method.
     *
     * - Returns:
     *   An `EventLoopFuture` that evaluates when the change stream has completed closing. This future should not fail.
     */
    public func kill() -> EventLoopFuture<Void> {
        self.client.operationExecutor.execute {
            self.wrappedCursor.kill()
        }
    }
}
