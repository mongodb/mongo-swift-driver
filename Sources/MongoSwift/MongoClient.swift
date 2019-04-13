import Foundation
import mongoc

/// Options to use when creating a `MongoClient`.
public struct ClientOptions: CodingStrategyProvider {
    /// Determines whether the client should retry supported write operations
    public let retryWrites: Bool?

    /// Indicates whether this client should be set up to enable monitoring
    /// command and server discovery and monitoring events.
    public let eventMonitoring: Bool

    /// Specifies a ReadConcern to use for the client. If one is not specified,
    /// the server's default read concern will be used.
    public let readConcern: ReadConcern?

    /// Specifies a ReadPreference to use for the client.
    public let readPreference: ReadPreference?

    /// Specifies a WriteConcern to use for the client. If one is not specified,
    /// the server's default write concern will be used.
    public let writeConcern: WriteConcern?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public let dateCodingStrategy: DateCodingStrategy?

    /// Specifies the `UUIDCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public let uuidCodingStrategy: UUIDCodingStrategy?

    /// Specifies the `DataCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public let dataCodingStrategy: DataCodingStrategy?

    /// Convenience initializer allowing any/all to be omitted or optional
    public init(eventMonitoring: Bool = false,
                readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil,
                retryWrites: Bool? = nil,
                writeConcern: WriteConcern? = nil,
                dateCodingStrategy: DateCodingStrategy? = nil,
                uuidCodingStrategy: UUIDCodingStrategy? = nil,
                dataCodingStrategy: DataCodingStrategy? = nil) {
        self.retryWrites = retryWrites
        self.eventMonitoring = eventMonitoring
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.writeConcern = writeConcern
        self.dateCodingStrategy = dateCodingStrategy
        self.uuidCodingStrategy = uuidCodingStrategy
        self.dataCodingStrategy = dataCodingStrategy
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
public struct DatabaseOptions: CodingStrategyProvider {
    /// A read concern to set on the retrieved database. If one is not specified,
    /// the database will inherit the client's read concern.
    public let readConcern: ReadConcern?

    /// A read preference to set on the retrieved database. If one is not
    /// specified, the database will inherit the client's read preference.
    public let readPreference: ReadPreference?

    /// A write concern to set on the retrieved database. If one is not specified,
    /// the database will inherit the client's write concern.
    public let writeConcern: WriteConcern?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public let dateCodingStrategy: DateCodingStrategy?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public let uuidCodingStrategy: UUIDCodingStrategy?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public let dataCodingStrategy: DataCodingStrategy?

    /// Convenience initializer allowing any/all arguments to be omitted or optional
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

/// A MongoDB Client.
public class MongoClient {
    internal var _client: OpaquePointer?

    /// If command and/or server monitoring is enabled, stores the NotificationCenter events are posted to.
    internal var notificationCenter: NotificationCenter?

    /// If command and/or server monitoring is enabled, indicates what event types notifications will be posted for.
    internal var monitoringEventTypes: [MongoEventType]?

    /// Encoder whose options are inherited by databases derived from this client.
    public let encoder: BSONEncoder

    /// Decoder whose options are inherited by databases derived from this client.
    public let decoder: BSONDecoder

    /// The read concern set on this client, or nil if one is not set.
    public var readConcern: ReadConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let rc = ReadConcern(from: mongoc_client_get_read_concern(self._client))
        return rc.isDefault ? nil : rc
    }

    /// The `ReadPreference` set on this client
    public var readPreference: ReadPreference? {
        return ReadPreference(from: mongoc_client_get_read_prefs(self._client))
    }

    /// The write concern set on this client, or nil if one is not set.
    public var writeConcern: WriteConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let wc = WriteConcern(from: mongoc_client_get_write_concern(self._client))
        return wc.isDefault ? nil : wc
    }

    /**
     * Create a new client connection to a MongoDB server.
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to.
     *   - options: optional `ClientOptions` to use for this client
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
     *
     * - Throws:
     *   - A `UserError.invalidArgumentError` if the connection string passed in is improperly formatted.
     *   - A `UserError.invalidArgumentError` if the connection string specifies the use of TLS but libmongoc was not
     *     built with TLS support.
     */
    public init(_ connectionString: String = "mongodb://localhost:27017", options: ClientOptions? = nil) throws {
        var error = bson_error_t()
        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw parseMongocError(error)
        }
        defer { mongoc_uri_destroy(uri) }

        // if retryWrites is specified, set it on the uri (libmongoc does not provide api for setting it on the client).
        if let rw = options?.retryWrites {
            mongoc_uri_set_option_as_bool(uri, MONGOC_URI_RETRYWRITES, rw)
        }

        self._client = mongoc_client_new_from_uri(uri)
        guard self._client != nil else {
            throw UserError.invalidArgumentError(message: "libmongoc not built with TLS support")
        }

        // if a readConcern is provided, set it on the client
        if let rc = options?.readConcern {
            mongoc_client_set_read_concern(self._client, rc._readConcern)
        }

        // if a readPreference is provided, set it on the client
        if let rp = options?.readPreference {
            mongoc_client_set_read_prefs(self._client, rp._readPreference)
        }

        // if a writeConcern is provided, set it on the client
        if let wc = options?.writeConcern {
            mongoc_client_set_write_concern(self._client, wc._writeConcern)
        }

        self.encoder = BSONEncoder(options: options)
        self.decoder = BSONDecoder(options: options)

        if options?.eventMonitoring == true { self.initializeMonitoring() }

        guard mongoc_client_set_error_api(self._client, MONGOC_ERROR_API_VERSION_2) else {
            self.close()
            throw RuntimeError.internalError(message: "Could not configure error handling on client")
        }
    }

    /**
     * :nodoc:
     * Create a new client from an existing `mongoc_client_t`.
     * Do not use this initializer unless you know what you are doing.
     *
     * If this client was derived from a pool, ensure that the error api version was set to 2 on the pool.
     *
     * - Parameters:
     *   - fromPointer: the `mongoc_client_t` to store and use internally
     */
    public init(fromPointer: OpaquePointer) {
        self._client = fromPointer

        // This call may fail, and if it does, either the error api version was already set or the client was derived
        // from a pool. In either case, the error handling in MongoSwift will be incorrect unless the correct api
        // version was set by the caller.
        mongoc_client_set_error_api(self._client, MONGOC_ERROR_API_VERSION_2)

        self.encoder = BSONEncoder()
        self.decoder = BSONDecoder()
    }

    /// Cleans up internal state.
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
    private func startSession(options: SessionOptions) throws -> ClientSession {
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
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if the options passed are an invalid combination.
     *   - `EncodingError` if an error is encountered while encoding the options to BSON.
     */
    public func listDatabases(options: ListDatabasesOptions? = nil) throws -> MongoCursor<Document> {
        let opts = try self.encoder.encode(options)
        guard let cursor = mongoc_client_find_databases_with_opts(self._client, opts?.data) else {
            fatalError("Couldn't get cursor from the server")
        }
        return try MongoCursor(fromCursor: cursor, withClient: self, withDecoder: self.decoder)
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
    public func db(_ name: String, options: DatabaseOptions? = nil) -> MongoDatabase {
        guard let db = mongoc_client_get_database(self._client, name) else {
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

        let encoder = BSONEncoder(copies: self.encoder, options: options)
        let decoder = BSONDecoder(copies: self.decoder, options: options)

        return MongoDatabase(fromDatabase: db, withClient: self, withEncoder: encoder, withDecoder: decoder)
    }
}
