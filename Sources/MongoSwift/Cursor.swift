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
     * Returns the next document in this cursor, or nil
     */
    public func next() -> Document? {
        do {
            _ = try unwrapCursor()
        } catch {
            print("error unwrapping cursor")
            return nil
        }

        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate(capacity: 1)
        }
        var error = bson_error_t()

        if !mongoc_cursor_next(self._cursor, out) {
            if mongoc_cursor_error(self._cursor, &error) {
                print("cursor error: (domain: \(error.domain), code: \(error.code), message: \(toErrorString(error)))")
            }

            return nil
        }

        return Document(fromPointer: UnsafeMutablePointer(mutating: out.pointee!))
    }

    /// This function should be called rather than accessing self._cursor directly.
    /// It ensures that the `OpaquePointer` to a `mongoc_cursor_t` is still valid. 
    internal func unwrapCursor() throws -> OpaquePointer {
        return try unwrap(self._cursor, elseThrow: MongoError.invalidCursor(message: "Invalid cursor"))
    }
}
