import libmongoc

public struct RunCommandOptions: BsonEncodable {
    /// A session to associate with this operation
    let session: ClientSession?
}

public struct ListCollectionsOptions: BsonEncodable {
    /// A filter to match collections against
    let filter: Document?

    /// The batchSize for the returned cursor
    let batchSize: Int?

    /// A session to associate with this operation
    let session: ClientSession?
}

public struct CreateCollectionOptions: BsonEncodable {
    /// Indicates whether this will be a capped collection
    let capped: Bool?

    /// Whether or not this collection will automatically generate an index on _id
    let autoIndexId: Bool?

    /// Maximum size, in bytes, of this collection (if capped)
    let size: Int64?

    /// Maximum number of documents allowed in the collection (if capped)
    let max: Int64?

    /// Determine which storage engine to use
    let storageEngine: Document?

    /// What validator should be used for the collection
    let validator: Document?

    /// Determines how strictly MongoDB applies the validation rules to existing documents during an update
    let validationLevel: String?

    /// Determines whether to error on invalid documents or just warn about the violations
    /// but allow invalid documents to be inserted
    let validationAction: String?

    /// Allows users to specify a default configuration for indexes when creating a collection
    let indexOptionDefaults: Document?

    /// The name of the source collection or view from which to create the view
    let viewOn: String?

    /// Specifies the default collation for the collection
    let collation: Document?

    /// A session to associate with this operation
    let session: ClientSession?
}

// A MongoDB Database
public class MongoDatabase {
    private var _database = OpaquePointer(bitPattern: 1)
    private var _client: MongoClient?

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
        guard let database = self._database else { return }
        mongoc_database_destroy(database)
        self._database = nil
        self._client = nil
    }

    /**
     * Drops this database.
     */
    func drop() throws {
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
    func collection(_ name: String) throws -> MongoCollection {
        guard let collection = mongoc_database_get_collection(self._database, name) else {
            throw MongoError.invalidCollection(message: "Could not get collection '\(name)'")
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
    func createCollection(_ name: String, options: CreateCollectionOptions? = nil) throws -> MongoCollection {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        var error = bson_error_t()
        guard let collection = mongoc_database_create_collection(self._database, name, opts?.data, &error) else {
            throw MongoError.commandError(message: toErrorString(error))
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
    func listCollections(options: ListCollectionsOptions? = nil) throws -> MongoCursor {
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
    func runCommand(command: Document, options: RunCommandOptions? = nil) throws -> Document {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply: UnsafeMutablePointer<bson_t> = bson_new()
        var error = bson_error_t()
        if !mongoc_database_command_with_opts(self._database, command.data, nil, opts?.data, reply, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return Document(fromData: reply)
    }
}
