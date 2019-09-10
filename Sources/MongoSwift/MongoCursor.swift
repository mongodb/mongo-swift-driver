import mongoc

internal let ClosedCursorError = UserError.logicError(message: "Cannot advance a completed or failed cursor.")

/// A MongoDB cursor.
public class MongoCursor<T: Codable>: Sequence, IteratorProtocol {
    /// Enum for tracking the state of a cursor.
    internal enum State {
        /// Indicates that the cursor is still open. Stores a pointer to the `mongoc_cursor_t`, along with the source
        /// connection, client, and possibly session to ensure they are kept alive as long as the cursor is.
        case open(cursor: OpaquePointer, connection: Connection, client: MongoClient, session: ClientSession?)
        case closed
    }

    /// The state of this cursor.
    internal private(set) var state: State

    /// The error that occurred while iterating this cursor, if one exists. This should be used to check for errors
    /// after `next()` returns `nil`.
    public private(set) var error: Error?

    /// Indicates whether this is a tailable cursor.
    private let cursorType: CursorType

    /// Decoder from the `MongoCollection` or `MongoDatabase` that created this cursor.
    internal let decoder: BSONDecoder

    /**
     * Indicates whether this cursor has the potential to return more data. This property is mainly useful for
     * tailable cursors, where the cursor may be empty but contain more results later on. For non-tailable cursors,
     * the cursor will always be dead as soon as `next()` returns `nil`, or as soon as `nextOrError()` returns `nil` or
     * throws an error.
     */
    public var isAlive: Bool {
        if case .open = self.state {
            return true
        }
        return false
    }

    /// Returns the ID used by the server to track the cursor. `nil` until mongoc actually talks to the server by
    /// iterating the cursor, and `nil` after mongoc has fetched all the results from the server.
    internal var id: Int64? {
        guard case let .open(cursor, _, _, _) = self.state else {
            return nil
        }
        let id = mongoc_cursor_get_id(cursor)
        return id == 0 ? nil : id
    }

    /**
     * Initializes a new `MongoCursor` instance. Not meant to be instantiated directly by a user.
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(client: MongoClient,
                  decoder: BSONDecoder,
                  session: ClientSession?,
                  cursorType: CursorType? = nil,
                  initializer: (Connection) -> OpaquePointer) throws {
        let connection = try session?.getConnection(forUseWith: client) ?? client.connectionPool.checkOut()
        let cursor = initializer(connection)
        self.state = .open(cursor: cursor, connection: connection, client: client, session: session)
        self.cursorType = cursorType ?? .nonTailable
        self.decoder = decoder
        self.error = nil

        if let err = self.getMongocError() {
            // Errors in creation of the cursor are limited to invalid argument errors, but some errors are reported
            // by libmongoc as invalid cursor errors. These would be parsed to .logicErrors, so we need to rethrow them
            // as the correct case.
            throw UserError.invalidArgumentError(message: err.errorDescription ?? "")
        }
    }

    /// Cleans up internal state.
    private func close() {
        guard case let .open(cursor, conn, client, session) = self.state else {
            return
        }
        // If the cursor was created with a session, then the session owns the connection.
        if session == nil {
            client.connectionPool.checkIn(conn)
        }
        mongoc_cursor_destroy(cursor)
        self.state = .closed
    }

    /// Closes the cursor if it hasn't been closed already.
    deinit {
        self.close()
    }

    /**
     * Returns the next `Document` in this cursor or `nil`, or throws an error if one occurs -- compared to `next()`,
     * which returns `nil` and requires manually checking for an error afterward.
     * - Returns: the next `Document` in this cursor, or `nil` if at the end of the cursor
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while iterating the cursor.
     *   - `UserError.logicError` if this function is called after the cursor has died.
     *   - `UserError.logicError` if this function is called and the session associated with this cursor is inactive.
     *   - `DecodingError` if an error occurs decoding the server's response.
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

    /// Retrieves any error that occurred in mongoc or on the server while iterating the cursor. Returns nil if this
    /// cursor is already closed, or if no error occurred.
    private func getMongocError() -> MongoError? {
        guard case let .open(cursor, _, _, _) = self.state else {
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

    /// Returns the next `Document` in this cursor, or `nil`. After this function returns `nil`, the caller should use
    /// the `.error` property to check for errors. For tailable cursors, users should also check `isAlive` after this
    /// method returns `nil`, to determine if the cursor has the potential to return any more data in the future.
    public func next() -> T? {
        // We already closed the mongoc cursor, either because we reached the end or encountered an error.
        guard case let .open(cursor, conn, _, session) = self.state else {
            self.error = ClosedCursorError
            return nil
        }

        do {
            let operation = NextOperation(cursor: self)
            guard let out = try operation.execute(using: conn, session: session) else {
                self.error = self.getMongocError()
                // Since there was no document returned, we should close the cursor if:
                // 1. this is not a tailable cursor, or
                // 2. this is a tailable cursor and an error occurred, or
                // 3. this is a tailable cursor that will not possibly return any more data
                if !self.cursorType.isTailable || self.error != nil || !mongoc_cursor_more(cursor) {
                    self.close()
                }
                return nil
            }
            return out
        } catch {
            // This indicates that an error occurred executing the `NextOperation`. Currently the only possible error
            // is a `DecodingError` when decoding a `Document` to this cursor's type.
            self.error = error
            // Since we encountered an error, close the cursor.
            self.close()
            return nil
        }
    }
}
