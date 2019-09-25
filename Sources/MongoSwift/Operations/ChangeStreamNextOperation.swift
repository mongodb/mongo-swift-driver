import mongoc

/// An operation corresponding to a `next` call on a ChangeStream.
internal struct ChangeStreamNextOperation<T: Codable>: Operation {
    private let changeStream: ChangeStream<T>

    internal init(changeStream: ChangeStream<T>) {
        self.changeStream = changeStream
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> T? {
        // We already check this in `ChangeStream.next()` in order to extract the relevant connection and session,
        // but error again here just in case.
        guard case let .open(changeStreamPtr, _, _, _) = changeStream.state else {
            throw ClosedChangeStreamError
        }

        // Allocate space for a reference to a BSON pointer.
        let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            out.deinitialize(count: 1)
            out.deallocate()
        }

        guard mongoc_change_stream_next(changeStreamPtr, out) else {
            return nil
        }

        guard let pointee = out.pointee else {
            fatalError("The change stream was advanced, but the document is nil.")
        }

        // we have to copy because libmongoc owns the pointer.
        let doc = Document(copying: pointee)

        // Update the resumeToken with the `_id` field from the document.
        guard let resumeToken = doc["_id"] as? Document else {
            throw RuntimeError.internalError(message: "_id field is missing from the change stream document.")
        }
        self.changeStream.resumeToken = ResumeToken(resumeToken)

        return try self.changeStream.decoder.decode(T.self, from: doc)
    }
}
