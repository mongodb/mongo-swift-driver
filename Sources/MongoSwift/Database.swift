import libmongoc

public struct RunCommandOptions: BsonEncodable {
    /// A session to associate with this operation
    public let session: ClientSession?

    /// An optional ReadConcern to use for this operation
    let readConcern: ReadConcern?

    /// Convenience initializer allowing session to be omitted or optional
    public init(readConcern: ReadConcern? = nil, session: ClientSession? = nil) {
        self.readConcern = readConcern
        self.session = session
    }

    public var skipFields: [String] { return ["readConcern"] }
}

public struct ListCollectionsOptions: BsonEncodable {
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

public struct CreateCollectionOptions: BsonEncodable {
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
    let readConcern: ReadConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(autoIndexId: Bool? = nil, capped: Bool? = nil, collation: Document? = nil,
                indexOptionDefaults: Document? = nil, max: Int64? = nil, readConcern: ReadConcern? = nil,
                session: ClientSession? = nil, size: Int64? = nil, storageEngine: Document? = nil,
                validationAction: String? = nil, validationLevel: String? = nil, validator: Document? = nil,
                viewOn: String? = nil) {
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
    }

    public var skipFields: [String] { return ["readConcern"] }
}

public struct CollectionOptions {
    /// A read concern to set on the returned collection. If one is not specified,
    /// the collection will inherit the database's read concern.
    let readConcern: ReadConcern?
}

// A MongoDB Database
public class MongoDatabase {
    private var _database: OpaquePointer?
    private var _client: MongoClient?

    /// The name of this database.
    public var name: String {
        return String(cString: mongoc_database_get_name(self._database))
    }

    /// The readConcern set on this database.
    public var readConcern: ReadConcern {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let readConcern = mongoc_database_get_read_concern(self._database)
        return ReadConcern(readConcern)
    }

    /**
     * Initializes a new MongoDatabase instance, not meant to be instantiated directly
     */
    internal init(fromDatabase: OpaquePointer, withClient: MongoClient) {
        self._database = fromDatabase
        self._client = withClient
    }

    /**
     * Deinitializes a MongoDatabase, cleaning up the internal mongoc_database_t
     */
    deinit {
        self._client = nil
        guard let database = self._database else { return }
        mongoc_database_destroy(database)
        self._database = nil
    }

    /**
     * Drops this database.
     */
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
     *
     * - Returns: the requested `MongoCollection`
     */
    public func collection(_ name: String, options: CollectionOptions? = nil) throws -> MongoCollection {
        guard let collection = mongoc_database_get_collection(self._database, name) else {
            throw MongoError.invalidCollection(message: "Could not get collection '\(name)'")
        }

        if let rc = options?.readConcern {
            mongoc_collection_set_read_concern(collection, rc._readConcern)
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
     *   - name: the name of the collection
     *   - options: optional settings
     *
     * - Returns: the newly created `MongoCollection`
     */
    public func createCollection(_ name: String, options: CreateCollectionOptions? = nil) throws -> MongoCollection {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        var error = bson_error_t()

        guard let collection = mongoc_database_create_collection(self._database, name, opts?.data, &error) else {
            throw MongoError.commandError(message: toErrorString(error))
        }

        if let rc = options?.readConcern {
            mongoc_collection_set_read_concern(collection, rc._readConcern)
        }

        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCollection(fromCollection: collection, withClient: client)
    }

    /**
     * List all collections in this database
     *
     * - Parameters:
     *   - filter: Optional criteria to filter results by
     *   - options: Optional settings
     *
     * - Returns: a `MongoCursor` over an array of collections
     */
    public func listCollections(options: ListCollectionsOptions? = nil) throws -> MongoCursor {
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
     * Issue a MongoDB command against this database
     *
     * - Parameters:
     *   - command: The command to issue against the database
     *   - options: Optional settings
     *
     * - Returns: The server response for the command
     */
    public func runCommand(_ command: Document, options: RunCommandOptions? = nil) throws -> Document {
        let encoder = BsonEncoder()
        let opts = try ReadConcern.append(options?.readConcern, to: try encoder.encode(options), callerRC: self.readConcern)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_database_command_with_opts(self._database, command.data, nil, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return reply
    }
}
