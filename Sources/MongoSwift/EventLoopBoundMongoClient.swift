import NIO

/// An event loop bound MongoDB Client.
public struct EventLoopBoundMongoClient {
    /// The underlying `MongoClient`.
    internal let client: MongoClient

    /// The `EventLoop` bound to this `EventLoopBoundMongoClient`.
    internal let eventLoop: EventLoop

    internal init(client: MongoClient, eventLoop: EventLoop) {
        self.client = client
        self.eventLoop = eventLoop
    }

    /**
     * Retrieves a list of databases in this client's MongoDB deployment. The returned future will be bound to the
     * `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *
     * - Parameters:
     *   - filter: Optional `BSONDocument` specifying a filter that the listed databases must pass. This filter can be
     *      based on the "name", "sizeOnDisk", "empty", or "shards" fields of the output.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns:
     *    An `EventLoopFuture<[DatabaseSpecification]>` bound to the `EventLoop` specified on this
     *   `EventLoopBoundMongoClient`. On success, the future contains an array of the specifications of databases
     *    matching the provided criteria.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this client has already been closed.
     *    - `EncodingError` if an error is encountered while encoding the options to BSON.
     *    - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *      permissions.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/listDatabases/
     */
    public func listDatabases(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[DatabaseSpecification]> {
        let operation = ListDatabasesOperation(client: self.client, filter: filter, nameOnly: nil, options: options)
        return self.client.operationExecutor.execute(
            operation,
            client: self.client,
            on: self.eventLoop,
            session: session
        )
        .flatMapThrowing { result in
            guard case let .specs(dbs) = result else {
                throw MongoError.InternalError(message: "Invalid result")
            }
            return dbs
        }
    }

    /**
     * Gets the names of databases in this client's MongoDB deployment. The returned future will be bound to the
     * `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *
     * - Parameters:
     *   - filter: Optional `BSONDocument` specifying a filter on the names of the returned databases.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[String]>` bound to the `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *    On success, the future contains an array of names of databases that match the provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this client has already been closed.
     *    - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *      permissions.
     */
    public func listDatabaseNames(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[String]> {
        let operation = ListDatabasesOperation(client: self.client, filter: filter, nameOnly: true, options: options)
        return self.client.operationExecutor.execute(
            operation,
            client: self.client,
            on: self.eventLoop,
            session: session
        ).flatMapThrowing { result in
            guard case let .names(names) = result else {
                throw MongoError.InternalError(message: "Invalid result")
            }
            return names
        }
    }
}
