import libmongoc

/// A MongoDB cursor.
public class MongoCursor<T: Codable>: Sequence, IteratorProtocol {
    private var _cursor: OpaquePointer?
    private var _client: MongoClient?
    private var decodeError: Error?

    /// Initializes a new `MongoCursor` instance, not meant to be instantiated directly.
    internal init(fromCursor: OpaquePointer, withClient: MongoClient) {
        self._cursor = fromCursor
        self._client = withClient
    }

    /// Deinitializes a `MongoCursor`, cleaning up the internal `mongoc_cursor_t`.
    deinit {
        close()
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

    /// Returns the next `Document` in this cursor or `nil`, or throws an error if one occurs -- compared to `next()`, 
    /// which returns `nil` and requires manually checking for an error afterward.
    /// - returns: the next `Document` in this cursor, or `nil` if at the end of the cursor
    /// - throws: an error if one occurs while iterating
    public func nextOrError() throws -> T? {
        if let next = self.next() { return next }
        if let error = self.error { throw error }
        return nil
    }

    /// The error that occurred while iterating this cursor, if one exists. This should be used to check for errors 
    /// after `next()` returns `nil`.
    public var error: Error? {
        if let err = self.decodeError { return err }
        var error = bson_error_t()
        if mongoc_cursor_error(self._cursor, &error) {
            return MongoError.invalidCursor(message: toErrorString(error))
        }
        return nil
    }

    /// Returns the next `Document` in this cursor, or nil. Once this function returns `nil`, the caller should use 
    /// the `.error` property to check for errors.
    public func next() -> T? {
        let out = UnsafeMutablePointer<UnsafePointer<bson_t>?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate(capacity: 1)
        }
        if !mongoc_cursor_next(self._cursor, out) { return nil }
        let doc = Document(fromPointer: out.pointee!)

        do {
            return try BsonDecoder().decode(T.self, from: doc)
        } catch {
            self.decodeError = error
            return nil
        }
    }
}
