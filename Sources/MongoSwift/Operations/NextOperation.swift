import mongoc

/// The entity on which the `next` operation is called.
internal enum NextOperationTarget<T: Codable> {
    /// Indicates the `next` call will be on a MongoCursor.
    case cursor(MongoCursor<T>)

    /// Indicates the `next` call will be on a change stream.
    case changeStream(ChangeStream<T>)
}

/// An operation corresponding to a `next` call on a `NextOperationTarget`.
internal struct NextOperation<T: Codable>: Operation {
    private let target: NextOperationTarget<T>
    internal let connectionStrategy: ConnectionStrategy

    internal init(target: NextOperationTarget<T>, using connection: Connection) {
        self.target = target
        self.connectionStrategy = .bound(to: connection)
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func execute(using _: Connection, session: ClientSession?) throws -> T? {
        // NOTE: this method does not actually use the `connection` parameter passed in. for the moment, it is only
        // here so that `NextOperation` conforms to `Operation`. if we eventually rewrite MongoCursor to no longer
        // wrap a mongoc cursor then we will use the connection here.

        if let session = session, !session.active {
            throw ClientSession.SessionInactiveError
        }

        let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }

        switch self.target {
        case let .cursor(cursor):
            // We already check this in `MongoCursor.next()` in order to extract the relevant connection and session,
            // but error again here just in case.
            guard case let .open(cursorPtr, _, _, _) = cursor.state else {
                throw ClosedCursorError
            }
            guard mongoc_cursor_next(cursorPtr, out) else {
                return nil
            }
        case let .changeStream(changeStream):
            guard case let .open(changeStreamPtr, _, _, _) = changeStream.state else {
                throw ClosedChangeStreamError
            }
            guard mongoc_change_stream_next(changeStreamPtr, out) else {
                return nil
            }
        }

        guard let pointee = out.pointee else {
            fatalError("The cursor was advanced, but the document is nil")
        }

        // We have to copy because libmongoc owns the pointer.
        let doc = Document(copying: pointee)

        switch self.target {
        case let .cursor(cursor):
            return try cursor.decoder.decode(T.self, from: doc)
        case let .changeStream(changeStream):
            // Update the resumeToken with the `_id` field from the document.
            guard let resumeToken = doc["_id"] as? Document else {
                throw RuntimeError.internalError(message: "_id field is missing from the change stream document.")
            }
            changeStream.resumeToken = ResumeToken(resumeToken)
            return try changeStream.decoder.decode(T.self, from: doc)
        }
    }
}
