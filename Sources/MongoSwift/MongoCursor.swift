import CLibMongoC
import Foundation
import NIO
import NIOConcurrencyHelpers

/// Direct wrapper of a `mongoc_cursor_t`.
internal struct MongocCursor: MongocCursorWrapper {
    internal let pointer: OpaquePointer

    internal static var isLazy: Bool { true }

    internal init(referencing pointer: OpaquePointer) {
        self.pointer = pointer
    }

    internal func errorDocument(bsonError: inout bson_error_t, replyPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        mongoc_cursor_error_document(self.pointer, &bsonError, replyPtr)
    }

    internal func next(outPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        mongoc_cursor_next(self.pointer, outPtr)
    }

    internal func more() -> Bool {
        mongoc_cursor_more(self.pointer)
    }

    internal func destroy() {
        mongoc_cursor_destroy(self.pointer)
    }
}

// sourcery: skipSyncExport
/// A MongoDB cursor.
public class MongoCursor<T: Codable>: CursorProtocol {
    /// The client this cursor descended from.
    private let client: MongoClient

    private let wrappedCursor: Cursor<MongocCursor>

    /// The `EventLoop` this `MongoCursor` is bound to.
    internal let eventLoop: EventLoop?

    /// Decoder from the client, database, or collection that created this cursor.
    internal let decoder: BSONDecoder

    /// The ID used by the server to track the cursor over time. If all of the cursor's results were returnable in a
    /// single batch, or if the cursor contained no results, this value will be nil.
    public let id: Int64?

    /**
     * Initializes a new `MongoCursor` instance. Not meant to be instantiated directly by a user.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(
        stealing cursorPtr: OpaquePointer,
        connection: Connection,
        client: MongoClient,
        decoder: BSONDecoder,
        eventLoop: EventLoop?,
        session: ClientSession?,
        cursorType: MongoCursorType? = nil
    ) throws {
        self.client = client
        self.decoder = decoder
        self.eventLoop = eventLoop

        self.wrappedCursor = try Cursor(
            mongocCursor: MongocCursor(referencing: cursorPtr),
            connection: connection,
            session: session,
            type: cursorType ?? .nonTailable
        )

        self.id = self.wrappedCursor.withUnsafeMongocPointer { ptr in
            guard let ptr = ptr else {
                return nil
            }
            let id = mongoc_cursor_get_id(ptr)
            return id == 0 ? nil : id
        }
    }

    /// Decodes a result to the generic type or `nil` if no result were returned.
    private func decode(result: BSONDocument?) throws -> T? {
        guard let doc = result else {
            return nil
        }
        return try self.decode(doc: doc)
    }

    /// Decodes the given document to the generic type.
    private func decode(doc: BSONDocument) throws -> T {
        try self.decoder.decode(T.self, from: doc)
    }

    /**
     * Indicates whether this cursor has the potential to return more data.
     *
     * This method is mainly useful if this cursor is tailable, since in that case `tryNext` may return more results
     * even after returning `nil`.
     *
     * If this cursor is non-tailable, it will always be dead after either `tryNext` returns `nil` or a
     * non-`DecodingError` error.
     *
     * This cursor will be dead after `next` returns `nil` or a non-`DecodingError` error, regardless of the
     * `MongoCursorType`.
     *
     * This cursor may still be alive after `next` or `tryNext` returns a `DecodingError`.
     *
     * - Warning:
     *    If this cursor is alive when it goes out of scope, it will leak resources. To ensure it is dead before it
     *    leaves scope, invoke `MongoCursor.kill(...)` on it.
     */
    public func isAlive() -> EventLoopFuture<Bool> {
        self.client.operationExecutor.execute(on: self.eventLoop) {
            self.wrappedCursor.isAlive
        }
    }

    /**
     * Attempt to get the next `T` from the cursor, returning `nil` if there are no results.
     *
     * If this cursor is tailable, this method may be called repeatedly while `isAlive` is true to retrieve new data.
     *
     * If this cursor is a tailable await cursor, it will wait for results server side for a maximum of `maxAwaitTimeMS`
     * before evaluating to `nil`. This option can be configured via options passed to the method that created this
     * cursor (e.g. the `maxAwaitTimeMS` option on the `FindOptions` passed to `find`).
     *
     * Note: You *must not* call any cursor methods besides `kill` and `isAlive` while the future returned from this
     * method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *    An `EventLoopFuture<T?>` containing the next `T` in this cursor, an error if one occurred, or `nil` if
     *    there was no data.
     *
     *    If the future evaluates to an error, it is likely one of the following:
     *      - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *      - `MongoError.LogicError` if this function is called after the cursor has died.
     *      - `MongoError.LogicError` if this function is called and the session associated with this cursor is
     *        inactive.
     *      - `MongoError.LogicError` if this cursor's parent client has already been closed.
     *      - `DecodingError` if an error occurs decoding the server's response.
     */
    public func tryNext() -> EventLoopFuture<T?> {
        self.client.operationExecutor.execute(on: self.eventLoop) {
            try self.decode(result: self.wrappedCursor.tryNext())
        }
    }

