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
    func execute<T: Operation>(_ operation: T,
                               client: MongoClient,
                               session: ClientSession?) throws -> T.OperationResult
}

/// Default executor type used by `MongoClient`s.
internal struct DefaultOperationExecutor: OperationExecutor {
    internal func execute<T: Operation>(_ operation: T,
                                        client: MongoClient,
                                        session: ClientSession?) throws -> T.OperationResult {
        // TODO SWIFT-374: if session is non-nil, use its underlying Connection
        return try client.connectionPool.withConnection { conn in
            try operation.execute(using: conn, session: session)
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
