import CLibMongoC

/// An operation corresponding to committing a transaction.
internal struct CommitTransactionOperation: Operation {
    internal func execute(using _: Connection, session: ClientSession?) throws {
        guard let session = session else {
            throw InternalError(message: "No session provided to CommitTransactionOperation")
        }

        var reply = Document()
        var error = bson_error_t()
        let success = try session.withMongocSession { sessionPtr in
            reply.withMutableBSONPointer { replyPtr in
                mongoc_client_session_commit_transaction(sessionPtr, replyPtr, &error)
            }
        }
        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }
    }
}
