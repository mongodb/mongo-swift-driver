import NIO

/// A protocol for operation types to conform to. An `Operation` instance corresponds to any single operation a user
/// can perform with the driver's API that requires I/O.
internal protocol Operation {
    /// The result type this operation returns.
    associatedtype OperationResult

    /// Executes this operation using the provided connection and optional session, and returns its corresponding
    /// result type.
    func execute(using connection: Connection, session: ClientSession?) throws -> OperationResult
}

/// Operation executor used by `MongoClient`s.
internal class OperationExecutor {
    /// A group of event loops to use for running operations in the thread pool.
    private let eventLoopGroup: EventLoopGroup
    /// The thread pool to execute operations in.
    private let threadPool: NIOThreadPool

    internal init(eventLoopGroup: EventLoopGroup, threadPoolSize: Int) {
        self.eventLoopGroup = eventLoopGroup
        self.threadPool = NIOThreadPool(numberOfThreads: threadPoolSize)
        self.threadPool.start()
    }

    /// Closes the executor's underlying thread pool.
    internal func close() -> EventLoopFuture<Void> {
        let promise = self.eventLoopGroup.next().makePromise(of: Void.self)
        self.threadPool.shutdownGracefully { error in
            if let error = error {
                promise.fail(error)
                return
            }
            promise.succeed(Void())
        }
        return promise.futureResult
    }

    /// Closes the executor's underlying thread pool synchronously.
    internal func syncClose() throws {
        try self.threadPool.syncShutdownGracefully()
    }

    internal func execute<T: Operation>(
        _ operation: T,
        using connection: Connection? = nil,
        client: MongoClient,
        session: ClientSession?
    ) -> EventLoopFuture<T.OperationResult> {
        guard !client.isClosed else {
            return self.makeFailedFuture(MongoClient.ClosedClientError)
        }

        let doOperation = { () -> T.OperationResult in
            // select a connection in following order of priority:
            // 1. connection specifically provided for use with this operation
            // 2. if a session was provided, use its underlying connection
            // 3. a new connection from the pool
            let connection = try connection ?? resolveConnection(client: client, session: session)
            return try operation.execute(using: connection, session: session)
        }

        if let session = session {
            if case .ended = session.state {
                return self.makeFailedFuture(ClientSession.SessionInactiveError)
            }
            guard session.client == client else {
                return self.makeFailedFuture(ClientSession.ClientMismatchError)
            }

            // start the session if needed (which generates a new operation itself), and then execute the operation.
            return session.startIfNeeded().flatMap { self.execute(doOperation) }
        }

        // no session was provided, so we can just jump to executing the operation.
        return self.execute(doOperation)
    }

    internal func execute<T>(_ body: @escaping () throws -> T) -> EventLoopFuture<T> {
        return self.threadPool.runIfActive(eventLoop: self.eventLoopGroup.next(), body)
    }

    internal func makeFailedFuture<T>(_ error: Error) -> EventLoopFuture<T> {
        return self.eventLoopGroup.next().makeFailedFuture(error)
    }

    internal func makeSucceededFuture<T>(_ value: T) -> EventLoopFuture<T> {
        return self.eventLoopGroup.next().makeSucceededFuture(value)
    }

    internal func makePromise<T>(of type: T.Type) -> EventLoopPromise<T> {
        return self.eventLoopGroup.next().makePromise(of: type)
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
