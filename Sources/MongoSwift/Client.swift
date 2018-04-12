import Foundation
import libmongoc

public struct ClientOptions: BsonEncodable {
    /// Determines whether the client should retry supported write operations
    let retryWrites: Bool?

    /// Indicates whether this client should be set up to enable monitoring 
    /// command and server discovery and monitoring events.
    let eventMonitoring: Bool

    /// Convenience initializer allowing retryWrites to be omitted or optional
    public init(retryWrites: Bool? = nil, eventMonitoring: Bool = false) {
        self.retryWrites = retryWrites
        self.eventMonitoring = eventMonitoring
    }

    /// Custom `encode`, because we don't want to actually send the `eventMonitoring` option
    public func encode(to encoder: BsonEncoder) throws {
        try encoder.encode(retryWrites, forKey: "retryWrites")
    }
}

public struct ListDatabasesOptions: BsonEncodable {
    /// An optional filter for the returned databases
    let filter: Document?

    /// Optionally indicate whether only names should be returned
    let nameOnly: Bool?

    /// An optional session to use for this operation
    let session: ClientSession?

    /// Convenience constructor for basic construction
    public init(filter: Document? = nil, nameOnly: Bool? = nil, session: ClientSession? = nil) {
        self.filter = filter
        self.nameOnly = nameOnly
        self.session = session
    }
}

// A MongoDB Client
public class MongoClient {
    internal var _client = OpaquePointer(bitPattern: 1)

    /// If command and/or server monitoring is enabled, stores the NotificationCenter events are posted to.
    internal var notificationCenter: NotificationCenter?

    /// If command and/or server monitoring is enabled, indicates what event types notifications will be posted for. 
    internal var monitoringEventTypes: [MongoEventType]?

    /**
     * Create a new client connection to a MongoDB server
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to
     *   - options: optional settings
     */
    public init(connectionString: String = "mongodb://localhost:27017", options: ClientOptions? = nil) throws {
        var error = bson_error_t()
        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw MongoError.invalidUri(message: toErrorString(error))
        }

        self._client = mongoc_client_new_from_uri(uri)
        if self._client == nil {
            throw MongoError.invalidClient()
        }

        // if the user passed in this option, set up all the monitoring callbacks 
        if let opts = options, opts.eventMonitoring {
            self.initializeMonitoring()
        }
    }

    /**
     * Create a new client from an existing `mongoc_client_t`.
     * Do not use this initialier unless you know what you are doing.
     *
     * - Parameters:
     *   - fromPointer: the `mongoc_client_t` to store and use internally
     */
    public init(fromPointer: OpaquePointer) {
        self._client = fromPointer
    }

    /**
     * Cleanup the internal mongoc_client_t
     */
    deinit {
        close()
    }

    /**
     * Creates a client session
     *
     * - Parameters:
     *   - options: The options to use to create the client session
     *
     * - Returns: A `ClientSession` instance
     */
    public func startSession(options: SessionOptions) throws -> ClientSession {
        return ClientSession()
    }

    /**
     * Close the client
     */
    public func close() {
        guard let client = self._client else {
            return
        }

        // this is defined in the APM extension to Client
        self.disableMonitoring()

        mongoc_client_destroy(client)
        self._client = nil
    }

    /**
     * Get a list of databases
     *
     * - Parameters:
     *   - options: Optional settings
     *
     * - Returns: A `MongoCursor` over documents describing the databases matching provided criteria
     */
    public func listDatabases(options: ListDatabasesOptions? = nil) throws -> MongoCursor {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        guard let cursor = mongoc_client_find_databases_with_opts(self._client, opts?.data) else {
            throw MongoError.invalidResponse()
        }
        return MongoCursor(fromCursor: cursor, withClient: self)
    }

    /**
     * Gets a MongoDatabase instance for the given database name.
     *
     * - Parameters:
     *   - name: the name of the database to retrieve
     *
     * - Returns: a `MongoDatabase` corresponding to the provided database name
     */
    public func db(_ name: String) throws -> MongoDatabase {
        guard let db = mongoc_client_get_database(self._client, name) else {
            throw MongoError.invalidClient()
        }
        return MongoDatabase(fromDatabase: db, withClient: self)
    }
}