    /**
     * Get the next `T` from the cursor.
     *
     * If this cursor is tailable, this method will continue polling until a non-empty batch is returned from the server
     * or the cursor is closed.
     *
     * A thread from the driver's internal thread pool will be occupied until the returned future is completed, so
     * performance degradation is possible if the number of polling cursors is too close to the total number of threads
     * in the thread pool. To configure the total number of threads in the pool, set the
     * `MongoClientOptions.threadPoolSize` option during client creation.
     *
     * Note: You *must not* call any cursor methods besides `kill` and `isAlive` while the future returned from this
     * method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *   An `EventLoopFuture<T?>` evaluating to the next `T` in this cursor, or `nil` if the cursor is exhausted. If
     *   the underlying cursor is tailable, the future will not resolve until data is returned (potentially after
     *   multiple requests to the server), the cursor is closed, or an error occurs.
     *
     *   If the future fails, the error is likely one of the following:
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the cursor has died.
     *     - `MongoError.LogicError` if this function is called and the session associated with this cursor is
     *        inactive.
     *     - `DecodingError` if an error occurs decoding the server's response.
     */
    public func next() -> EventLoopFuture<T?> {
        self.client.operationExecutor.execute(on: self.eventLoop) {
            try self.decode(result: self.wrappedCursor.next())
        }
    }

    /**
     * Consolidate the currently available results of the cursor into an array of type `T`.
     *
     * If this cursor is not tailable, this method will exhaust it.
     *
     * If this cursor is tailable, `toArray` will only fetch the currently available results, and it
     * may return more data if it is called again while the cursor is still alive.
     *
     * Note: You *must not* call any cursor methods besides `kill` and `isAlive` while the future returned from this
     * method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *    An `EventLoopFuture<[T]>` evaluating to the results currently available in this cursor, or an error.
     *
     *    If the future evaluates to an error, that error is likely one of the following:
     *      - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *      - `MongoError.LogicError` if this function is called after the cursor has died.
     *      - `MongoError.LogicError` if this function is called and the session associated with this cursor is
     *        inactive.
     *      - `DecodingError` if an error occurs decoding the server's responses.
     */
    public func toArray() -> EventLoopFuture<[T]> {
        self.client.operationExecutor.execute(on: self.eventLoop) {
            try self.wrappedCursor.toArray().map { try self.decode(doc: $0) }
        }
    }

    /**
     * Calls the provided closure with each element in the cursor.
     *
     * If the cursor is not tailable, this method will exhaust it, calling the closure with every document.
     *
     * If the cursor is tailable, the method will call the closure with each new document as it arrives.
     *
     * A thread from the driver's internal thread pool will be occupied until the returned future is completed, so
     * performance degradation is possible if the number of polling cursors is too close to the total number of threads
     * in the thread pool. To configure the total number of threads in the pool, set the
     * `MongoClientOptions.threadPoolSize` option during client creation.
     *
     * Note: You *must not* call any cursor methods besides `kill` and `isAlive` while the future returned from this
     * method is unresolved. Doing so will result in undefined behavior.
     *
     * - Returns:
     *     An `EventLoopFuture<Void>` which will succeed when the end of the cursor is reached, or in the case of a
     *     tailable cursor, when the cursor is killed via `kill`.
     *
     *     If the future evaluates to an error, that error is likely one of the following:
     *     - `MongoError.CommandError` if an error occurs while fetching more results from the server.
     *     - `MongoError.LogicError` if this function is called after the cursor has died.
     *     - `MongoError.LogicError` if this function is called and the session associated with this cursor is inactive.
     *     - `DecodingError` if an error occurs decoding the server's responses.
     */
    public func forEach(_ body: @escaping (T) throws -> Void) -> EventLoopFuture<Void> {
        self.client.operationExecutor.execute(on: self.eventLoop) {
            while let next = try self.decode(result: self.wrappedCursor.next()) {
                try body(next)
            }
        }
    }

    /**
     * Kill this cursor.
     *
     * This method MAY be called even if there are unresolved futures created from other `MongoCursor` methods.
     *
     * This method MAY be called if the cursor is already dead. It will have no effect.
     *
     * - Warning:
     *    If this cursor is alive when it goes out of scope, it will leak resources. To ensure it
     *    is dead before it leaves scope, invoke this method.
     *
     * - Returns:
     *   An `EventLoopFuture` that evaluates when the cursor has completed closing. This future should not fail.
     */
    public func kill() -> EventLoopFuture<Void> {
        self.client.operationExecutor.execute(on: self.eventLoop) {
            self.wrappedCursor.kill()
        }
    }
}
