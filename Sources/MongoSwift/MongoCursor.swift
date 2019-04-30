import mongoc

/// A MongoDB cursor.
public class MongoCursor<T: Codable>: Sequence, IteratorProtocol {
    internal var _cursor: OpaquePointer?
    private var _client: MongoClient?
    internal var _session: ClientSession?

    private var swiftError: Error?

    /// Decoder from the `MongoCollection` or `MongoDatabase` that created this cursor.
    internal let decoder: BSONDecoder

    /**
     * Initializes a new `MongoCursor` instance. Not meant to be instantiated directly by a user.
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(from cursor: OpaquePointer,
                  client: MongoClient,
                  decoder: BSONDecoder,
                  session: ClientSession?) throws {
        self._cursor = cursor
        self._client = client
        self._session = session
        self.decoder = decoder

        if let session = session, !session.active {
            throw ClientSession.SessionInactiveError
        }

        if let err = self.error {
            // Need to explicitly close since deinit will not execute if we throw.
            self.close()

            // Errors in creation of the cursor are limited to invalid argument errors, but some errors are reported
            // by libmongoc as invalid cursor errors. These would be parsed to .logicErrors, so we need to rethrow them
            // as the correct case.
            if let mongoSwiftErr = err as? MongoError {
                throw UserError.invalidArgumentError(message: mongoSwiftErr.errorDescription ?? "")
            }

            throw err
        }
    }

    /// Cleans up internal state.
    deinit {
        self.close()
    }

    /// Closes the cursor.
    public func close() {
        guard let cursor = self._cursor else {
            return
        }
        mongoc_cursor_destroy(cursor)
        self._cursor = nil
        self._client = nil
        self._session = nil
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

    /// The error that occurred while iterating this cursor, if one exists. This should be used to check for errors
    /// after `next()` returns `nil`.
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
        guard mongoc_cursor_error_document(self._cursor, &error, replyPtr) else {
            return nil
        }

        // If a reply is present, it implies the error occurred on the server. This *should* always be a commandError,
        // but we will still parse the mongoc error to cover all cases.
        if let docPtr = replyPtr.pointee {
            // we have to copy because libmongoc owns the pointer.
            let reply = Document(copying: docPtr)
            return parseMongocError(error, errorLabels: reply["errorLabels"] as? [String])
        }

        // Otherwise, the only feasible error is that the user tried to advance a dead cursor, which is a logic error.
        // We will still parse the mongoc error to cover all cases.
        return parseMongocError(error)
    }

    /// Returns the next `Document` in this cursor, or nil. Once this function returns `nil`, the caller should use
    /// the `.error` property to check for errors.
    public func next() -> T? {
        do {
            let operation = NextOperation(cursor: self)
            let out = try operation.execute()
            self.swiftError = nil
            return out
        } catch {
            self.swiftError = error
            return nil
        }
    }
}
