import Foundation
import mongoc

/// Options to use when creating a `MongoClient`.
public struct ClientOptions: CodingStrategyProvider, Decodable {
    /// Determines whether the client should retry supported write operations.
    public var retryWrites: Bool?

    /// Indicates whether this client should be set up to enable monitoring command and server discovery and monitoring
    /// events.
    public var eventMonitoring: Bool

    /// Specifies a ReadConcern to use for the client. If one is not specified, the server's default read concern will
    /// be used.
    public var readConcern: ReadConcern?

    /// Specifies a WriteConcern to use for the client. If one is not specified, the server's default write concern
    /// will be used.
    public var writeConcern: WriteConcern?

    // swiftlint:disable redundant_optional_initialization

    /// Specifies a ReadPreference to use for the client.
    public var readPreference: ReadPreference? = nil

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var dateCodingStrategy: DateCodingStrategy? = nil

    /// Specifies the `UUIDCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var uuidCodingStrategy: UUIDCodingStrategy? = nil

    /// Specifies the `DataCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var dataCodingStrategy: DataCodingStrategy? = nil

    // swiftlint:enable redundant_optional_initialization

    private enum CodingKeys: CodingKey {
        case retryWrites, eventMonitoring, readConcern, writeConcern
    }

    /// Convenience initializer allowing any/all to be omitted or optional.
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

/// Options to use when retrieving a `MongoDatabase` from a `MongoClient`.
public struct DatabaseOptions: CodingStrategyProvider {
    /// A read concern to set on the retrieved database. If one is not specified, the database will inherit the
    /// client's read concern.
    public var readConcern: ReadConcern?

    /// A read preference to set on the retrieved database. If one is not specified, the database will inherit the
    /// client's read preference.
    public var readPreference: ReadPreference?

    /// A write concern to set on the retrieved database. If one is not specified, the database will inherit the
    /// client's write concern.
    public var writeConcern: WriteConcern?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public var dateCodingStrategy: DateCodingStrategy?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public var uuidCodingStrategy: UUIDCodingStrategy?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
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

/// A MongoDB Client.
public class MongoClient {
    // TODO SWIFT-374: remove this property.
    internal let _client: OpaquePointer

    internal let connectionPool: ConnectionPool

    private let operationExecutor: OperationExecutor = DefaultOperationExecutor()

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
    public var readPreference: ReadPreference {
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
        // Initialize mongoc. Repeated calls have no effect so this is safe to do every time.
        initializeMongoc()

        // TODO: when we stop storing _client, we will store these options and use them to determine the return values
        // for MongoClient.readConcern, etc.
        var options = options ?? ClientOptions()
        let connString = try ConnectionString(connectionString, options: &options)
        self.connectionPool = try ConnectionPool(from: connString)

        // temporarily retrieve the single client from the pool.
        self._client = try self.connectionPool.checkOut().clientHandle

        self.encoder = BSONEncoder(options: options)
        self.decoder = BSONDecoder(options: options)

        if options.eventMonitoring { self.initializeMonitoring() }
    }

    /**
     * :nodoc:
     */
     @available(*, deprecated, message: "Use MongoClient(stealing:) instead.")
     public convenience init(fromPointer pointer: OpaquePointer) {
        self.init(stealing: pointer)
     }

    /**
     * :nodoc:
     * Create a new client from an existing `mongoc_client_t`. The new client will destroy the `mongoc_client_t` upon
     * deinitialization.
     * Do not use this initializer unless you know what you are doing. You *must* call libmongoc_init *before* using
     * this initializer for the first time.
     *
     * If this client was derived from a pool, ensure that the error api version was set to 2 on the pool.
     *
     * - Parameters:
     *   - pointer: the `mongoc_client_t` to store and use internally
     */
    public init(stealing pointer: OpaquePointer) {
        self._client = pointer
        self.connectionPool = ConnectionPool(stealing: pointer)
        self.encoder = BSONEncoder()
        self.decoder = BSONDecoder()
    }

    /**
     * Starts a new `ClientSession` with the provided options.
     *
     * - Throws:
     *   - `RuntimeError.compatibilityError` if the deployment does not support sessions.
     */
    public func startSession(options: ClientSessionOptions? = nil) throws -> ClientSession {
        return try ClientSession(client: self, options: options)
    }

    /**
     * Starts a new `ClientSession` with the provided options and passes it to the provided closure.
     * The session is only valid within the body of the closure and will be ended after the body completes.
     *
     * - Throws:
     *   - `RuntimeError.compatibilityError` if the deployment does not support sessions.
     */
    public func withSession<T>(options: ClientSessionOptions? = nil,
                               _ sessionBody: (ClientSession) throws -> T) throws -> T {
        let session = try ClientSession(client: self, options: options)
        defer { session.end() }
        return try sessionBody(session)
    }

    /**
     * Run the `listDatabases` command.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter that the listed databases must pass.
     *
     * - Returns: A `MongoCursor` over `Document`s describing the databases matching provided criteria
     *
     * - Throws:
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error is encountered while encoding the options to BSON.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/listDatabases/
     */
    public func listDatabases(_ filter: Document? = nil,
                              session: ClientSession? = nil) throws -> ListDatabasesResult {
        let operation = ListDatabasesOperation(client: self, filter: filter, options: nil, session: session)
        guard case let .full(result) = try operation.execute() else {
            throw RuntimeError.internalError(message: "Invalid result")
        }
        return result
    }

    /**
     * Get a list of `MongoDatabase`s.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter that the listed databases must pass.
     *
     * - Returns: An Array of `MongoDatabase`s that match the provided filter.
     *
     * - Throws:
     *   - `UserError.logicError` if the provided session is inactive.
     */
    public func listMongoDatabases(_ filter: Document? = nil, session: ClientSession? = nil) throws -> [MongoDatabase] {
        return try self.listDatabaseNames(filter, session: session).map { self.db($0) }
    }

    /**
     * Get a list of names of databases.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter that the listed databases must pass.
     *
     * - Returns: An Array of `MongoDatabase`s that match the provided filter.
     *
     * - Throws:
     *   - `UserError.logicError` if the provided session is inactive.
     */
    public func listDatabaseNames(_ filter: Document? = nil, session: ClientSession? = nil) throws -> [String] {
        let operation = ListDatabasesOperation(client: self,
                                               filter: filter,
                                               options: ListDatabasesOptions(nameOnly: true),
                                               session: session)
        guard case let .names(result) = try operation.execute() else {
            throw RuntimeError.internalError(message: "Invalid result")
        }
        return result
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
        return MongoDatabase(name: name, client: self, options: options)
    }

    /// Executes an `Operation` using this `MongoClient` and an optionally provided session.
    internal func executeOperation<T: Operation>(_ operation: T,
                                                 session: ClientSession? = nil) throws -> T.OperationResult {
        return try self.operationExecutor.execute(operation, client: self, session: session)
    }
}
