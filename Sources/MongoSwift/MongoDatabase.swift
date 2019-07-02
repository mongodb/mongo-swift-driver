import mongoc

/// Options to use when executing a `listCollections` command on a `MongoDatabase`.
public struct ListCollectionsOptions: Encodable {
    /// A filter to match collections against.
    public var filter: Document?

    /// The batchSize for the returned cursor.
    public var batchSize: Int?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(batchSize: Int? = nil, filter: Document? = nil) {
        self.batchSize = batchSize
        self.filter = filter
    }
}

/// Options to set on a retrieved `MongoCollection`.
public struct CollectionOptions: CodingStrategyProvider {
    /// A read concern to set on the returned collection. If one is not specified, the collection will inherit the
    /// database's read concern.
    public var readConcern: ReadConcern?

    /// A read preference to set on the returned collection. If one is not specified, the collection will inherit the
    /// database's read preference.
    public var readPreference: ReadPreference?

    /// A write concern to set on the returned collection. If one is not specified, the collection will inherit the
    /// database's write concern.
    public var writeConcern: WriteConcern?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `Date`s already stored in this collection can be
    /// decoded using this strategy.
    public var dateCodingStrategy: DateCodingStrategy?

    /// Specifies the `UUIDCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `UUID`s already stored in this collection can be
    /// decoded using this strategy.
    public var uuidCodingStrategy: UUIDCodingStrategy?

    /// Specifies the `DataCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `Data`s already stored in this collection can be
    /// decoded using this strategy.
    public var dataCodingStrategy: DataCodingStrategy?

    /// Convenience initializer allowing any/all arguments to be omitted or optional.
    public init(readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil,
                writeConcern: WriteConcern? = nil,
                dateCodingStrategy: DateCodingStrategy? = nil,
                uuidCodingStrategy: UUIDCodingStrategy? = nil,
                dataCodingStrategy: DataCodingStrategy? = nil) {
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.writeConcern = writeConcern
        self.dateCodingStrategy = dateCodingStrategy
        self.uuidCodingStrategy = uuidCodingStrategy
        self.dataCodingStrategy = dataCodingStrategy
    }
}

/// Options to use when executing dropDatabase command.
public struct DropDatabaseOptions: Codable {
    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(writeConcern: WriteConcern? = nil) {
        self.writeConcern = writeConcern
    }
}

/// A MongoDB Database.
public struct MongoDatabase {
    /// The client which this database was derived from.
    internal let _client: MongoClient

    /// The namespace for this database.
    private let namespace: MongoNamespace

    /// Encoder used by this database for BSON conversions. This encoder's options are inherited by collections derived
    /// from this database.
    public let encoder: BSONEncoder

    /// Decoder whose options are inherited by collections derived from this database.
    public let decoder: BSONDecoder

    /// The name of this database.
    public var name: String { return namespace.db }

    /// The `ReadConcern` set on this database, or `nil` if one is not set.
    public let readConcern: ReadConcern?

    /// The `ReadPreference` set on this database
    public let readPreference: ReadPreference

    /// The `WriteConcern` set on this database, or `nil` if one is not set.
    public let writeConcern: WriteConcern?

