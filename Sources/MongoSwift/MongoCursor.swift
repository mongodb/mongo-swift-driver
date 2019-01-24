import mongoc

/// A MongoDB cursor.
public class MongoCursor<T: Codable>: Sequence, IteratorProtocol {
    private var _cursor: OpaquePointer?
    private var _client: MongoClient?
    private var swiftError: Error?

    private let decoder: BSONDecoder

    /**
     * Initializes a new `MongoCursor` instance, not meant to be instantiated directly.
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if the options passed to the command that generated this cursor formed an
     *     invalid combination.
     */
    internal init(fromCursor: OpaquePointer, withClient: MongoClient, withDecoder: BSONDecoder) throws {
        self._cursor = fromCursor
        self._client = withClient
        self.decoder = withDecoder

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

    /// Deinitializes a `MongoCursor`, cleaning up the internal `mongoc_cursor_t`.
    deinit {
        self.close()
    }

    /// Closes the cursor.
    public func close() {
        self._client = nil
        guard let cursor = self._cursor else {
            return
        }
        mongoc_cursor_destroy(cursor)
        self._cursor = nil
    }

    /**
     * Returns the next `Document` in this cursor or `nil`, or throws an error if one occurs -- compared to `next()`,
     * which returns `nil` and requires manually checking for an error afterward.
     * - Returns: the next `Document` in this cursor, or `nil` if at the end of the cursor
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while iterating the cursor.
     *   - `UserError.logicError` if this function is called after the cursor has died.
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

        var replyPtr = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        defer { replyPtr.deallocate() }

        var error = bson_error_t()
        guard mongoc_cursor_error_document(self._cursor, &error, replyPtr) else {
            return nil
        }

        // If a reply is present, it implies the error occurred on the server. This *should* always be a commandError,
        // but we will still parse the mongoc error to cover all cases.
        if let docPtr = replyPtr.pointee {
            let reply = Document(fromPointer: docPtr)
            return parseMongocError(error, errorLabels: reply["errorLabels"] as? [String])
        }

        // Otherwise, the only feasible error is that the user tried to advance a dead cursor, which is a logic error.
        // We will still parse the mongoc error to cover all cases.
        return parseMongocError(error)
    }

    /// Returns the next `Document` in this cursor, or nil. Once this function returns `nil`, the caller should use
    /// the `.error` property to check for errors.
    public func next() -> T? {
        guard self._cursor != nil else {
            self.swiftError = UserError.logicError(message: "Tried to iterate a closed cursor.")
            return nil
        }

        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }
        guard mongoc_cursor_next(self._cursor, out) else {
            return nil
        }
        // swiftlint:disable:next force_unwrapping - if mongoc_cursor_next returned `true`, this is filled out.
        let doc = Document(fromPointer: out.pointee!)

        do {
            let outDoc = try self.decoder.decode(T.self, from: doc)
            self.swiftError = nil
            return outDoc
        } catch {
            self.swiftError = error
            return nil
        }
    }
}
