#if compiler(>=5.5) && canImport(_Concurrency)
/// Extension to `MongoDatabase` to support async/await APIs.
@available(macOS 10.15.0, *)
extension MongoDatabase {
    /**
     *   Drops this database.
     * - Parameters:
     *   - options: An optional `DropDatabaseOptions` to use when executing this command.
     *   - session: An optional `ClientSession` to use for this command.
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     */
    public func drop(options: DropDatabaseOptions? = nil, session: ClientSession? = nil) async throws {
        try await self.drop(options: options, session: session).get()
    }

    /**
     * Creates a collection in this database with the specified options.
     *
     * - Parameters:
     *   - name: a `String`, the name of the collection to create.
     *   - options: Optional `CreateCollectionOptions` to use for the collection.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: the newly created `MongoCollection<BSONDocument>`.
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection(
        _ name: String,
        options: CreateCollectionOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> MongoCollection<BSONDocument> {
        try await self.createCollection(name, withType: BSONDocument.self, options: options, session: session).get()
    }

    /**
     * Creates a collection in this database with the specified options, and associates the
     * specified `Codable` type `T` with the returned `MongoCollection`. This association only
     * exists in the context of this particular `MongoCollection` instance.
     *
     *
     * - Parameters:
     *   - name: a `String`, the name of the collection to create.
     *   - type: a `Codable` type to associate with the returned `MongoCollection`.
     *   - options: Optional `CreateCollectionOptions` to use for the collection.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: the newly created `MongoCollection<T>`.
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection<T: Codable>(
        _ name: String,
        withType type: T.Type,
        options: CreateCollectionOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> MongoCollection<T> {
        try await self.createCollection(name, withType: type, options: options, session: session).get()
    }

    /**
     * Lists all the collections in this database.
     *
     * - Parameters:
     *   - filter: a `BSONDocument`, optional criteria to filter results by.
     *   - options: Optional `ListCollectionsOptions` to use when executing this command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: a `MongoCursor` over an array of `CollectionSpecification`s.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     */
    public func listCollections(
        _ filter: BSONDocument? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> MongoCursor<CollectionSpecification> {
        try await self.listCollections(filter, options: options, session: session).get()
    }

    /**
     * Gets a list of `MongoCollection`s in this database.
     *
     * - Parameters:
     *   - filter: a `BSONDocument`, optional criteria to filter results by.
     *   - options: Optional `ListCollectionsOptions` to use when executing this command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: An array of `MongoCollection`s that match the provided filter.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     */
    public func listMongoCollections(
        _ filter: BSONDocument? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> [MongoCollection<BSONDocument>] {
        try await self.listCollectionNames(filter, options: options, session: session).map { name in
            self.collection(name)
        }
    }

    /**
     * Gets a list of names of collections in this database.
     *
     * - Parameters:
     *   - filter: a `BSONDocument`, optional criteria to filter results by.
     *   - options: Optional `ListCollectionsOptions` to use when executing this command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `[String]` containing names of collections that match the provided filter.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     */
    public func listCollectionNames(
        _ filter: BSONDocument? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> [String] {
        try await self.listCollectionNames(filter, options: options, session: session).get()
    }

    /**
     * Issues a MongoDB command against this database.
     *
     * - Parameters:
     *   - command: a `BSONDocument` containing the command to issue against the database.
     *   - options: Optional `RunCommandOptions` to use when executing this command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: a `BSONDocument` containing the server response for the command.
     *
     * - Throws:
     *   - `MongoError.InvalidArgumentError` if `requests` is empty.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `MongoError.WriteError` if any error occurs while the command was performing a write.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from being performed.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     *
     * - Note: Attempting to specify an API version in this command is considered undefined behavior. API version may
     *         only be configured at the `MongoClient` level.
     */
    @discardableResult
    public func runCommand(
        _ command: BSONDocument,
        options: RunCommandOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> BSONDocument {
        try await self.runCommand(command, options: options, session: session).get()
    }

    /**
     * Starts a `ChangeStream` on a database. Excludes system collections.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *
     * - Returns: A `ChangeStream` on all collections in a database.
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
     * Starts a `ChangeStream` on a database. Excludes system collections.
     * Associates the specified `Codable` type `T` with the `fullDocument` field in the `ChangeStreamEvent`s emitted
     * by the returned `ChangeStream`.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the `fullDocument` field of the emitted `ChangeStreamEvent`s will be
     *                           decoded to.
     *
     * - Returns: A `ChangeStream` on all collections in a database.
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
     * Starts a `ChangeStream` on a database. Excludes system collections.
     * Associates the specified `Codable` type `T` with the returned `ChangeStream`.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the `ChangeStream`.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withEventType: The type that the entire change stream response will be decoded to and that will be returned
     *                    when iterating through the change stream.
     *
     * - Returns: A `ChangeStream` on all collections in a database.
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

    /**
     * Runs an aggregation framework pipeline against this database for pipeline stages that do not require an
     * underlying collection, such as `$currentOp` and `$listLocalSessions`.
     *
     * - Parameters:
     *   - pipeline: an `[BSONDocument]` containing the pipeline of aggregation operations to perform.
     *   - options: Optional `AggregateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns:
     *    A `MongoCursor` over the resulting documents.
     *
     *    Throws:
     *    - `MongoError.CommandError` if an error occurs on the server while executing the aggregation.
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this database's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation-pipeline/#db-aggregate-stages
     */
    public func aggregate(
        _ pipeline: [BSONDocument],
        options: AggregateOptions? = nil,
        session: ClientSession? = nil
    ) async throws -> MongoCursor<BSONDocument> {
        try await self.aggregate(pipeline, options: options, session: session, withOutputType: BSONDocument.self)
    }

    /**
     * Runs an aggregation framework pipeline against this database for pipeline stages that do not require an
     * underlying collection, such as `$currentOp` and `$listLocalSessions`.
     * Associates the specified `Codable` type `OutputType` with the returned `MongoCursor`.
     *
     * - Parameters:
     *   - pipeline: an `[BSONDocument]` containing the pipeline of aggregation operations to perform.
     *   - options: Optional `AggregateOptions` to use when executing the command.
     *   - session: Optional `ClientSession` to use when executing this command.
     *   - withOutputType: the type that each resulting document of the output of the aggregation operation will be
     *      decoded to.
     *
     * - Returns:
     *    A `MongoCursor` over the resulting `OutputType`s.
     *
     *    Throws:
     *    - `MongoError.CommandError` if an error occurs on the server while executing the aggregation.
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this database's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation-pipeline/#db-aggregate-stages
     */
    public func aggregate<OutputType: Codable>(
        _ pipeline: [BSONDocument],
        options: AggregateOptions? = nil,
        session: ClientSession? = nil,
        withOutputType: OutputType.Type
    ) async throws -> MongoCursor<OutputType> {
        try await self.aggregate(
            pipeline,
            options: options,
            session: session,
            withOutputType: withOutputType
        ).get()
    }
}

#endif
