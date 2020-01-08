import MongoSwift

/// A MongoDB Database.
public struct MongoDatabase {
    /// Encoder used by this database for BSON conversions. This encoder's options are inherited by collections derived
    /// from this database.
    public var encoder: BSONEncoder { return self.asyncDB.encoder }

    /// Decoder whose options are inherited by collections derived from this database.
    public var decoder: BSONDecoder { return self.asyncDB.decoder }

    /// The name of this database.
    public var name: String { return self.asyncDB.name }

    /// The `ReadConcern` set on this database, or `nil` if one is not set.
    public var readConcern: ReadConcern? { return self.asyncDB.readConcern }

    /// The `ReadPreference` set on this database
    public var readPreference: ReadPreference { return self.asyncDB.readPreference }

    /// The `WriteConcern` set on this database, or `nil` if one is not set.
    public var writeConcern: WriteConcern? { return self.asyncDB.writeConcern }

    /// The underlying asynchronous database.
    private let asyncDB: MongoSwift.MongoDatabase

    /// The client this database descended from.
    private let client: MongoClient

    /// Initializes a new `MongoDatabase` instance wrapping the provided async database.
    internal init(asyncDB: MongoSwift.MongoDatabase, client: MongoClient) {
        self.asyncDB = asyncDB
        self.client = client
    }

    /**
     *   Drops this database.
     * - Parameters:
     *   - options: An optional `DropDatabaseOptions` to use when executing this command
     *   - session: An optional `ClientSession` to use for this command
     *
     * - Throws:
     *   - `CommandError` if an error occurs that prevents the command from executing.
     */
    public func drop(options: DropDatabaseOptions? = nil, session: ClientSession? = nil) throws {
        return try self.asyncDB.drop(options: options, session: session?.asyncSession).wait()
    }

    /**
     * Access a collection within this database. If an option is not specified in the `CollectionOptions` param, the
     * collection will inherit the value from the parent database or the default if the db's option is not set.
     * To override an option inherited from the db (e.g. a read concern) with the default value, it must be explicitly
     * specified in the options param (e.g. ReadConcern(), not nil).
     *
     * - Parameters:
     *   - name: the name of the collection to get
     *   - options: options to set on the returned collection
     *
     * - Returns: the requested `MongoCollection<Document>`
     */
    public func collection(_ name: String, options: CollectionOptions? = nil) -> MongoCollection<Document> {
        return self.collection(name, withType: Document.self, options: options)
    }

    /**
     * Access a collection within this database, and associates the specified `Codable` type `T` with the
     * returned `MongoCollection`. This association only exists in the context of this particular
     * `MongoCollection` instance. If an option is not specified in the `CollectionOptions` param, the
     * collection will inherit the value from the parent database or the default if the db's option is not set.
     * To override an option inherited from the db (e.g. a read concern) with the default value, it must be explicitly
     * specified in the options param (e.g. ReadConcern(), not nil).
     *
     * - Parameters:
     *   - name: the name of the collection to get
     *   - options: options to set on the returned collection
     *
     * - Returns: the requested `MongoCollection<T>`
     */
    public func collection<T: Codable>(
        _ name: String,
        withType _: T.Type,
        options: CollectionOptions? = nil
    ) -> MongoCollection<T> {
        let asyncColl = self.asyncDB.collection(name, withType: T.self, options: options)
        return MongoCollection(asyncCollection: asyncColl, client: self.client)
    }

