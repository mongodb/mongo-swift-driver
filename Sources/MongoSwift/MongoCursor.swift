import CLibMongoC
import Foundation
import NIO
import NIOConcurrencyHelpers

/// Direct wrapper of a `mongoc_cursor_t`.
internal struct MongocCursor: MongocCursorWrapper {
    internal let pointer: OpaquePointer

    internal static var isLazy: Bool { return true }

    internal init(referencing pointer: OpaquePointer) {
        self.pointer = pointer
    }

    internal func errorDocument(bsonError: inout bson_error_t, replyPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        return mongoc_cursor_error_document(self.pointer, &bsonError, replyPtr)
    }

    internal func next(outPtr: UnsafeMutablePointer<BSONPointer?>) -> Bool {
        return mongoc_cursor_next(self.pointer, outPtr)
    }

    internal func more() -> Bool {
        return mongoc_cursor_more(self.pointer)
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

    /// Decoder from the client, database, or collection that created this cursor.
    internal let decoder: BSONDecoder

    /**
     * Initializes a new `MongoCursor` instance. Not meant to be instantiated directly by a user. When `forceIO` is
     * true, this initializer will force a connection to the server if one is not already established.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(
        stealing cursorPtr: OpaquePointer,
        connection: Connection,
        client: MongoClient,
        decoder: BSONDecoder,
        session: ClientSession?,
        cursorType: CursorType? = nil
    ) throws {
        self.client = client
        self.decoder = decoder

        self.wrappedCursor = try Cursor(
            mongocCursor: MongocCursor(referencing: cursorPtr),
            connection: connection,
            session: session,
            type: cursorType ?? .nonTailable
        )
    }

    /// Decodes a result to the generic type or `nil` if no result were returned.
    private func decode(result: Document?) throws -> T? {
        guard let doc = result else {
            return nil
        }
        return try self.decode(doc: doc)
    }

    /// Decodes the given document to the generic type.
    private func decode(doc: Document) throws -> T {
        return try self.decoder.decode(T.self, from: doc)
    }

    /**
     * Indicates whether this cursor has the potential to return more data.
     *
     * This method is mainly useful if this cursor is tailable, since in that case `tryNext` may return more results
     * even after returning `nil`.
     *
     * If this cursor is non-tailable, it will always be dead as soon as either `tryNext` returns `nil` or an error.
     *
     * This cursor will be dead as soon as `next` returns `nil` or an error, regardless of the `CursorType`.
     */
    public func isAlive() -> EventLoopFuture<Bool> {
        return self.client.operationExecutor.execute {
            self.wrappedCursor.isAlive
        }
    }

    /// Returns the ID used by the server to track the cursor. `nil` once all results have been fetched from the server.
    public var id: Int64? {
        return self.wrappedCursor.withUnsafeMongocPointer { ptr in
            guard let ptr = ptr else {
                return nil
            }
            let id = mongoc_cursor_get_id(ptr)
            return id == 0 ? nil : id
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
     * - Returns:
     *    An `EventLoopFuture<T?>` containing the next `T` in this cursor, an error if one occurred, or `nil` if
     *    there was no data.
     *
     *    If the future evaluates to an error, it is likely one of the following:
     *      - `CommandError` if an error occurs while fetching more results from the server.
     *      - `LogicError` if this function is called after the cursor has died.
     *      - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *      - `LogicError` if this cursor's parent client has already been closed.
     *      - `DecodingError` if an error occurs decoding the server's response.
     */
    public func tryNext() -> EventLoopFuture<T?> {
        return self.client.operationExecutor.execute {
            try self.decode(result: self.wrappedCursor.tryNext())
        }
    }

    /**
     * Get the next `T` from the cursor.
     *
     * If this cursor is tailable, this method will continue polling until a non-empty batch is returned from the server
     * or the cursor is closed.
     *
     * - Returns:
     *   An `EventLoopFuture<T?>` evaluating to the next `T` in this cursor, or `nil` if the cursor is exhausted. If
     *   the underlying cursor is tailable, the future will not resolve until data is returned (potentially after
     *   multiple requests to the server), the cursor is closed, or an error occurs.
     *
     *   If the future fails, the error is likely one of the following:
     *     - `CommandError` if an error occurs while fetching more results from the server.
     *     - `LogicError` if this function is called after the cursor has died.
     *     - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *     - `DecodingError` if an error occurs decoding the server's response.
     */
    public func next() -> EventLoopFuture<T?> {
        return self.client.operationExecutor.execute {
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
     * - Returns:
     *    An `EventLoopFuture<[T]>` evaluating to the results currently available in this cursor, or an error.
     *
     *    If the future evaluates to an error, that error is likely one of the following:
     *      - `CommandError` if an error occurs while fetching more results from the server.
     *      - `LogicError` if this function is called after the cursor has died.
     *      - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *      - `DecodingError` if an error occurs decoding the server's responses.
     */
    public func toArray() -> EventLoopFuture<[T]> {
        return self.client.operationExecutor.execute {
            try self.wrappedCursor.toArray().map { try self.decode(doc: $0) }
        }
    }

    public func forEach(_ body: @escaping (T) throws -> Void) -> EventLoopFuture<Void> {
        return self.client.operationExecutor.execute {
            while let next = try self.decode(result: self.wrappedCursor.next()) {
                try body(next)
            }
        }
    }

    /**
     * Kill this cursor.
     *
     * This method MUST be called before this cursor goes out of scope to prevent leaking resources.
     * This method may be called even if there are unresolved futures created from other `MongoCursor` methods.
     *
     * - Returns:
     *   An `EventLoopFuture` that evaluates when the cursor has completed closing. This future should not fail.
     */
    public func kill() -> EventLoopFuture<Void> {
        return self.client.operationExecutor.execute {
            self.wrappedCursor.kill()
        }
    }
}
