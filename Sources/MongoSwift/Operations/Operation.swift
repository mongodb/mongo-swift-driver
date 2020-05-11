/// A protocol for operation types to conform to. An `Operation` instance corresponds to any single operation a user
/// can perform with the driver's API that requires I/O.
internal protocol Operation {
    /// The result type this operation returns.
    associatedtype OperationResult
    /// Indicates how this operation interacts with `Connection`s.
    var connectionStrategy: ConnectionStrategy { get }

    /// Executes this operation using the provided connection and optional session, and returns its corresponding
    /// result type.
    func execute(using connection: Connection, session: ClientSession?) throws -> OperationResult
}

extension Operation {
    /// This is the behavior of most operations, so default to this.
    internal var connectionStrategy: ConnectionStrategy { .unbound }
}

/// Uses to indicate how an `Operation` type uses `Connection`s passed to its execute method.
internal enum ConnectionStrategy {
    /// This operation is already bound to the provided connection based on the context it was created in. This
    /// connection must be used to execute it. This applies to e.g. `NextOperation` where the operation must use its
    /// parent cursor's source connection rather than an arbitrary one from the pool.
    case bound(to: Connection)
    /// This operation will use the connection provided to its execute method to execute itself. It will not save it or
    /// pass it off for later usage. This applies to the majority of operations.
    case unbound
}

/// A protocol for types that can be used to execute `Operation`s.
internal protocol OperationExecutor {
    /// Executes an operation using the provided client and optionally provided session.
    func execute<T: Operation>(
        _ operation: T,
        client: MongoClient,
        session: ClientSession?
    ) throws -> T.OperationResult
}

/// Default executor type used by `MongoClient`s.
internal struct DefaultOperationExecutor: OperationExecutor {
    internal func execute<T: Operation>(
        _ operation: T,
        client: MongoClient,
        session: ClientSession?
    ) throws -> T.OperationResult {
        switch operation.connectionStrategy {
        case let .bound(conn):
            // pass in the connection this operation is already bound to
            return try operation.execute(using: conn, session: session)
        case .unbound:
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

/// Given a client and optionally a session associated which are to be associated with an operation, returns a
/// connection for the operation to use. After the connection is no longer in use, it should be returned by
/// passing it to `returnConnection` along with the same client and session that were passed into this method.
internal func resolveConnection(client: MongoClient, session: ClientSession?) throws -> Connection {
    try session?.getConnection(forUseWith: client) ?? client.connectionPool.checkOut()
}

/// Handles releasing a connection that was returned by `resolveConnection`. Must be called with the same client and
/// session that were passed to `resolveConnection`.
internal func releaseConnection(connection: Connection, client: MongoClient, session: ClientSession?) {
    if session == nil {
        client.connectionPool.checkIn(connection)
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
