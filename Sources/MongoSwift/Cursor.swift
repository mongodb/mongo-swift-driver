import libmongoc

// A Cursor
public class Cursor: Sequence, IteratorProtocol {
    private var _cursor = OpaquePointer(bitPattern: 1)
    private var _client: Client?

    /**
     * Initializes a new Cursor instance, not meant to be instantiated directly
     */
    internal init(fromCursor: OpaquePointer, withClient: Client) {
        self._cursor = fromCursor
        self._client = withClient
    }

    /**
     * Deinitializes a Cursor, cleaning up the internal mongoc_cursor_t
     */
    deinit {
        close()
    }

    /**
     * Close the cursor
     */
    func close() {
        guard let cursor = self._cursor else {
            return
        }

        mongoc_cursor_destroy(cursor)
        self._cursor = nil
        self._client = nil
    }

    /**
     * Returns the next document in this cursor, or nil
     */
    public func next() -> Document? {
        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        var error = bson_error_t()

        if !mongoc_cursor_next(self._cursor, out) {
            if mongoc_cursor_error(self._cursor, &error) {
                print("cursor error: (domain: \(error.domain), code: \(error.code), message: \(toErrorString(error)))")
            }

            return nil
        }

        return Document(fromData: UnsafeMutablePointer(mutating: out.pointee!))
    }
}
