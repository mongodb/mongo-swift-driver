import CLibMongoC
import Foundation
import NIO
import NIOConcurrencyHelpers

internal let ClosedCursorError = LogicError(message: "Cannot advance a completed or failed cursor.")

// sourcery: skipSyncExport
/// A MongoDB cursor.
public class MongoCursor<T: Codable>: Cursor {
    /// Enum for tracking the state of a cursor.
    internal enum State {
        /// Indicates that the cursor is still open. Stores a pointer to the `mongoc_cursor_t`, along with the source
        /// connection, and possibly session to ensure they are kept alive as long as the cursor is.
        case open(cursor: OpaquePointer, connection: Connection, session: ClientSession?)
        case closed
    }

    /// Lock used to synchronize usage of the internal state.
    /// This lock should only be acquired in the bodies of public API methods.
    private let lock: Lock

    /// Atomic variable used to signal long running operations (e.g. `next(...)`) that the cursor is closing.
    private var isClosing: NIOAtomic<Bool>

    /// The state of this cursor.
    internal private(set) var state: State

    /// Indicates whether this is a tailable cursor.
    private let cursorType: CursorType

    /// The client this cursor descended from.
    private let client: MongoClient

    /// Decoder from the client, database, or collection that created this cursor.
    internal let decoder: BSONDecoder

    /// Used to store a cached next value to return, if one exists.
    private enum CachedDocument {
        /// Indicates that the associated value is the next value to return. This value may be nil.
        case cached(T?)
        /// Indicates that there is no value cached.
        case none
    }

    /// Tracks the caching status of this cursor.
    private var cached: CachedDocument

    /**
     * Initializes a new `MongoCursor` instance. Not meant to be instantiated directly by a user. When `forceIO` is
     * true, this initializer will force a connection to the server if one is not already established.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(
        stealing cursor: OpaquePointer,
        connection: Connection,
        client: MongoClient,
        decoder: BSONDecoder,
        session: ClientSession?,
        cursorType: CursorType? = nil
    ) throws {
        self.state = .open(cursor: cursor, connection: connection, session: session)
        self.client = client
        self.cursorType = cursorType ?? .nonTailable
        self.decoder = decoder
        self.cached = .none
        self.lock = Lock()
        self.isClosing = NIOAtomic.makeAtomic(value: false)

        // If there was an error constructing the cursor, throw it.
        if let error = self.getMongocError() {
            self.blockingKill()
            throw error
        }

        let next = try self.getNextDocument()
        self.cached = .cached(next)
    }

    /// Close this cursor
    ///
    /// This method should only be called while the lock is held.
    internal func blockingKill() {
        self.cached = .none
        guard case let .open(cursor, _, _) = self.state else {
            return
        }
        mongoc_cursor_destroy(cursor)
        self.state = .closed
    }

    /// Asserts that the cursor was closed.
    deinit {
        assert(!self.isAlive, "cursor wasn't closed before it went out of scope")
    }

    /// Retrieves the next document from the cache or the underlying `mongoc_cursor_t`, if it exists.
    /// Will close the cursor if the end of the cursor is reached or if an error occurs.
    ///
    /// This method should only be called while the lock is held.
    internal func getNextDocument() throws -> T? {
        if case let .cached(doc) = self.cached {
            self.cached = .none
            return doc
        }

        guard case let .open(cursor, _, session) = self.state else {
            throw ClosedCursorError
        }

        if let session = session, !session.active {
            throw ClientSession.SessionInactiveError
        }

        let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }

        guard mongoc_cursor_next(cursor, out) else {
            if let error = self.getMongocError() {
                self.blockingKill()
                throw error
            }

            // if we've reached the end of the cursor, close it.
            if !self.cursorType.isTailable || !mongoc_cursor_more(cursor) {
                self.blockingKill()
            }

            return nil
        }

        guard let pointee = out.pointee else {
            fatalError("The cursor was advanced, but the document is nil")
        }

        // We have to copy because libmongoc owns the pointer.
        let doc = Document(copying: pointee)
        do {
            return try self.decoder.decode(T.self, from: doc)
        } catch {
            self.blockingKill()
            throw error
        }
    }

    /// Retrieves any error that occurred in mongoc or on the server while iterating the cursor. Returns nil if this
    /// cursor is already closed, or if no error occurred.
    ///
    /// This method should only be called while the lock is held.
    private func getMongocError() -> MongoError? {
        guard case let .open(cursor, _, _) = self.state else {
            return nil
        }

        var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            replyPtr.deinitialize(count: 1)
            replyPtr.deallocate()
        }

        var error = bson_error_t()
        guard mongoc_cursor_error_document(cursor, &error, replyPtr) else {
            return nil
        }

        // If a reply is present, it implies the error occurred on the server. This *should* always be a commandError,
        // but we will still parse the mongoc error to cover all cases.
        if let docPtr = replyPtr.pointee {
            // we have to copy because libmongoc owns the pointer.
            let reply = Document(copying: docPtr)
            return extractMongoError(error: error, reply: reply)
        }

        // The only feasible error here is that we tried to advance a dead mongoc cursor. Due to our cursor-closing
        // logic in `next()` that should never happen, but parse the error anyway just in case we end up here.
        return extractMongoError(error: error)
    }

    /**
     * Indicates whether this cursor has the potential to return more data.
     *
     * This property is mainly useful if this cursor is tailable, since in that case `tryNext` may return more results
     * even after returning `nil`.
     *
     * If this cursor is non-tailable, it will always be dead as soon as either `tryNext` returns `nil` or an error.
     *
     * This cursor will be dead as soon as `next` returns `nil` or an error, regardless of the `CursorType`.
     */
    public var isAlive: Bool {
        if case .open = self.state {
            return true
        } else if case .cached = self.cached {
            return true
        }
        return false
    }

    /// Returns the ID used by the server to track the cursor. `nil` once all results have been fetched from the server.
    public var id: Int64? {
        guard case let .open(cursor, _, _) = self.state else {
            return nil
        }
        let id = mongoc_cursor_get_id(cursor)
        return id == 0 ? nil : id
    }

    /**
     * Consolidate the currently available results of the cursor into an array of type `T`.
     *
     * If this cursor is not tailable, this method will exhaust it.
     *
     * If this cursor is tailable, `all` will only fetch the currently available results, and it
     * may return more data if it is called again while the cursor is still alive.
     *
     * - Returns:
     *    An `EventLoopFuture<[T]>` evaluating to the results currently available to this cursor or an error.
     *
     *    If the future evaluates to an error, that error is likely one of the following:
     *      - `CommandError` if an error occurs while fetching more results from the server.
     *      - `LogicError` if this function is called after the cursor has died.
     *      - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *      - `DecodingError` if an error occurs decoding the server's responses.
     */
    internal func all() -> EventLoopFuture<[T]> {
        return self.client.operationExecutor.execute {
            try self.lock.withLock {
                var results: [T] = []
                while let result = try self.getNextDocument() {
                    results.append(result)
                }
                return results
            }
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
            try self.lock.withLock {
                try self.getNextDocument()
            }
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
            try self.lock.withLock {
                guard self.isAlive else {
                    throw ClosedCursorError
                }

                // Keep trying until either the cursor is killed or a notification has been sent by close
                while self.isAlive && !self.isClosing.load() {
                    if let doc = try self.getNextDocument() {
                        return doc
                    }
                }

                return nil
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
            self.isClosing.store(true)
            self.lock.withLock {
                self.blockingKill()
            }
            self.isClosing.store(false)
        }
    }
}
