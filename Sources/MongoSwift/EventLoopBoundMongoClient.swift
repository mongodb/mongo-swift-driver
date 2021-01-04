import NIO

// sourcery: skipSyncExport
/// A wrapper around a `MongoClient` that will return `EventLoopFuture`s on the specified `EventLoop`.
/// - SeeAlso: https://apple.github.io/swift-nio/docs/current/NIO/Classes/EventLoopFuture.html
public struct EventLoopBoundMongoClient {
    /// The underlying `MongoClient`.
    internal let client: MongoClient

    /// The `EventLoop` this `EventLoopBoundMongoClient` will be bound to.
    public let eventLoop: EventLoop

    internal init(client: MongoClient, eventLoop: EventLoop) {
        self.client = client
        self.eventLoop = eventLoop
    }

    /**
     * Retrieves a list of databases in this client's MongoDB deployment. The returned future will be on the
     * `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *
     * - Parameters:
     *   - filter: Optional `BSONDocument` specifying a filter that the listed databases must pass. This filter can be
     *     based on the "name", "sizeOnDisk", "empty", or "shards" fields of the output.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns:
     *    An `EventLoopFuture<[DatabaseSpecification]>` on  the `EventLoop` specified on this
     *   `EventLoopBoundMongoClient`. On success, the future contains an array of the specifications of databases
     *    matching the provided criteria.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this client has already been closed.
     *    - `EncodingError` if an error is encountered while encoding the options to BSON.
     *    - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *       permissions.
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
     * Gets the names of databases in this client's MongoDB deployment. The returned future will be on the
     * `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *
     * - Parameters:
     *   - filter: Optional `BSONDocument` specifying a filter on the names of the returned databases.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[String]>` on the `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *    On success, the future contains an array of names of databases that match the provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this client has already been closed.
     *    - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *       permissions.
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

    /**
     * Gets a `MongoDatabase` instance for the given database name that will return `EventLoopFuture`s on this
     * `EventLoopBoundMongoClient`'s `EventLoop`. If an option is not specified in the optional `MongoDatabaseOptions`
     * param, the database will inherit the value from this `EventLoopBoundMongoClient`'s underlying `MongoClient`
     * or the default if the client’s option is not set.
     * To override an option inherited from the client (e.g. a read concern) with the default value, it must be
     * explicitly specified in the options param (e.g. ReadConcern.serverDefault, not nil).
     *
     * - Parameters:
     *   - name: the name of the database to retrieve
     *   - options: Optional `MongoDatabaseOptions` to use for the retrieved database
     *
     * - Returns:
     *     A `MongoDatabase` that is bound to this `EventLoopBoundMongoClient`'s `EventLoop`.
     */
    public func db(_ name: String, options: MongoDatabaseOptions? = nil) -> MongoDatabase {
        MongoDatabase(name: name, client: self.client, eventLoop: self.eventLoop, options: options)
    }

    /**
     * Starts a `ChangeStream` on this `EventLoopBoundMongoClient`. The returned future will be on the `EventLoop`
     * specified on this `EventLoopBoundMongoClient`.
     * Allows the client to observe all changes in a cluster - excluding system collections and the "config", "local",
     * and "admin" databases.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>` on this `EventLoopBoundMongoClient`'s `EventLoop`. On success, contains a
     *    `ChangeStream` watching all collections in this deployment. The `ChangeStream`'s methods will return futures
     *    on the `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *    - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *      pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch(
        _ pipeline: [BSONDocument] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<ChangeStream<ChangeStreamEvent<BSONDocument>>> {
        self.watch(pipeline, options: options, session: session, withFullDocumentType: BSONDocument.self)
    }

    /**
     * Starts a `ChangeStream` on this `EventLoopBoundMongoClient`. The returned future will be on the `EventLoop`
     * specified on this `EventLoopBoundMongoClient`.
     * Allows the client to observe all changes in a cluster - excluding system collections and the "config", "local",
     * and "admin" databases. Associates the specified `Codable` type `T` with the `fullDocument` field in the
     * `ChangeStreamEvent`s emitted by the returned `ChangeStream`.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the `fullDocument` field of the emitted `ChangeStreamEvent`s will be
     *                           decoded to.
     *
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>` on this `EventLoopBoundMongoClient`'s `EventLoop`. On success, contains a
     *    `ChangeStream` watching all collections in this deployment. The `ChangeStream`'s methods will return futures
     *    on the `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *    - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *      pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<FullDocType: Codable>(
        _ pipeline: [BSONDocument] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withFullDocumentType _: FullDocType.Type
    ) -> EventLoopFuture<ChangeStream<ChangeStreamEvent<FullDocType>>> {
        self.watch(
            pipeline,
            options: options,
            session: session,
            withEventType: ChangeStreamEvent<FullDocType>.self
        )
    }

    /**
     * Starts a `ChangeStream` on this `EventLoopBoundMongoClient`. The returned future will be on the `EventLoop`
     * specified on this `EventLoopBoundMongoClient`. Allows the client to observe all changes in a cluster -
     * excluding system collections and the "config", "local", and "admin" databases. Associates the specified
     * `Codable` type `T` with the returned `ChangeStream`.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withEventType: The type that the entire change stream response will be decoded to and that will be returned
     *                    when iterating through the change stream.
     *
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>` on this `EventLoopBoundMongoClient`'s `EventLoop`. On success, contains a
     *    `ChangeStream` watching all collections in this deployment. The `ChangeStream`'s methods will return futures
     *    on the `EventLoop` specified on this `EventLoopBoundMongoClient`.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *    - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *      pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<EventType: Codable>(
        _ pipeline: [BSONDocument] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withEventType _: EventType.Type
    ) -> EventLoopFuture<ChangeStream<EventType>> {
        let operation = WatchOperation<BSONDocument, EventType>(
            target: .eventLoopBoundClient(self),
            pipeline: pipeline,
            options: options
        )
        return self.client.operationExecutor.execute(
            operation,
            client: self.client,
            on: self.eventLoop,
            session: session
        )
    }
}