    /**
     * Creates a collection in this database with the specified options.
     *
     * - Parameters:
     *   - name: a `String`, the name of the collection to create
     *   - options: Optional `CreateCollectionOptions` to use for the collection
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: the newly created `MongoCollection<Document>`
     *
     * - Throws:
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection(
        _ name: String,
        options: CreateCollectionOptions? = nil,
        session: ClientSession? = nil
    ) throws -> MongoCollection<Document> {
        return try self.createCollection(name, withType: Document.self, options: options, session: session)
    }

    /**
     * Creates a collection in this database with the specified options, and associates the
     * specified `Codable` type `T` with the returned `MongoCollection`. This association only
     * exists in the context of this particular `MongoCollection` instance.
     *
     *
     * - Parameters:
     *   - name: a `String`, the name of the collection to create
     *   - options: Optional `CreateCollectionOptions` to use for the collection
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: the newly created `MongoCollection<T>`
     *
     * - Throws:
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection<T: Codable>(
        _ name: String,
        withType type: T.Type,
        options: CreateCollectionOptions? = nil,
        session: ClientSession? = nil
    ) throws -> MongoCollection<T> {
        let asyncColl = try self.asyncDB.createCollection(name,
                                                          withType: type,
                                                          options: options,
                                                          session: session?.asyncSession)
                                                          .wait()
        return MongoCollection(asyncCollection: asyncColl, client: self.client)
    }

    /**
     * Lists all the collections in this database.
     *
     * - Parameters:
     *   - filter: a `Document`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: a `MongoCursor` over an array of `CollectionSpecification`s
     *
     * - Throws:
     *   - `userError.invalidArgumentError` if the options passed are an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     */
    public func listCollections(
        _ filter: Document? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) throws -> MongoCursor<CollectionSpecification> {
        fatalError("unimplemented")
    }

    /**
     * Gets a list of `MongoCollection`s in this database.
     *
     * - Parameters:
     *   - filter: a `Document`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An array of `MongoCollection`s that match the provided filter.
     *
     * - Throws:
     *   - `userError.invalidArgumentError` if the options passed are an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     */
    public func listMongoCollections(
        _ filter: Document? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) throws -> [MongoCollection<Document>] {
        fatalError("unimplemented")
    }

    /**
     * Gets a list of names of collections in this database.
     *
     * - Parameters:
     *   - filter: a `Document`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `[String]` containing names of collections that match the provided filter.
     *
     * - Throws:
     *   - `userError.invalidArgumentError` if the options passed are an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     */
    public func listCollectionNames(
        _ filter: Document? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) throws -> [String] {
        return try self.asyncDB.listCollectionNames(filter, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Issues a MongoDB command against this database.
     *
     * - Parameters:
     *   - command: a `Document` containing the command to issue against the database
     *   - options: Optional `RunCommandOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: a `Document` containing the server response for the command
     *
     * - Throws:
     *   - `InvalidArgumentError` if `requests` is empty.
     *   - `LogicError` if the provided session is inactive.
     *   - `WriteError` if any error occurs while the command was performing a write.
     *   - `CommandError` if an error occurs that prevents the command from being performed.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func runCommand(
        _ command: Document,
        options: RunCommandOptions? = nil,
        session: ClientSession? = nil
    ) throws -> Document {
        return try self.asyncDB.runCommand(command, options: options, session: session?.asyncSession).wait()
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
     *   - `CommandError` if an error occurs on the server while creating the change stream.
     *   - `InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
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
        _ pipeline: [Document] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil
    ) throws -> ChangeStream<ChangeStreamEvent<Document>> {
        return try self.watch(
          pipeline,
          options: options,
          session: session,
          withEventType: ChangeStreamEvent<Document>.self
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
     *   - `CommandError` if an error occurs on the server while creating the change stream.
     *   - `InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
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
        _ pipeline: [Document] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withFullDocumentType _: FullDocType.Type
    ) throws -> ChangeStream<ChangeStreamEvent<FullDocType>> {
        return try self.watch(
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
     *   - `CommandError` if an error occurs on the server while creating the change stream.
     *   - `InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
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
        _ pipeline: [Document] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withEventType _: EventType.Type
    ) throws -> ChangeStream<EventType> {
        let asyncStream = try self.asyncDB.watch(
          pipeline,
          options: options,
          session: session?.asyncSession,
          withEventType: EventType.self
        ).wait()
        return ChangeStream(wrapping: asyncStream, client: self.client)
    }
}