    /// Initializes a new `MongoDatabase` instance, not meant to be instantiated directly.
    internal init(name: String, client: MongoClient, options: DatabaseOptions?) {
        self.namespace = MongoNamespace(db: name, collection: nil)
        self._client = client
        self.readConcern = options?.readConcern ?? client.readConcern
        self.writeConcern = options?.writeConcern ?? client.writeConcern
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
    * - Throws:
    *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
    */
    public func drop(options: DropDatabaseOptions? = nil, session: ClientSession? = nil) throws {
        let operation = DropDatabaseOperation(database: self, options: options)
        return try self._client.executeOperation(operation, session: session)
    }

    /**
     * Access a collection within this database.
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
     * `MongoCollection` instance.
     *
     * - Parameters:
     *   - name: the name of the collection to get
     *   - options: options to set on the returned collection
     *
     * - Returns: the requested `MongoCollection<T>`
     */
    public func collection<T: Codable>(_ name: String,
                                       withType: T.Type,
                                       options: CollectionOptions? = nil) -> MongoCollection<T> {
        return MongoCollection(name: name, database: self, options: options)
    }

    /**
     * Creates a collection in this database with the specified options.
     *
     * - Parameters:
     *   - name: a `String`, the name of the collection to create
     *   - options: Optional `CreateCollectionOptions` to use for the collection
     *
     * - Returns: the newly created `MongoCollection<Document>`
     *
     * - Throws:
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection(_ name: String,
                                 options: CreateCollectionOptions? = nil,
                                 session: ClientSession? = nil) throws -> MongoCollection<Document> {
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
     *
     * - Returns: the newly created `MongoCollection<T>`
     *
     * - Throws:
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func createCollection<T: Codable>(_ name: String,
                                             withType type: T.Type,
                                             options: CreateCollectionOptions? = nil,
                                             session: ClientSession? = nil) throws -> MongoCollection<T> {
        let operation = CreateCollectionOperation(database: self, name: name, type: type, options: options)
        return try self._client.executeOperation(operation, session: session)
    }

    /**
     * Lists all the collections in this database.
     *
     * - Parameters:
     *   - filter: a `Document`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *
     * - Returns: a `MongoCursor` over an array of collections
     *
     * - Throws:
     *   - `userError.invalidArgumentError` if the options passed are an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     */
    public func listCollections(options: ListCollectionsOptions? = nil,
                                session: ClientSession? = nil) throws -> MongoCursor<Document> {
        let opts = try encodeOptions(options: options, session: session)
        let conn = try self._client.connectionPool.checkOut()
        let collections: OpaquePointer = self.withMongocDatabase(from: conn) { dbPtr in
            guard let collections = mongoc_database_find_collections_with_opts(dbPtr, opts?._bson) else {
                fatalError("Couldn't get cursor from the server")
            }
            return collections
        }

        return try MongoCursor(from: collections,
                               client: self._client,
                               connection: conn,
                               decoder: self.decoder,
                               session: session)
    }

    /**
     * Issues a MongoDB command against this database.
     *
     * - Parameters:
     *   - command: a `Document` containing the command to issue against the database
     *   - options: Optional `RunCommandOptions` to use when executing this command
     *
     * - Returns: a `Document` containing the server response for the command
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if `requests` is empty.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `ServerError.writeError` if any error occurs while the command was performing a write.
     *   - `ServerError.commandError` if an error occurs that prevents the command from being performed.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func runCommand(_ command: Document,
                           options: RunCommandOptions? = nil,
                           session: ClientSession? = nil) throws -> Document {
        let operation = RunCommandOperation(database: self, command: command, options: options)
        return try self._client.executeOperation(operation, session: session)
    }

    /// Uses the provided `Connection` to get a pointer to a `mongoc_database_t` corresponding to this `MongoDatabase`,
    /// and uses it to execute the given closure. The `mongoc_database_t` is only valid for the body of the closure.
    /// The caller is *not responsible* for cleaning up the `mongoc_database_t`.
    internal func withMongocDatabase<T>(from connection: Connection, body: (OpaquePointer) throws -> T) rethrows -> T {
        guard let db = mongoc_client_get_database(connection.clientHandle, self.name) else {
            fatalError("Couldn't get database '\(self.name)'")
        }
        defer { mongoc_database_destroy(db) }

        self.readConcern?.withMongocReadConcern { rcPtr in
            mongoc_database_set_read_concern(db, rcPtr)
        }
        self.writeConcern?.withMongocWriteConcern { wcPtr in
            mongoc_database_set_write_concern(db, wcPtr)
        }
        if self.readPreference != self._client.readPreference {
            mongoc_database_set_read_prefs(db, self.readPreference._readPreference)
        }

        return try body(db)
    }
}
