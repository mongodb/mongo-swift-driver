import CLibMongoC

/// An operation corresponding to committing a transaction.
internal struct CommitTransactionOperation: Operation {
    internal func execute(using _: Connection, session: ClientSession?) throws {
        guard let session = session else {
            throw MongoError.InternalError(message: "No session provided to CommitTransactionOperation")
        }

        try session.withMongocSession { sessionPtr in
            try withStackAllocatedMutableBSONPointer { replyPtr in
                var error = bson_error_t()
                guard mongoc_client_session_commit_transaction(sessionPtr, replyPtr, &error) else {
                    throw extractMongoError(error: error, reply: BSONDocument(copying: replyPtr))
                }
            }
        }
    }
}
