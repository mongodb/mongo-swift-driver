import mongoc

/// The entity on which the `next` operation is called.
internal enum NextOperationTarget<T: Codable> {
    /// Indicates the `next` call will be on a cursor.
    case cursor(MongoCursor<T>)

    /// Indicates the `next` call will be on a change stream.
    case changeStream(ChangeStream<T>)
}

/// An operation corresponding to a `next` call on a `NextOperationTarget`.
internal struct NextOperation<T: Codable>: Operation {
    private let target: NextOperationTarget<T>

    internal init(target: NextOperationTarget<T>) {
        self.target = target
    }

    internal func execute(using _: Connection, session: ClientSession?) throws -> T? {
        // NOTE: this method does not actually use the `connection` parameter passed in. for the moment, it is only
        // here so that `NextOperation` conforms to `Operation`. if we eventually rewrite our cursors to no longer
        // wrap a mongoc cursor then we will use the connection here.
        if let session = session, !session.active {
            throw ClientSession.SessionInactiveError
        }

        switch self.target {
        case let .cursor(cursor):
            return try cursor.getNextDocumentFromMongocCursor()
        case let .changeStream(changeStream):
            guard case let .open(changeStreamPtr, _, _, _) = changeStream.state else {
                throw ClosedChangeStreamError
            }

            let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
            defer {
                out.deinitialize(count: 1)
                out.deallocate()
            }

            guard mongoc_change_stream_next(changeStreamPtr, out) else {
                return nil
            }

            guard let pointee = out.pointee else {
                fatalError("The cursor was advanced, but the document is nil")
            }

            // We have to copy because libmongoc owns the pointer.
            let doc = Document(copying: pointee)

            // Update the resumeToken with the `_id` field from the document.
            guard let resumeToken = doc["_id"]?.documentValue else {
                throw InternalError(message: "_id field is missing from the change stream document.")
            }
            changeStream.resumeToken = ResumeToken(resumeToken)
            return try changeStream.decoder.decode(T.self, from: doc)
        }
    }
}
