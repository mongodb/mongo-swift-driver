import mongoc

/// An operation corresponding to a `next` call on a MongoCursor.
internal struct NextOperation<T: Codable>: Operation {
    private let cursor: MongoCursor<T>

    internal init(cursor: MongoCursor<T>) {
        self.cursor = cursor
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> T? {
        // NOTE: this method does not actually use the `connection` parameter passed in. for the moment, it is only
        // here so that `NextOperation` conforms to `Operation`. if we eventually rewrite MongoCursor to no longer
        // wrap a mongoc cursor then we will use the connection here.

        if let session = session, !session.active {
            throw ClientSession.SessionInactiveError
        }

        guard case let .open(cursorPtr, _, _, _) = cursor.state else {
            return nil
        }

        let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }
        guard mongoc_cursor_next(cursorPtr, out) else {
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
