import CLibMongoC

/// An operation corresponding to aborting a transaction.
internal struct AbortTransactionOperation: Operation {
    internal func execute(using _: Connection, session: ClientSession?) throws {
        guard let session = session else {
            throw InternalError(message: "No session provided to AbortTransactionOperation")
        }

        // session either was not started or ended
        guard case let .started(sessionPtr, _) = session.state else {
            return
        }

        var error = bson_error_t()
        let success = mongoc_client_session_abort_transaction(sessionPtr, &error)
        guard success else {
            throw extractMongoError(error: error)
        }
    }
}
