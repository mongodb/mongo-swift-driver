import libmongoc

// A Cursor
public class MongoCursor: Sequence, IteratorProtocol {
    private var _cursor = OpaquePointer(bitPattern: 1)
    private var _client: MongoClient?

    /**
     * Initializes a new MongoCursor instance, not meant to be instantiated directly
     */
    internal init(fromCursor: OpaquePointer, withClient: MongoClient) {
        self._cursor = fromCursor
        self._client = withClient
    }

    /**
     * Deinitializes a MongoCursor, cleaning up the internal mongoc_cursor_t
     */
    deinit {
        close()
    }

    /**
     * Close the cursor
     */
    public func close() {
        self._client = nil
        guard let cursor = self._cursor else {
            return
        }

        mongoc_cursor_destroy(cursor)
        self._cursor = nil
    }

    /**
     * Returns the next document in this cursor, or nil. Throws an error if one
     * occurs. (Compared to next(), which returns nil and requires manually checking
     * for an error afterward.)
     *
     */
    func nextOrError() throws -> Document? {
        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate(capacity: 1)
        }
        let cursor = try unwrapCursor()
        if !mongoc_cursor_next(cursor, out) {
            var error = bson_error_t()
            if mongoc_cursor_error(cursor, &error) {
                throw MongoError.invalidCursor(message: toErrorString(error))
            }
            return nil
        }
        return Document(fromData: UnsafeMutablePointer(mutating: out.pointee!))
    }

    /**
     *  Returns the error that occurred while iterating this cursor, if one exists. 
     *  This function should be called after next() returns nil. 
     *
     */
    func getError() -> Error? {
        do {
            let cursor = try unwrapCursor()
            var error = bson_error_t()
            if mongoc_cursor_error(cursor, &error) {
                return MongoError.invalidCursor(message: toErrorString(error))
            }
            return nil
        } catch { return error }
    }

    /**
     * Returns the next document in this cursor, or nil. 
     * Once the cursor returns nil, getError() should be called to check if there were any errors
     * iterating the cursor. 
     * 
     * This function, part of `IteratorProtocol`, allows you to iterate a cursor with a `for` loop: 
     *      `for doc in cursor { ... }`
     */
    public func next() -> Document? {
        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate(capacity: 1)
        }
        do {
            let cursor = try unwrapCursor()
            if !mongoc_cursor_next(cursor, out) { return nil }
            return Document(fromData: UnsafeMutablePointer(mutating: out.pointee!))
        } catch { return nil }
    }

    /// This function should be called rather than accessing self._cursor directly.
    /// It ensures that the `OpaquePointer` to a `mongoc_cursor_t` is still valid. 
    internal func unwrapCursor() throws -> OpaquePointer {
        guard let cursor = self._cursor else {
            throw MongoError.invalidCursor(message: "Invalid cursor")
        }
        return cursor
    }
}
