import CLibMongoC

/// Options to use when starting a transaction.
public struct TransactionOptions {
    /// The maximum amount of time to allow a single `commitTransaction` command to run.
    public var maxCommitTimeMS: Int64?

    /// The `ReadConcern` to use for this transaction.
    public var readConcern: ReadConcern?

    /// The `ReadPreference` to use for this transaction.
    public var readPreference: ReadPreference?

    /// The `WriteConcern` to use for this transaction.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(
        maxCommitTimeMS: Int64? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.maxCommitTimeMS = maxCommitTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.writeConcern = writeConcern
    }
}

/// Internal helper function for providing a `mongoc_transaction_opt_t` that is only valid within the body of the
/// provided closure.
internal func withMongocTransactionOpts<T>(
    copying options: TransactionOptions?,
    _ body: (OpaquePointer) throws -> T
) rethrows -> T {
    let optionsPtr: OpaquePointer = mongoc_transaction_opts_new()
    defer { mongoc_transaction_opts_destroy(optionsPtr) }

    if let readConcern = options?.readConcern {
        readConcern.withMongocReadConcern { rcPtr in
            mongoc_transaction_opts_set_read_concern(optionsPtr, rcPtr)
        }
    }

    if let writeConcern = options?.writeConcern {
        writeConcern.withMongocWriteConcern { wcPtr in
            mongoc_transaction_opts_set_write_concern(optionsPtr, wcPtr)
        }
    }

    if let rpPtr = options?.readPreference?.pointer {
        mongoc_transaction_opts_set_read_prefs(optionsPtr, rpPtr)
    }

    if let maxCommitTimeMS = options?.maxCommitTimeMS {
        mongoc_transaction_opts_set_max_commit_time_ms(optionsPtr, maxCommitTimeMS)
    }

    return try body(optionsPtr)
}

/// An operation corresponding to starting a transaction.
internal struct StartTransactionOperation: Operation {
    /// The options to use when starting this transaction.
    private let options: TransactionOptions?

    internal init(options: TransactionOptions?) {
        self.options = options
    }

    internal func execute(using _: Connection, session: ClientSession?) throws {
        guard let session = session else {
            throw InternalError(message: "No session provided to StartTransactionOperation")
        }

        let sessionPtr: OpaquePointer
        switch session.state {
        case let .started(ptr, _):
            sessionPtr = ptr
        case .notStarted:
            throw InternalError(message: "Session not started for StartTransactionOperation")
        case .ended:
            throw LogicError(message: "Tried to start transaction on an ended session")
        }

        try withMongocTransactionOpts(copying: self.options) { opts in
            var error = bson_error_t()
            let success = mongoc_client_session_start_transaction(sessionPtr, opts, &error)
            guard success else {
                throw extractMongoError(error: error)
            }
        }
    }
}
