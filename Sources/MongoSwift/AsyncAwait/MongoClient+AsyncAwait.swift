#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)
/// Extension to `MongoClient` to support async/await APIs.
extension MongoClient {
    /**
     * Closes this `MongoClient`, closing all connections to the server and cleaning up internal state.
     *
     * Call this method exactly once when you are finished using the client.
     *
     * This function will not complete until all cursors and change streams created from this client have been
     * been killed, and all sessions created from this client have been ended.
     *
     * You must `await` the result of this method before shutting down the `EventLoopGroup` provided to this client's
     * constructor.
     */
    public func close() async throws {
        try await self.close().get()
    }

    /**
     * Starts a new `ClientSession` with the provided options and passes it to the provided closure. The session must
     * be explicitly passed as an argument to each command within the closure that should be executed as part of the
     * session.
     *
     * The session is only valid within the body of the closure and will be ended after the body completes.
     *
     * `ClientSession`s are _not_ thread safe so you must ensure the session is not used concurrently for multiple
     * operations.
     *
     * - Parameters:
     *   - options: Options to use when creating the session.
     *   - sessionBody: An `async` closure which takes in a `ClientSession` and returns a `T`.
     *
     * - Returns:
     *    A `T`, the return value of the user-provided closure.
     *
     * - Throws:
     *   - `RuntimeError.CompatibilityError` if the deployment does not support sessions.
     */
    public func withSession<T>(
        options: ClientSessionOptions? = nil,
        _ sessionBody: (ClientSession) async throws -> T
    ) async throws -> T {
        let session = self.startSession(options: options)
        return try await sessionBody(session)
    }

    /**
     * Run the `listDatabases` command.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter that the listed databases must pass. This filter can be based
     *     on the "name", "sizeOnDisk", "empty", or "shards" fields of the output.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `[DatabaseSpecification]` containing the databases matching provided criteria.
     *
     * - Throws:
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error is encountered while encoding the options to BSON.
     *   - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *     permissions.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/listDatabases/
     */
    public func listDatabases(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> [DatabaseSpecification] {
        try await self.listDatabases(filter, options: options, session: session).get()
    }

    /**
     * Get a list of `MongoDatabase`s.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An Array of `MongoDatabase`s that match the provided filter.
     *
     * - Throws:
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *     permissions.
     */
    public func listMongoDatabases(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> [MongoDatabase] {
        try await self.listDatabaseNames(filter, options: options, session: session).map { self.db($0) }
    }

    /**
     * Get a list of names of databases.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `[String]` containing names of databases that match the provided filter.
     *
     * - Throws:
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *     permissions.
     */
    public func listDatabaseNames(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> [String] {
        try await self.listDatabaseNames(filter, options: options, session: session).get()
    }

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster -
     * excluding system collections and the "config", "local", and "admin" databases.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *
     * - Returns: a `ChangeStream` on all collections in all databases in a cluster.
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *   - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
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
    ) async throws -> ChangeStream<ChangeStreamEvent<BSONDocument>> {
        try await self.watch(
            pipeline,
            options: options,
            session: session,
            withEventType: ChangeStreamEvent<BSONDocument>.self
        )
    }

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster -
     * excluding system collections and the "config", "local", and "admin" databases. Associates the specified
     * `Codable` type `T` with the `fullDocument` field in the `ChangeStreamEvent`s emitted by the returned
     * `ChangeStream`.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the `fullDocument` field of the emitted `ChangeStreamEvent`s will be
     *                           decoded to.
     *
     * - Returns: A `ChangeStream` on all collections in all databases in a cluster.
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *   - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
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
    ) async throws -> ChangeStream<ChangeStreamEvent<FullDocType>> {
        try await self.watch(
            pipeline,
            options: options,
            session: session,
            withEventType: ChangeStreamEvent<FullDocType>.self
        )
    }

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster -
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
     * - Returns: A `ChangeStream` on all collections in all databases in a cluster.
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *   - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
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
    ) async throws -> ChangeStream<EventType> {
        try await self.watch(
            pipeline,
            options: options,
            session: session,
            withEventType: EventType.self
        ).get()
    }
}
#endif
