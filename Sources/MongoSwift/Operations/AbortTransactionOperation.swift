import CLibMongoC

/// An operation corresponding to aborting a transaction.
internal struct AbortTransactionOperation: Operation {
    internal func execute(using _: Connection, session: ClientSession?) throws {
        guard let session = session else {
            throw InternalError(message: "No session provided to AbortTransactionOperation")
        }

        let sessionPtr: OpaquePointer
        switch session.state {
        case let .started(ptr, _):
            sessionPtr = ptr
        case .notStarted:
            throw InternalError(message: "Session not started for AbortTransactionOperation")
        case .ended:
            throw LogicError(message: "Tried to abort transaction on an ended session")
        }

        var error = bson_error_t()
        let success = mongoc_client_session_abort_transaction(sessionPtr, &error)
        guard success else {
            throw extractMongoError(error: error)
        }
    }
}
