import mongoc

/// An operation corresponding to a `next` call on a MongoCursor.
internal struct NextOperation<T: Codable>: Operation {
    private let cursor: MongoCursor<T>

    internal init(cursor: MongoCursor<T>) {
        self.cursor = cursor
    }

    internal func execute() throws -> T? {
        guard let cursor = self.cursor._cursor else {
            throw UserError.logicError(message: "Tried to iterate a closed cursor.")
        }

        if let session = self.cursor._session, !session.active {
            throw ClientSession.SessionInactiveError
        }

        let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }
        guard mongoc_cursor_next(cursor, out) else {
            return nil
        }

        guard let pointee = out.pointee else {
            fatalError("mongoc_cursor_next returned true, but document is nil")
        }

        // we have to copy because libmongoc owns the pointer.
        let doc = Document(copying: pointee)
        return try self.cursor.decoder.decode(T.self, from: doc)
    }
}
