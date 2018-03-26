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
        guard let cursor = self._cursor else {
            return
        }

        mongoc_cursor_destroy(cursor)
        self._cursor = nil
        self._client = nil
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

        if !mongoc_cursor_next(self._cursor, out) {
            var error = bson_error_t()
            if mongoc_cursor_error(self._cursor, &error) {
                throw MongoError.invalidCursor(message: toErrorString(error))
            }
            return nil
        }
        return Document(fromPointer: UnsafeMutablePointer(mutating: out.pointee!))
    }

    /**
     *  Returns the error that occurred while iterating this cursor, if one exists. 
     *  This function should be called to check for errors after next() returns nil. 
     */
    func getError() -> Error? {
        var error = bson_error_t()
        if mongoc_cursor_error(self._cursor, &error) {
            return MongoError.invalidCursor(message: toErrorString(error))
        }
        return nil
    }

    /**
     * Returns the next document in this cursor, or nil
     */
    public func next() -> Document? {
        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate(capacity: 1)
        }
        if !mongoc_cursor_next(self._cursor, out) { return nil }
        return Document(fromPointer: UnsafeMutablePointer(mutating: out.pointee!))
    }
}
