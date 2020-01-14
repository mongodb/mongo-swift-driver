import CLibMongoC
import NIO

internal let ClosedCursorError = LogicError(message: "Cannot advance a completed or failed cursor.")

// sourcery: skipSyncExport
/// A MongoDB cursor.
public class MongoCursor<T: Codable> {
    /// Enum for tracking the state of a cursor.
    internal enum State {
        /// Indicates that the cursor is still open. Stores a pointer to the `mongoc_cursor_t`, along with the source
        /// connection, and possibly session to ensure they are kept alive as long as the cursor is.
        case open(cursor: OpaquePointer, connection: Connection, session: ClientSession?)
        case closed
    }

    /// The state of this cursor.
    internal private(set) var state: State

    /// Indicates whether this is a tailable cursor.
    private let cursorType: CursorType

    /// The client this cursor descended from.
    private let client: MongoClient

    /// Decoder from the client, database, or collection that created this cursor.
    internal let decoder: BSONDecoder

    /**
     * Indicates whether this cursor has the potential to return more data. This property is mainly useful for
     * tailable cursors, where the cursor may be empty but contain more results later on. For non-tailable cursors,
     * the cursor will always be dead as soon as `next()` returns `nil` or a failed `Result`.
     */
    public var isAlive: Bool {
        if case .open = self.state {
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
        // If there was an error constructing the cursor, throw it.
        if let error = self.getMongocError() {
            self.blockingClose()
            throw error
        }

        let next = try self.getNextDocument()
        self.cached = .cached(next)
    }

    private func blockingClose() {
        guard case let .open(cursor, _, _) = self.state else {
            return
        }
        mongoc_cursor_destroy(cursor)
        self.state = .closed
    }

    /// Cleans up internal state.
    public func close() -> EventLoopFuture<Void> {
        return self.client.operationExecutor.execute {
            self.blockingClose()
        }
    }

    /// Closes the cursor if it hasn't been closed already.
    deinit {
        self.blockingClose()
    }

    /// Retrieves the next document from the underlying `mongoc_cursor_t`, if one exists.
    /// Will close the cursor if the end of the cursor is reached or if an error occurs.
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
                self.blockingClose()
                throw error
            }

            // if we've reached the end of the cursor, close it.
            if !self.cursorType.isTailable || !mongoc_cursor_more(cursor) {
                self.blockingClose()
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
            self.blockingClose()
            throw error
        }
    }

    /// Retrieves any error that occurred in mongoc or on the server while iterating the cursor. Returns nil if this
    /// cursor is already closed, or if no error occurred.
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
     * Returns an array of type `T` from this cursor.
     * - Returns: an array of type `T`
     * - Throws:
     *   - `CommandError` if an error occurs while fetching more results from the server.
     *   - `LogicError` if this function is called after the cursor has died.
     *   - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *   - `DecodingError` if an error occurs decoding the server's response.
     */
    public func all() -> EventLoopFuture<[T]> {
        return self.client.operationExecutor.execute {
            var results: [T] = []
            while let result = try self.getNextDocument() {
                results.append(result)
            }
            return results
        }
    }

    /**
     * Returns a `Result` containing the next `T` in this cursor, or an error if one occurred.
     * Returns `nil` if the cursor is exhausted. For tailable cursors,
     * users should also check `isAlive` after this method returns `nil`,
     * to determine if the cursor has the potential to return any more data in the future.
     * - Returns: `nil` if the end of the cursor has been reached, or a `Result`. On success, the
     *   `Result` contains the next `T`, and on failure contains:
     *   - `CommandError` if an error occurs while fetching more results from the server.
     *   - `LogicError` if this function is called after the cursor has died.
     *   - `LogicError` if this function is called and the session associated with this cursor is inactive.
     *   - `DecodingError` if an error occurs decoding the server's response.
     */
    public func next() -> EventLoopFuture<T?> {
        return self.client.operationExecutor.execute {
            try self.getNextDocument()
        }
    }
}
