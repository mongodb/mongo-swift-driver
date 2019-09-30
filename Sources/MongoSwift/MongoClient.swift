import Foundation
import mongoc

/// Options to use when creating a `MongoClient`.
public struct ClientOptions: CodingStrategyProvider, Decodable {
    /// Determines whether the client should retry supported write operations.
    public var retryWrites: Bool?

    /**
     * Indicates whether this client should publish command monitoring events. If true, the following event types will
     * be published, under the listed names (which are defined as static properties of `Notification.Name`):
     * - `CommandStartedEvent`: `.commandStarted`
     * - `CommandSucceededEvent`: `.commandSucceeded`
     * - `CommandFailedEvent`: `.commandFailed`
     */
    public var commandMonitoring: Bool = false

    /**
     * Indicates whether this client should publish command monitoring events. If true, the following event types will
     * be published, under the listed names (which are defined as static properties of `Notification.Name`):
     * - `ServerOpeningEvent`: `.serverOpening`
     * - `ServerClosedEvent`: `.serverClosed`
     * - `ServerDescriptionChangedEvent`: `.serverDescriptionChanged`
     * - `TopologyOpeningEvent`: `.topologyOpening`
     * - `TopologyClosedEvent`: `.topologyClosed`
     * - `TopologyDescriptionChangedEvent`: `.topologyDescriptionChanged`
     * - `ServerHeartbeatStartedEvent`: `serverHeartbeatStarted`
     * - `ServerHeartbeatSucceededEvent`: `serverHeartbeatSucceeded`
     * - `ServerHeartbeatFailedEvent`: `serverHeartbeatFailed`
     */
    public var serverMonitoring: Bool = false

    /// If command and/or server monitoring is enabled, indicates the `NotificationCenter` events are posted to. If one
    /// is not specified, the application's default `NotificationCenter` will be used.
    public var notificationCenter: NotificationCenter?

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

    public var tlsConfig: TLSConfig? = nil

    // swiftlint:enable redundant_optional_initialization

    private enum CodingKeys: CodingKey {
        case retryWrites, readConcern, writeConcern
    }

