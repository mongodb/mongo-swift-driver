import libmongoc

// A Cursor
public class Cursor: Sequence, IteratorProtocol {
    private var _cursor = OpaquePointer(bitPattern: 1)

    /// get rid of this
    init() {}

    /**
     * Initializes a new Cursor instance, not meant to be instantiated directly
     */
    public init(fromCursor: OpaquePointer) {
        self._cursor = fromCursor
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
    }

    /**
     * Returns the next document in this cursor, or nil
     */
    public func next() -> Document? {
        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        var error = bson_error_t()

        if !mongoc_cursor_next(self._cursor, out) {
            if mongoc_cursor_error(self._cursor, &error) {
                print("cursor error: (domain: \(error.domain), code: \(error.code), message: \(error.message))")
            }

            return nil
        }

        return Document(fromData: UnsafeMutablePointer(mutating: out.pointee!))
    }
}
