/// A protocol for operation types to conform to. An `Operation` instance corresponds to any single operation a user
/// can perform with the driver's API that requires I/O.
internal protocol Operation {
    /// The result type this operation returns.
    associatedtype OperationResult

    /// Executes this operation using the provided connection and optional session, and returns its corresponding
    /// result type.
    func execute(using connection: Connection, session: ClientSession?) throws -> OperationResult
}

/// A protocol for types that can be used to execute `Operation`s.
internal protocol OperationExecutor {
    /// Executes an operation using the provided client and optionally provided session.
    func execute<T: Operation>(
        _ operation: T,
        using connection: Connection?,
        client: MongoClient,
        session: ClientSession?
    ) throws -> T.OperationResult
}

/// Default executor type used by `MongoClient`s.
internal struct DefaultOperationExecutor: OperationExecutor {
    internal func execute<T: Operation>(
        _ operation: T,
        using connection: Connection?,
        client: MongoClient,
        session: ClientSession?
    ) throws -> T.OperationResult {
        // if a session was provided, start it if it hasn't been started already.
        try session?.startIfNeeded()
        // select a connection in following order of priority:
        // 1. connection specifically provided for use with this operation
        // 2. if a session was provided, use its underlying connection
        // 3. a new connection from the pool
        let connection = try connection ?? resolveConnection(client: client, session: session)
        return try operation.execute(using: connection, session: session)
    }
}

/// Given a client and optionally a session associated which are to be associated with an operation, returns a
/// connection for the operation to use. After the connection is no longer in use, it should be returned by
/// passing it to `returnConnection` along with the same client and session that were passed into this method.
internal func resolveConnection(client: MongoClient, session: ClientSession?) throws -> Connection {
    return try session?.getConnection(forUseWith: client) ?? client.connectionPool.checkOut()
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
