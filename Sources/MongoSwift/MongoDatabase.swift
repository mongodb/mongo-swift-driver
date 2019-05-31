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

/// A MongoDB Database.
public class MongoDatabase {
    internal var _database: OpaquePointer?
    internal var _client: MongoClient

    /// Encoder used by this database for BSON conversions. This encoder's options are inherited by collections derived
    /// from this database.
    public let encoder: BSONEncoder

    /// Decoder whose options are inherited by collections derived from this database.
    public let decoder: BSONDecoder

    /// The name of this database.
    public var name: String {
        return String(cString: mongoc_database_get_name(self._database))
    }

    /// The `ReadConcern` set on this database, or `nil` if one is not set.
    public var readConcern: ReadConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let rc = ReadConcern(from: mongoc_database_get_read_concern(self._database))
        return rc.isDefault ? nil : rc
    }

    /// The `ReadPreference` set on this database
    public var readPreference: ReadPreference {
        return ReadPreference(from: mongoc_database_get_read_prefs(self._database))
    }

    /// The `WriteConcern` set on this database, or `nil` if one is not set.
    public var writeConcern: WriteConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let wc = WriteConcern(from: mongoc_database_get_write_concern(self._database))
        return wc.isDefault ? nil : wc
    }

    /// Initializes a new `MongoDatabase` instance, not meant to be instantiated directly.
    internal init(name: String, client: MongoClient, options: DatabaseOptions?) {
        guard let db = mongoc_client_get_database(client._client, name) else {
            fatalError("Couldn't get database '\(name)'")
        }

        if let rc = options?.readConcern {
            mongoc_database_set_read_concern(db, rc._readConcern)
        }

        if let rp = options?.readPreference {
            mongoc_database_set_read_prefs(db, rp._readPreference)
        }

        if let wc = options?.writeConcern {
            mongoc_database_set_write_concern(db, wc._writeConcern)
        }

        self._database = db
        self._client = client
        self.encoder = BSONEncoder(copies: client.encoder, options: options)
        self.decoder = BSONDecoder(copies: client.decoder, options: options)
    }

    /// Cleans up internal state.
    deinit {
        guard let database = self._database else {
            return
        }
        mongoc_database_destroy(database)
        self._database = nil
    }

    /// Drops this database.
    /// - Throws:
    ///   - `ServerError.commandError` if an error occurs that prevents the command from executing.
    public func drop(session: ClientSession? = nil) throws {
        let operation = DropDatabaseOperation(database: self, session: session)
        try operation.execute()
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
        let operation = CreateCollectionOperation(database: self,
                                                  name: name,
                                                  type: type,
                                                  options: options,
                                                  session: session)
        return try operation.execute()
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

        guard let collections = mongoc_database_find_collections_with_opts(self._database, opts?._bson) else {
            fatalError("Couldn't get cursor from the server")
        }

        return try MongoCursor(from: collections, client: self._client, decoder: self.decoder, session: session)
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
        let operation = RunCommandOperation(database: self, command: command, options: options, session: session)
        return try operation.execute()
    }
}
