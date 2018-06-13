import libmongoc

/// Options to use when running a command against a `MongoDatabase`. 
public struct RunCommandOptions: Encodable {
    /// A session to associate with this operation
    public let session: ClientSession?

    /// An optional `ReadConcern` to use for this operation
    public let readConcern: ReadConcern?

    /// An optional WriteConcern to use for this operation
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing session to be omitted or optional
    public init(readConcern: ReadConcern? = nil, session: ClientSession? = nil,
                writeConcern: WriteConcern? = nil) {
        self.readConcern = readConcern
        self.session = session
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `listCollections` command on a `MongoDatabase`.
public struct ListCollectionsOptions: Encodable {
    /// A filter to match collections against
    public let filter: Document?

    /// The batchSize for the returned cursor
    public let batchSize: Int?

    /// A session to associate with this operation
    public let session: ClientSession?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(batchSize: Int? = nil, filter: Document? = nil, session: ClientSession? = nil) {
        self.batchSize = batchSize
        self.filter = filter
        self.session = session
    }
}

/// Options to use when executing a `createCollection` command on a `MongoDatabase`.
public struct CreateCollectionOptions: Encodable {
    /// Indicates whether this will be a capped collection
    public let capped: Bool?

    /// Whether or not this collection will automatically generate an index on _id
    public let autoIndexId: Bool?

    /// Maximum size, in bytes, of this collection (if capped)
    public let size: Int64?

    /// Maximum number of documents allowed in the collection (if capped)
    public let max: Int64?

    /// Determine which storage engine to use
    public let storageEngine: Document?

    /// What validator should be used for the collection
    public let validator: Document?

    /// Determines how strictly MongoDB applies the validation rules to existing documents during an update
    public let validationLevel: String?

    /// Determines whether to error on invalid documents or just warn about the violations
    /// but allow invalid documents to be inserted
    public let validationAction: String?

    /// Allows users to specify a default configuration for indexes when creating a collection
    public let indexOptionDefaults: Document?

    /// The name of the source collection or view from which to create the view
    public let viewOn: String?

    /// Specifies the default collation for the collection
    public let collation: Document?

    /// A session to associate with this operation
    public let session: ClientSession?

    /// A read concern to set on the returned collection. If one is not specified, it will inherit
    /// the database's read concern.
    public let readConcern: ReadConcern?

    /// A write concern to set on the returned collection. If one is not specified, it will inherit
    /// the database's write concern.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(autoIndexId: Bool? = nil, capped: Bool? = nil, collation: Document? = nil,
                indexOptionDefaults: Document? = nil, max: Int64? = nil, readConcern: ReadConcern? = nil,
                session: ClientSession? = nil, size: Int64? = nil, storageEngine: Document? = nil,
                validationAction: String? = nil, validationLevel: String? = nil, validator: Document? = nil,
                viewOn: String? = nil, writeConcern: WriteConcern? = nil) {
        self.autoIndexId = autoIndexId
        self.capped = capped
        self.collation = collation
        self.indexOptionDefaults = indexOptionDefaults
        self.max = max
        self.readConcern = readConcern
        self.session = session
        self.size = size
        self.storageEngine = storageEngine
        self.validationAction = validationAction
        self.validationLevel = validationLevel
        self.validator = validator
        self.viewOn = viewOn
        self.writeConcern = writeConcern
    }

    // Encode everything except `readConcern` and 'writeConcern`. We skip them because we don't actually
    // send them with the initial command, we just set them on the collection after its creation.
    private enum CodingKeys: String, CodingKey {
        case autoIndexId, capped, collation, indexOptionDefaults, max, session,
            size, storageEngine, validationAction, validationLevel, validator, viewOn
    }
}

/// Options to set on a retrieved `MongoCollection`.
public struct CollectionOptions {
    /// A read concern to set on the returned collection. If one is not specified,
    /// the collection will inherit the database's read concern.
    public let readConcern: ReadConcern?

    /// A write concern to set on the returned collection. If one is not specified,
    /// the collection will inherit the database's write concern.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all arguments to be omitted or optional
    public init(readConcern: ReadConcern? = nil, writeConcern: WriteConcern? = nil) {
        self.readConcern = readConcern
        self.writeConcern = writeConcern
    }
}

/// A MongoDB Database
public class MongoDatabase {
    private var _database: OpaquePointer?
    private var _client: MongoClient?

