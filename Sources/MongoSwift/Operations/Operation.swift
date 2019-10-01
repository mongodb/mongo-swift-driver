/// A protocol for operation types to conform to. An `Operation` instance corresponds to any single operation a user
/// can perform with the driver's API that requires I/O.
internal protocol Operation {
    /// The result type this operation returns.
    associatedtype OperationResult
    /// Indicates how this operation interactions with `Connection`s.
    var connectionUsage: ConnectionUsage { get }

    /// Executes this operation using the provided connection and optional session, and returns its corresponding
    /// result type.
    func execute(using connection: Connection, session: ClientSession?) throws -> OperationResult
}

extension Operation {
    /// This is the behavior of most operations so default to this.
    internal var connectionUsage: ConnectionUsage { return .uses }
}

/// Uses to indicate how an `Operation` type uses `Connection`s passed to its execute method.
internal enum ConnectionUsage {
    /// This operation will "steal" the connection passed to its execute method, saving it for later usage and taking
    /// over responsibility for later returning it to the pool. This applies to e.g. `WatchOperation` where the
    /// resulting `ChangeStream` will hold onto its source `Connection` until deinitialization.
    case steals
    /// This operation is already holding onto the provided connection, which should be used to execute it. This
    /// applies to e.g. `NextOperation` where the operation must use its parent cursor's source connection rather than
    /// an arbitrary one from the pool.
    case owns(Connection)
    /// This operation will use the connection provided to its execute method to execute itself. It will not save it or
    /// pass it off for later usage. This applies to the majority of operations.
    case uses
}

/// A protocol for types that can be used to execute `Operation`s.
internal protocol OperationExecutor {
    /// Executes an operation using the provided client and optionally provided session.
    func execute<T: Operation>(_ operation: T,
                               client: MongoClient,
                               session: ClientSession?) throws -> T.OperationResult
}

/// Default executor type used by `MongoClient`s.
internal struct DefaultOperationExecutor: OperationExecutor {
    internal func execute<T: Operation>(_ operation: T,
                                        client: MongoClient,
                                        session: ClientSession?) throws -> T.OperationResult {
        switch operation.connectionUsage {
        case .steals:
            // don't return the connection to the pool, as the operation will handle it
            let conn = try session?.getConnection(forUseWith: client) ?? client.connectionPool.checkOut()
            return try operation.execute(using: conn, session: session)
        case let .owns(conn):
            // pass in the connection this operation already owns
            return try operation.execute(using: conn, session: session)
        case .uses:
            // if a session was provided, use its underlying connection
            if let session = session {
                let conn = try session.getConnection(forUseWith: client)
                return try operation.execute(using: conn, session: session)
            }
            // otherwise use a new connection from the pool
            return try client.connectionPool.withConnection { conn in
                try operation.execute(using: conn, session: nil)
            }
        }
    }
}

/// Internal function for generating an options `Document` for passing to libmongoc.
internal func encodeOptions<T: Encodable>(options: T?, session: ClientSession?) throws -> Document? {
    guard options != nil || session != nil else {
        return nil
    }

    var doc = try BSONEncoder().encode(options) ?? Document()
    try session?.append(to: &doc)
    return doc
}
