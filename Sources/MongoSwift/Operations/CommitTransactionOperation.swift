import CLibMongoC

/// An operation corresponding to committing a transaction.
internal struct CommitTransactionOperation: Operation {
    internal func execute(using _: Connection, session: ClientSession?) throws {
        guard let session = session else {
            throw InternalError(message: "No session provided to CommitTransactionOperation")
        }

        // session either was not started or ended
        guard case let .started(sessionPtr, _) = session.state else {
            return
        }

        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_client_session_commit_transaction(sessionPtr, replyPtr, &error)
        }
        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }
    }
}
