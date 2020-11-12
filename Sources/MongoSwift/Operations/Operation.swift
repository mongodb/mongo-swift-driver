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

/// Contains the result of attempting to execute an operation in the thread pool.
private enum ExecuteResult<T> {
    /// Indicates that the operation was successfully executed and returned the associated value.
    case success(T)
    /// Indicates that a connection was not available and the operation should be resubmitted to the pool.
    case resubmit
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
    internal func shutdown() -> EventLoopFuture<Void> {
        let promise = self.eventLoopGroup.next().makePromise(of: Void.self)
        self.threadPool.shutdownGracefully { error in
            if let error = error {
                promise.fail(error)
                return
            }
            promise.succeed(())
        }
        return promise.futureResult
    }

    /// Closes the executor's underlying thread pool synchronously.
    internal func syncShutdown() throws {
        try self.threadPool.syncShutdownGracefully()
    }

    internal func execute<T: Operation>(
        _ operation: T,
        client: MongoClient,
        session: ClientSession?
    ) -> EventLoopFuture<T.OperationResult> {
        // closure containing the work to run in the thread pool: obtain a connection and execute the operation.
        let doOperation = { () -> ExecuteResult<T.OperationResult> in
            // if a session was provided, use its underlying connection. otherwise, use a new connection from the pool
            // if available.
            guard let connection =
                try session?.getConnection(forUseWith: client) ??
                client.connectionPool.tryCheckOut()
            else {
                return .resubmit
            }
            return try .success(operation.execute(using: connection, session: session))
        }

        // if a connection isn't immediately available, we exit the thread pool and resubmit the operation. we can't
        // just block until one is available within the pool because it can lead to deadlock. one such scenario:
        // - connection pool size 4, thread pool size 2
        // - 4 cursors are created, each one holding onto a connection
        // - user issues 2 commands that generate 2 new operations and block both threads in the pool
        // - cursors can't finish iterating and give up their connections, because they need threads, but ops in pool
        //   can't complete and free up threads, because they need connections!
        let resubmitIfNeeded = { (result: ExecuteResult<T.OperationResult>) -> EventLoopFuture<T.OperationResult> in
            switch result {
            case let .success(res):
                return self.makeSucceededFuture(res)
            case .resubmit:
                return self.execute(operation, client: client, session: session)
            }
        }

        if let session = session {
            // start the session if needed (which generates a new operation itself), and then execute the operation.
            return session.startIfNeeded()
                .flatMap { self.execute(doOperation) }
                .flatMap { resubmitIfNeeded($0) }
        }

        // no session was provided, so we can just jump to executing the operation.
        return self.execute(doOperation).flatMap { resubmitIfNeeded($0) }
    }

    internal func execute<T>(_ body: @escaping () throws -> T) -> EventLoopFuture<T> {
        self.threadPool.runIfActive(eventLoop: self.eventLoopGroup.next(), body)
    }

    internal func makeFailedFuture<T>(_ error: Error) -> EventLoopFuture<T> {
        self.eventLoopGroup.next().makeFailedFuture(error)
    }

    internal func makeSucceededFuture<T>(_ value: T) -> EventLoopFuture<T> {
        self.eventLoopGroup.next().makeSucceededFuture(value)
    }

    internal func makePromise<T>(of type: T.Type) -> EventLoopPromise<T> {
        self.eventLoopGroup.next().makePromise(of: type)
    }
}

/// Internal function for generating an options `BSONDocument` for passing to libmongoc.
internal func encodeOptions<T: Encodable>(options: T?, session: ClientSession?) throws -> BSONDocument? {
    guard options != nil || session != nil else {
        return nil
    }

    var doc = try BSONEncoder().encode(options) ?? BSONDocument()
    try session?.append(to: &doc)
    return doc
}
