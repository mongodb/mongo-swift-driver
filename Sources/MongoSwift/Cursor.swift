// A Cursor
public class Cursor: Sequence, IteratorProtocol {
    /**
        Initializes a new Cursor instance, not meant to be instantiated directly
     */
    public init() {
    }

    /**
        Deinitializes a Cursor, cleaning up the internal mongoc_cursor_t
     */
    deinit {
    }

    /**
     * Close the cursor
     */
    func close() throws {
    }

    /**
     * Returns the next document in this cursor, or nil
     */
    public func next() -> Document? {
        return Document()
    }
}
