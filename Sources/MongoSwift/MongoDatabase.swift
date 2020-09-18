import CLibMongoC
import NIO

/// Options to set on a retrieved `MongoCollection`.
public struct MongoCollectionOptions: CodingStrategyProvider {
    /// Specifies the `DataCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `Data`s already stored in this collection can be
    /// decoded using this strategy.
    public var dataCodingStrategy: DataCodingStrategy?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `Date`s already stored in this collection can be
    /// decoded using this strategy.
    public var dateCodingStrategy: DateCodingStrategy?

    /// A read concern to set on the returned collection.
    public var readConcern: ReadConcern?

    /// A read preference to set on the returned collection.
    public var readPreference: ReadPreference?

    /// Specifies the `UUIDCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `UUID`s already stored in this collection can be
    /// decoded using this strategy.
    public var uuidCodingStrategy: UUIDCodingStrategy?

    /// A write concern to set on the returned collection.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all arguments to be omitted or optional.
    public init(
        dataCodingStrategy: DataCodingStrategy? = nil,
        dateCodingStrategy: DateCodingStrategy? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        uuidCodingStrategy: UUIDCodingStrategy? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.dataCodingStrategy = dataCodingStrategy
        self.dateCodingStrategy = dateCodingStrategy
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.uuidCodingStrategy = uuidCodingStrategy
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `dropDatabase` command.
public struct DropDatabaseOptions: Codable {
    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(writeConcern: WriteConcern? = nil) {
        self.writeConcern = writeConcern
    }
}

// sourcery: skipSyncExport
/// A MongoDB Database.
public struct MongoDatabase {
    /// The client which this database was derived from.
    internal let _client: MongoClient

    /// The namespace for this database.
    internal let namespace: MongoNamespace

    /// Encoder used by this database for BSON conversions. This encoder's options are inherited by collections derived
    /// from this database.
    public let encoder: BSONEncoder

    /// Decoder whose options are inherited by collections derived from this database.
    public let decoder: BSONDecoder

    /// The name of this database.
    public var name: String { self.namespace.db }

    /// The `ReadConcern` set on this database, or `nil` if one is not set.
    public let readConcern: ReadConcern?

    /// The `ReadPreference` set on this database
    public let readPreference: ReadPreference

    /// The `WriteConcern` set on this database, or `nil` if one is not set.
    public let writeConcern: WriteConcern?

    /// Initializes a new `MongoDatabase` instance, not meant to be instantiated directly.
    internal init(name: String, client: MongoClient, options: MongoDatabaseOptions?) {
        self.namespace = MongoNamespace(db: name, collection: nil)
        self._client = client

        // for both read concern and write concern, we look for a read concern in the following order:
        // 1. options provided for this collection
        // 2. value for this `MongoDatabase`'s parent `MongoClient`
        // if we found a non-nil value, we check if it's the empty/server default or not, and store it if not.
        if let rc = options?.readConcern ?? client.readConcern, !rc.isDefault {
            self.readConcern = rc
        } else {
            self.readConcern = nil
        }

        if let wc = options?.writeConcern ?? client.writeConcern, !wc.isDefault {
            self.writeConcern = wc
        } else {
            self.writeConcern = nil
        }

        // read preference has similar inheritance logic to read concern and write concern, but there is no empty read
        // preference so we don't need to check for that as we did above.
        self.readPreference = options?.readPreference ?? client.readPreference
        self.encoder = BSONEncoder(copies: client.encoder, options: options)
        self.decoder = BSONDecoder(copies: client.decoder, options: options)
    }

    /**
     *   Drops this database.
     * - Parameters:
     *   - options: An optional `DropDatabaseOptions` to use when executing this command
     *   - session: An optional `ClientSession` to use for this command
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when the drop is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this database's parent client has already been closed.
     */
    public func drop(options: DropDatabaseOptions? = nil, session: ClientSession? = nil) -> EventLoopFuture<Void> {
        let operation = DropDatabaseOperation(database: self, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Access a collection within this database. If an option is not specified in the `MongoCollectionOptions` param,
     * the collection will inherit the value from the parent database or the default if the db's option is not set.
     * To override an option inherited from the db (e.g. a read concern) with the default value, it must be explicitly
     * specified in the options param (e.g. ReadConcern.serverDefault, not nil).
     *
     * - Parameters:
     *   - name: the name of the collection to get
     *   - options: options to set on the returned collection
     *
     * - Returns: the requested `MongoCollection<Document>`
     */
    public func collection(_ name: String, options: MongoCollectionOptions? = nil) -> MongoCollection<BSONDocument> {
        self.collection(name, withType: BSONDocument.self, options: options)
    }

    /**
     * Access a collection within this database, and associates the specified `Codable` type `T` with the
     * returned `MongoCollection`. This association only exists in the context of this particular
     * `MongoCollection` instance. If an option is not specified in the `MongoCollectionOptions` param, the
     * collection will inherit the value from the parent database or the default if the db's option is not set.
     * To override an option inherited from the db (e.g. a read concern) with the default value, it must be explicitly
     * specified in the options param (e.g. ReadConcern.serverDefault, not nil).
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
        options: MongoCollectionOptions? = nil
    ) -> MongoCollection<T> {
        MongoCollection(name: name, database: self, options: options)
    }

    /**
     * Creates a collection in this database with the specified options.
     *
     * - Parameters:
     *   - name: a `String`, the name of the collection to create
     *   - options: Optional `CreateCollectionOptions` to use for the collection
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCollection<Document>>`. On success, contains the newly created collection.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this databases's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection(
        _ name: String,
        options: CreateCollectionOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<MongoCollection<BSONDocument>> {
        self.createCollection(name, withType: BSONDocument.self, options: options, session: session)
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
     * - Returns:
     *    An `EventLoopFuture<MongoCollection<T>>`. On success, contains the newly created collection.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this databases's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection<T: Codable>(
        _ name: String,
        withType type: T.Type,
        options: CreateCollectionOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<MongoCollection<T>> {
        let operation = CreateCollectionOperation(database: self, name: name, type: type, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Lists all the collections in this database.
     *
     * - Parameters:
     *   - filter: a `BSONDocument`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Warning:
     *    If the returned cursor is alive when it goes out of scope, it will leak resources. To ensure the cursor
     *    is dead before it leaves scope, invoke `MongoCursor.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCursor<CollectionSpecification>>` containing a cursor over the collections.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this databases's parent client has already been closed.
     */
    public func listCollections(
        _ filter: BSONDocument? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<MongoCursor<CollectionSpecification>> {
        let operation = ListCollectionsOperation(database: self, nameOnly: false, filter: filter, options: options)
        return self._client.operationExecutor.execute(
            operation, client: self._client, session: session
        ).flatMapThrowing { result in
            guard case let .specs(result) = result else {
                throw MongoError.InternalError(message: "invalid result")
            }
            return result
        }
    }

    /**
     * Gets a list of `MongoCollection`s corresponding to collections in this database.
     *
     * - Parameters:
     *   - filter: a `BSONDocument`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[MongoCollection<Document>]>`. On success, contains collections that match the
     *    provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this databases's parent client has already been closed.
     */
    public func listMongoCollections(
        _ filter: BSONDocument? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[MongoCollection<BSONDocument>]> {
        self.listCollectionNames(filter, options: options, session: session).map { collNames in
            collNames.map { self.collection($0) }
        }
    }

    /**
     * Gets a list of names of collections in this database.
     *
     * - Parameters:
     *   - filter: a `BSONDocument`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[String]>`. On success, contains names of collections that match the provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this databases's parent client has already been closed.
     */
    public func listCollectionNames(
        _ filter: BSONDocument? = nil,
        options: ListCollectionsOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[String]> {
        let operation = ListCollectionsOperation(database: self, nameOnly: true, filter: filter, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
            .flatMapThrowing { result in
                guard case let .names(names) = result else {
                    throw MongoError.InternalError(message: "Invalid result")
                }
                return names
            }
    }

    /**
     * Issues a MongoDB command against this database.
     *
     * - Parameters:
     *   - command: a `BSONDocument` containing the command to issue against the database
     *   - options: Optional `RunCommandOptions` to use when executing this command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<Document>`. On success, contains the server response to the command.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if `requests` is empty.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this databases's parent client has already been closed.
     *    - `MongoError.WriteError` if any error occurs while the command was performing a write.
     *    - `MongoError.CommandError` if an error occurs that prevents the command from being performed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func runCommand(
        _ command: BSONDocument,
        options: RunCommandOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<BSONDocument> {
        let operation = RunCommandOperation(database: self, command: command, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Starts a `ChangeStream` on a database. Excludes system collections.
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
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    database.
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
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    database.
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
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    database.
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
            target: .database(self),
            pipeline: pipeline,
            options: options
        )
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /// Uses the provided `Connection` to get a pointer to a `mongoc_database_t` corresponding to this
    /// `MongoDatabase`, and uses it to execute the given closure. The `mongoc_database_t` is only valid for the
    /// body of the closure. The caller is *not responsible* for cleaning up the `mongoc_database_t`.
    internal func withMongocDatabase<T>(from connection: Connection, body: (OpaquePointer) throws -> T) rethrows -> T {
        try connection.withMongocConnection { connPtr in
            guard let db = mongoc_client_get_database(connPtr, self.name) else {
                fatalError("Couldn't get database '\(self.name)'")
            }
            defer { mongoc_database_destroy(db) }

            // `db` will automatically inherit read concern, write concern, and read preference from the parent client.
            // If this database's value for any of those settings is different than the parent, we need to explicitly
            // set it here.

            if self.readConcern != self._client.readConcern {
                // a nil value for self.readConcern corresponds to the empty read concern.
                (self.readConcern ?? .serverDefault).withMongocReadConcern { rcPtr in
                    mongoc_database_set_read_concern(db, rcPtr)
                }
            }

            if self.writeConcern != self._client.writeConcern {
                // a nil value for self.writeConcern corresponds to the empty write concern.
                (self.writeConcern ?? WriteConcern()).withMongocWriteConcern { wcPtr in
                    mongoc_database_set_write_concern(db, wcPtr)
                }
            }

            if self.readPreference != self._client.readPreference {
                // there is no concept of an empty read preference so we will always have a value here.
                self.readPreference.withMongocReadPreference { rpPtr in
                    mongoc_database_set_read_prefs(db, rpPtr)
                }
            }

            return try body(db)
        }
    }

    /// Internal method to check the `ReadConcern` that is set on `mongoc_database_t`s via `withMongocDatabase`.
    /// **This method may block and is for testing purposes only**.
    internal func getMongocReadConcern() throws -> ReadConcern? {
        try self._client.connectionPool.withConnection { conn in
            self.withMongocDatabase(from: conn) { dbPtr in
                ReadConcern(copying: mongoc_database_get_read_concern(dbPtr))
            }
        }
    }

    /// Internal method to check the `ReadPreference` that is set on `mongoc_database_t`s via `withMongocDatabase`.
    /// **This method may block and is for testing purposes only**.
    internal func getMongocReadPreference() throws -> ReadPreference {
        try self._client.connectionPool.withConnection { conn in
            self.withMongocDatabase(from: conn) { dbPtr in
                ReadPreference(copying: mongoc_database_get_read_prefs(dbPtr))
            }
        }
    }

    /// Internal method to check the `WriteConcern` that is set on `mongoc_database_t`s via `withMongocDatabase`.
    /// **This method may block and is for testing purposes only**.
    internal func getMongocWriteConcern() throws -> WriteConcern? {
        try self._client.connectionPool.withConnection { conn in
            self.withMongocDatabase(from: conn) { dbPtr in
                WriteConcern(copying: mongoc_database_get_write_concern(dbPtr))
            }
        }
    }
}
