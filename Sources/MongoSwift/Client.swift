import Foundation
import libmongoc

/// Options to use when creating a `MongoClient`.
public struct ClientOptions {
    /// Determines whether the client should retry supported write operations
    public let retryWrites: Bool?

    /// Indicates whether this client should be set up to enable monitoring
    /// command and server discovery and monitoring events.
    public let eventMonitoring: Bool

    /// Specifies a ReadConcern to use for the client. If one is not specified,
    /// the server's default read concern will be used.
    let readConcern: ReadConcern?

    /// Convenience initializer allowing any/all to be omitted or optional
    public init(eventMonitoring: Bool = false, readConcern: ReadConcern? = nil, retryWrites: Bool? = nil) {
        self.retryWrites = retryWrites
        self.eventMonitoring = eventMonitoring
        self.readConcern = readConcern
    }
}

/// Options to use when listing available databases.
public struct ListDatabasesOptions: Encodable {
    /// An optional filter for the returned databases
    public let filter: Document?

    /// Optionally indicate whether only names should be returned
    public let nameOnly: Bool?

    /// An optional session to use for this operation
    public let session: ClientSession?

    /// Convenience constructor for basic construction
    public init(filter: Document? = nil, nameOnly: Bool? = nil, session: ClientSession? = nil) {
        self.filter = filter
        self.nameOnly = nameOnly
        self.session = session
    }
}

/// Options to use when retrieving a `MongoDatabase` from a `MongoClient`. 
public struct DatabaseOptions {
    /// A read concern to set on the retrieved database. If one is not specified,
    /// the database will inherit the client's read concern. 
    let readConcern: ReadConcern?
}

/// A MongoDB Client.
public class MongoClient {
    internal var _client: OpaquePointer?

    /// If command and/or server monitoring is enabled, stores the NotificationCenter events are posted to.
    internal var notificationCenter: NotificationCenter?

    /// If command and/or server monitoring is enabled, indicates what event types notifications will be posted for.
    internal var monitoringEventTypes: [MongoEventType]?

    /// The read concern set on this client, or nil if one is not set.
    public var readConcern: ReadConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let readConcern = mongoc_client_get_read_concern(self._client)
        let rcObj = ReadConcern(readConcern)
        if rcObj.isDefault { return nil }
        return rcObj
    }

    /**
     * Create a new client connection to a MongoDB server.
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to.
     *   - options: optional `ClientOptions` to use for this client
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
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

        // if a readConcern is provided, set it on the client
        if let rc = options?.readConcern {
            mongoc_client_set_read_concern(self._client, rc._readConcern)
        }

        if options?.eventMonitoring == true { self.initializeMonitoring() }
    }

    /**
     * Create a new client from an existing `mongoc_client_t`.
     * Do not use this initializer unless you know what you are doing.
     *
     * - Parameters:
     *   - fromPointer: the `mongoc_client_t` to store and use internally
     */
    public init(fromPointer: OpaquePointer) {
        self._client = fromPointer
    }

    /**
     * Cleans up the internal `mongoc_client_t`.
     */
    deinit {
        close()
    }

    /**
     * Creates a client session.
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
     * Closes the client.
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
     * Get a list of databases.
     *
     * - Parameters:
     *   - options: Optional `ListDatabasesOptions` to use when executing the command
     *
     * - Returns: A `MongoCursor` over `Document`s describing the databases matching provided criteria
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
     * Gets a `MongoDatabase` instance for the given database name.
     *
     * - Parameters:
     *   - name: the name of the database to retrieve
     *   - options: Optional `DatabaseOptions` to use for the retrieved database
     *
     * - Returns: a `MongoDatabase` corresponding to the provided database name
     */
    public func db(_ name: String, options: DatabaseOptions? = nil) throws -> MongoDatabase {
        guard let db = mongoc_client_get_database(self._client, name) else {
            throw MongoError.invalidClient()
        }

        if let rc = options?.readConcern {
            mongoc_database_set_read_concern(db, rc._readConcern)
        }

        return MongoDatabase(fromDatabase: db, withClient: self)
    }
}