    /// Convenience initializer allowing any/all to be omitted or optional.
    public init(readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil,
                retryWrites: Bool? = nil,
                writeConcern: WriteConcern? = nil,
                commandMonitoring: Bool = false,
                serverMonitoring: Bool = false,
                notificationCenter: NotificationCenter? = nil,
                dateCodingStrategy: DateCodingStrategy? = nil,
                uuidCodingStrategy: UUIDCodingStrategy? = nil,
                dataCodingStrategy: DataCodingStrategy? = nil,
                tlsConfig: TLSConfig? = nil) {
        self.retryWrites = retryWrites
        self.commandMonitoring = commandMonitoring
        self.serverMonitoring = serverMonitoring
        self.notificationCenter = notificationCenter
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.writeConcern = writeConcern
        self.dateCodingStrategy = dateCodingStrategy
        self.uuidCodingStrategy = uuidCodingStrategy
        self.dataCodingStrategy = dataCodingStrategy
        self.tlsConfig = tlsConfig
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

/// Options used to configure TLS/SSL connections to the database.
public struct TLSConfig {
    /// Specifies the path to the client certificate key file.
    public var pemFile: String?

    /// Specifies the path to the client certificate key password.
    public var pemPassword: String?

    /// Specifies the path to the certificate authority file.
    public var caFile: String?

    /// Indicates whether invalid certificates are allowed. By default this is set to false.
    public var weakCertValidation: Bool?

    /// Indicates whether invalid hostnames are allowed. By default this is set to false.
    public var allowInvalidHostnames: Bool?

    /// Convenience initializer allowing any/all arguments to be omitted or optional.
    public init(pemFile: String? = nil,
                pemPassword: String? = nil,
                caFile: String? = nil,
                weakCertValidation: Bool? = nil,
                allowInvalidHostnames: Bool? = nil) {
        self.pemFile = pemFile
        self.pemPassword = pemPassword
        self.caFile = caFile
        self.weakCertValidation = weakCertValidation
        self.allowInvalidHostnames = allowInvalidHostnames
    }
}

/// A MongoDB Client.
public class MongoClient {
    internal let connectionPool: ConnectionPool

    private let operationExecutor: OperationExecutor = DefaultOperationExecutor()

    /// If command and/or server monitoring is enabled, stores the NotificationCenter events are posted to.
    internal let notificationCenter: NotificationCenter

    /// A unique identifier for this client.
    internal let _id = clientIdGenerator.next()

    /// Counter for generating client _ids.
    internal static let clientIdGenerator = Counter(label: "MongoClient ID generator")

    /// Encoder whose options are inherited by databases derived from this client.
    public let encoder: BSONEncoder

    /// Decoder whose options are inherited by databases derived from this client.
    public let decoder: BSONDecoder

    /// The read concern set on this client, or nil if one is not set.
    public let readConcern: ReadConcern?

    /// The `ReadPreference` set on this client.
    public let readPreference: ReadPreference

    /// The write concern set on this client, or nil if one is not set.
    public let writeConcern: WriteConcern?

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

        var options = options ?? ClientOptions()
        let connString = try ConnectionString(connectionString, options: &options)
        self.connectionPool = try ConnectionPool(from: connString, withTLSConfig: options.tlsConfig)

        if let rc = options.readConcern, !rc.isDefault {
            self.readConcern = rc
        } else {
            self.readConcern = nil
        }

        if let wc = options.writeConcern, !wc.isDefault {
            self.writeConcern = wc
        } else {
            self.writeConcern = nil
        }

        self.readPreference = options.readPreference ?? ReadPreference(.primary)
        self.encoder = BSONEncoder(options: options)
        self.decoder = BSONDecoder(options: options)
        self.notificationCenter = options.notificationCenter ?? NotificationCenter.default

        self.connectionPool.initializeMonitoring(commandMonitoring: options.commandMonitoring,
                                                 serverMonitoring: options.serverMonitoring,
                                                 client: self)
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
        self.connectionPool = ConnectionPool(stealing: pointer)
        self.encoder = BSONEncoder()
        self.decoder = BSONDecoder()
        self.readConcern = nil
        self.readPreference = ReadPreference(.primary)
        self.writeConcern = nil
        self.notificationCenter = NotificationCenter.default
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
     *   - filter: Optional `Document` specifying a filter that the listed databases must pass. This filter can be based
     *     on the "name", "sizeOnDisk", "empty", or "shards" fields of the output.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns: A `[DatabaseSpecification]` containing the databases matching provided criteria.
     *
     * - Throws:
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error is encountered while encoding the options to BSON.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/listDatabases/
     */
    public func listDatabases(_ filter: Document? = nil,
                              session: ClientSession? = nil) throws -> [DatabaseSpecification] {
        let operation = ListDatabasesOperation(client: self,
                                               filter: filter,
                                               nameOnly: nil)
        guard case let .specs(result) = try self.executeOperation(operation, session: session) else {
            throw RuntimeError.internalError(message: "Invalid result")
        }
        return result
    }

    /**
     * Get a list of `MongoDatabase`s.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - session: Optional `ClientSession` to use when executing this command
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
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `[String]` containing names of databases that match the provided filter.
     *
     * - Throws:
     *   - `UserError.logicError` if the provided session is inactive.
     */
    public func listDatabaseNames(_ filter: Document? = nil, session: ClientSession? = nil) throws -> [String] {
        let operation = ListDatabasesOperation(client: self,
                                               filter: filter,
                                               nameOnly: true)
        guard case let .names(result) = try self.executeOperation(operation, session: session) else {
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

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster - excluding
     * system collections and the "config", "local", and "admin" databases.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     * - Returns: a `ChangeStream` on all collections in all databases in a cluster.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch(_  pipeline: [Document] = [],
                      options: ChangeStreamOptions?  =  nil,
                      session: ClientSession? = nil) throws -> ChangeStream<ChangeStreamEvent<Document>> {
        return try self.watch(pipeline, options: options, session: session, withFullDocumentType: Document.self)
    }

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster - excluding
     * system collections and the "config", "local", and "admin" databases. Associates the specified `Codable` type `T`
     * with the `fullDocument` field in the `ChangeStreamEvent`s emitted by the returned `ChangeStream`.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the `fullDocument` field of the emitted `ChangeStreamEvent`s will be
     *                           decoded to.
     * - Returns: A `ChangeStream` on all collections in all databases in a cluster.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<T: Codable>(_  pipeline: [Document] = [],
                                  options: ChangeStreamOptions?  =  nil,
                                  session: ClientSession? = nil,
                                  withFullDocumentType: T.Type) throws -> ChangeStream<ChangeStreamEvent<T>> {
        return try self.watch(pipeline,
                              options: options,
                              session: session,
                              withEventType: ChangeStreamEvent<T>.self)
    }

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster - excluding
     * system collections and the "config", "local", and "admin" databases. Associates the specified `Codable` type `T`
     * with the returned `ChangeStream`.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withEventType: The type that the entire change stream response will be decoded to and that will be returned
     *                    when iterating through the change stream.
     * - Returns: A `ChangeStream` on all collections in all databases in a cluster.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<T: Codable>(_  pipeline: [Document] = [],
                                  options: ChangeStreamOptions?  =  nil,
                                  session: ClientSession? = nil,
                                  withEventType: T.Type) throws -> ChangeStream<T> {
        let pipeline: Document = ["pipeline": pipeline]
        let opts = try encodeOptions(options: options, session: session)
        return try ChangeStream<T>(options: options, client: self, decoder: self.decoder, session: session) { conn in
            mongoc_client_watch(conn.clientHandle, pipeline._bson, opts?._bson)
        }
    }

    /// Executes an `Operation` using this `MongoClient` and an optionally provided session.
    internal func executeOperation<T: Operation>(_ operation: T,
                                                 session: ClientSession? = nil) throws -> T.OperationResult {
        return try self.operationExecutor.execute(operation, client: self, session: session)
    }
}

extension MongoClient: Equatable {
    public static func == (lhs: MongoClient, rhs: MongoClient) -> Bool {
        return lhs._id == rhs._id
    }
}