    /// The name of this database.
    public var name: String {
        return String(cString: mongoc_database_get_name(self._database))
    }

    /// The `ReadConcern` set on this database, or `nil` if one is not set.
    public var readConcern: ReadConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let readConcern = mongoc_database_get_read_concern(self._database)
        let rcObj = ReadConcern(from: readConcern)
        if rcObj.isDefault { return nil }
        return rcObj
    }

    /// The `WriteConcern` set on this database, or `nil` if one is not set.
    public var writeConcern: WriteConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let writeConcern = mongoc_database_get_write_concern(self._database)
        let wcObj = WriteConcern(writeConcern)
        if wcObj.isDefault { return nil }
        return wcObj
    }

    /// Initializes a new `MongoDatabase` instance, not meant to be instantiated directly.
    internal init(fromDatabase: OpaquePointer, withClient: MongoClient) {
        self._database = fromDatabase
        self._client = withClient
    }

    /// Deinitializes a MongoDatabase, cleaning up the internal `mongoc_database_t`.
    deinit {
        self._client = nil
        guard let database = self._database else { return }
        mongoc_database_destroy(database)
        self._database = nil
    }

    /// Drops this database.
    public func drop() throws {
        var error = bson_error_t()
        if !mongoc_database_drop(self._database, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
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
    public func collection(_ name: String, options: CollectionOptions? = nil) throws -> MongoCollection<Document> {
        return try self.collection(name, withType: Document.self, options: options)
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
    public func collection<T: Codable>(_ name: String, withType: T.Type,
                                              options: CollectionOptions? = nil) throws -> MongoCollection<T> {
        guard let collection = mongoc_database_get_collection(self._database, name) else {
            throw MongoError.invalidCollection(message: "Could not get collection '\(name)'")
        }

        if let rc = options?.readConcern {
            mongoc_collection_set_read_concern(collection, rc._readConcern)
        }

        if let wc = options?.writeConcern {
            mongoc_collection_set_write_concern(collection, wc._writeConcern)
        }

        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCollection(fromCollection: collection, withClient: client)
    }

    /**
     * Creates a collection in this database with the specified options
     *
     * - Parameters:
     *   - name: a `String`, the name of the collection to create
     *   - options: Optional `CreateCollectionOptions` to use for the collection
     *
     * - Returns: the newly created `MongoCollection<Document>`
     */
    public func createCollection(_ name: String,
                                 options: CreateCollectionOptions? = nil) throws -> MongoCollection<Document> {
        return try self.createCollection(name, withType: Document.self, options: options)
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
     */
    public func createCollection<T: Codable>(_ name: String, withType: T.Type,
                                             options: CreateCollectionOptions? = nil) throws -> MongoCollection<T> {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        var error = bson_error_t()

        guard let collection = mongoc_database_create_collection(self._database, name, opts?.data, &error) else {
            throw MongoError.commandError(message: toErrorString(error))
        }

        if let rc = options?.readConcern {
            mongoc_collection_set_read_concern(collection, rc._readConcern)
        }

        if let wc = options?.writeConcern {
            mongoc_collection_set_write_concern(collection, wc._writeConcern)
        }

        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCollection(fromCollection: collection, withClient: client)
    }

    /**
     * Lists all the collections in this database.
     *
     * - Parameters:
     *   - filter: a `Document`, optional criteria to filter results by
     *   - options: Optional `ListCollectionsOptions` to use when executing this command
     *
     * - Returns: a `MongoCursor` over an array of collections
     */
    public func listCollections(options: ListCollectionsOptions? = nil) throws -> MongoCursor<Document> {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        guard let collections = mongoc_database_find_collections_with_opts(self._database, opts?.data) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: collections, withClient: client)
    }

    /**
     * Issues a MongoDB command against this database.
     *
     * - Parameters:
     *   - command: a `Document` containing the command to issue against the database
     *   - options: Optional `RunCommandOptions` to use when executing this command
     *
     * - Returns: a `Document` containing the server response for the command
     */
    @discardableResult
    public func runCommand(_ command: Document, options: RunCommandOptions? = nil) throws -> Document {
        let opts = try BsonEncoder().encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_database_command_with_opts(self._database, command.data, nil, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return reply
    }
}
