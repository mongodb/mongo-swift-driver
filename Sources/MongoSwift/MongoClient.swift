import Foundation
import NIO
import NIOConcurrencyHelpers

/// Options to use when creating a `MongoClient`.
public struct ClientOptions: CodingStrategyProvider, Decodable {
    /**
     * Indicates whether this client should publish command monitoring events. If true, the following event types will
     * be published, under the listed names (which are defined as static properties of `Notification.Name`):
     * - `CommandStartedEvent`: `.commandStarted`
     * - `CommandSucceededEvent`: `.commandSucceeded`
     * - `CommandFailedEvent`: `.commandFailed`
     */
    public var commandMonitoring: Bool = false

    // swiftlint:disable redundant_optional_initialization

    /// Specifies the `DataCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var dataCodingStrategy: DataCodingStrategy? = nil

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var dateCodingStrategy: DateCodingStrategy? = nil

    /// If command and/or server monitoring is enabled, indicates the `NotificationCenter` events are posted to. If one
    /// is not specified, the application's default `NotificationCenter` will be used.
    public var notificationCenter: NotificationCenter?

    /// Specifies a ReadConcern to use for the client.
    public var readConcern: ReadConcern?

    /// Specifies a ReadPreference to use for the client.
    public var readPreference: ReadPreference? = nil

    /// Determines whether the client should retry supported read operations (on by default).
    public var retryReads: Bool?

    /// Determines whether the client should retry supported write operations (on by default).
    public var retryWrites: Bool?

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

    /**
     * `MongoSwift.MongoClient` provides an asynchronous API by running all blocking operations off of their
     * originating threads in a thread pool. `MongoSwiftSync.MongoClient` is implemented as a wrapper of the async
     * client which waits for each corresponding asynchronous operation to complete and then returns the result.
     * This option specifies the size of the thread pool used by the asynchronous client, and determines the max
     * number of concurrent operations that may be performed using a single client.
     */
    public var threadPoolSize: Int? = MongoClient.defaultThreadPoolSize

    /// Specifies the TLS/SSL options to use for database connections.
    public var tlsOptions: TLSOptions? = nil

    /// Specifies the `UUIDCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var uuidCodingStrategy: UUIDCodingStrategy? = nil

    // swiftlint:enable redundant_optional_initialization

    /// Specifies a WriteConcern to use for the client.
    public var writeConcern: WriteConcern?

    private enum CodingKeys: CodingKey {
        case retryWrites, retryReads, readConcern, writeConcern
    }

    /// Convenience initializer allowing any/all to be omitted or optional.
    public init(
        commandMonitoring: Bool = false,
        dataCodingStrategy: DataCodingStrategy? = nil,
        dateCodingStrategy: DateCodingStrategy? = nil,
        notificationCenter: NotificationCenter? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        retryReads: Bool? = nil,
        retryWrites: Bool? = nil,
        serverMonitoring: Bool = false,
        threadPoolSize: Int = MongoClient.defaultThreadPoolSize,
        tlsOptions: TLSOptions? = nil,
        uuidCodingStrategy: UUIDCodingStrategy? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.commandMonitoring = commandMonitoring
        self.dataCodingStrategy = dataCodingStrategy
        self.dateCodingStrategy = dateCodingStrategy
        self.notificationCenter = notificationCenter
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.retryWrites = retryWrites
        self.retryReads = retryReads
        self.serverMonitoring = serverMonitoring
        self.threadPoolSize = threadPoolSize
        self.tlsOptions = tlsOptions
        self.uuidCodingStrategy = uuidCodingStrategy
        self.writeConcern = writeConcern
    }
}

/// Options to use when retrieving a `MongoDatabase` from a `MongoClient`.
public struct DatabaseOptions: CodingStrategyProvider {
    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public var dataCodingStrategy: DataCodingStrategy?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public var dateCodingStrategy: DateCodingStrategy?

    /// A read concern to set on the retrieved database.
    public var readConcern: ReadConcern?

    /// A read preference to set on the retrieved database.
    public var readPreference: ReadPreference?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this database and
    /// any collections that derive from it.
    public var uuidCodingStrategy: UUIDCodingStrategy?

    /// A write concern to set on the retrieved database.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all arguments to be omitted or optional.
    public init(
        dataCodingStrategy: DataCodingStrategy? = nil,
        dateCodingStrategy: DateCodingStrategy? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        uuidCodingStrategy: UUIDCodingStrategy? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.dataCodingStrategy = dataCodingStrategy
        self.dateCodingStrategy = dateCodingStrategy
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.uuidCodingStrategy = uuidCodingStrategy
        self.writeConcern = writeConcern
    }
}

/// Options used to configure TLS/SSL connections to the database.
public struct TLSOptions {
    /// Indicates whether invalid hostnames are allowed. By default this is set to false.
    public var allowInvalidHostnames: Bool?

    /// Specifies the path to the certificate authority file.
    public var caFile: URL?

    /// Specifies the path to the client certificate key file.
    public var pemFile: URL?

    /// Specifies the client certificate key password.
    public var pemPassword: String?

    /// Indicates whether invalid certificates are allowed. By default this is set to false.
    public var weakCertValidation: Bool?

    /// Convenience initializer allowing any/all arguments to be omitted or optional.
    public init(
        allowInvalidHostnames: Bool? = nil,
        caFile: URL? = nil,
        pemFile: URL? = nil,
        pemPassword: String? = nil,
        weakCertValidation: Bool? = nil
    ) {
        self.allowInvalidHostnames = allowInvalidHostnames
        self.caFile = caFile
        self.pemFile = pemFile
        self.pemPassword = pemPassword
        self.weakCertValidation = weakCertValidation
    }
}

// sourcery: skipSyncExport
/// A MongoDB Client providing an asynchronous, SwiftNIO-based API.
public class MongoClient {
    internal let connectionPool: ConnectionPool

    internal let operationExecutor: OperationExecutor

    // TODO: SWIFT-705 document size justification.
    /// Default size for a client's NIOThreadPool.
    public static let defaultThreadPoolSize = 5

    /// Indicates whether this client has been closed.
    internal private(set) var isClosed = false

    /// If command and/or server monitoring is enabled, stores the NotificationCenter events are posted to.
    internal let notificationCenter: NotificationCenter

    /// Counter for generating client _ids.
    internal static var clientIdGenerator = NIOAtomic<Int>.makeAtomic(value: 0)

    /// A unique identifier for this client. Sets _id to the generator's current value and increments the generator.
    internal let _id = clientIdGenerator.add(1)

    /// Error thrown when user attempts to use a closed client.
    internal static let ClosedClientError = LogicError(message: "MongoClient was already closed")

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
     * Create a new client for a MongoDB deployment. For options that included in both the connection string URI
     * and the ClientOptions struct, the final value is set in descending order of priority: the value specified in
     * ClientOptions (if non-nil), the value specified in the URI, or the default value if both are unset.
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to.
     *   - eventLoopGroup: A SwiftNIO `EventLoopGroup` which the client will use for executing operations. It is the
     *                     user's responsibility to ensure the group remains active for as long as the client does, and
     *                     to ensure the group is properly shut down when it is no longer in use.
     *   - options: optional `ClientOptions` to use for this client
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
     *
     * - Throws:
     *   - A `InvalidArgumentError` if the connection string passed in is improperly formatted.
     *   - A `InvalidArgumentError` if the connection string specifies the use of TLS but libmongoc was not
     *     built with TLS support.
     */
    public init(
        _ connectionString: String = "mongodb://localhost:27017",
        using eventLoopGroup: EventLoopGroup,
        options: ClientOptions? = nil
    ) throws {
        // Initialize mongoc. Repeated calls have no effect so this is safe to do every time.
        initializeMongoc()

        let connString = try ConnectionString(connectionString, options: options)
        self.connectionPool = try ConnectionPool(from: connString, options: options?.tlsOptions)
        self.operationExecutor = DefaultOperationExecutor(
            eventLoopGroup: eventLoopGroup,
            threadPoolSize: options?.threadPoolSize ?? MongoClient.defaultThreadPoolSize
        )

        let rc = connString.readConcern
        if !rc.isDefault {
            self.readConcern = rc
        } else {
            self.readConcern = nil
        }

        let wc = connString.writeConcern
        if !wc.isDefault {
            self.writeConcern = wc
        } else {
            self.writeConcern = nil
        }

        self.readPreference = connString.readPreference
        self.encoder = BSONEncoder(options: options)
        self.decoder = BSONDecoder(options: options)
        self.notificationCenter = options?.notificationCenter ?? NotificationCenter.default

        self.connectionPool.initializeMonitoring(
            commandMonitoring: options?.commandMonitoring ?? false,
            serverMonitoring: options?.serverMonitoring ?? false,
            client: self
        )
    }

    deinit {
        assert(self.isClosed, "MongoClient was not closed before deinitialization")
    }

    /// Closes this `MongoClient`. Call this method exactly once when you are finished using the client. You must
    /// ensure that all operations using the client have completed before calling this. The returned future must be
    /// fulfilled before the client goes out of scope.
    public func close() -> EventLoopFuture<Void> {
        return self.operationExecutor.execute {
            self.connectionPool.close()
            self.isClosed = true
        }
        .flatMap {
            self.operationExecutor.close()
        }
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
    public func withSession<T>(
        options: ClientSessionOptions? = nil,
        _ sessionBody: (ClientSession) throws -> T
    ) throws -> T {
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
     * - Returns: An `EventLoopFuture<[DatabaseSpecification]>` containing the databases matching provided criteria.
     *
     * - Throws:
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error is encountered while encoding the options to BSON.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/listDatabases/
     */
    public func listDatabases(
        _ filter: Document? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[DatabaseSpecification]> {
        let operation = ListDatabasesOperation(client: self, filter: filter, nameOnly: nil)
        return self.executeOperationAsync(operation, session: session).flatMapThrowing { result in
            guard case let .specs(dbs) = result else {
                throw InternalError(message: "Invalid result")
            }
            return dbs
        }
    }

    /**
     * Get a list of `MongoDatabase`s.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `EventLoopFuture<[MongoDatabase]>` containing databases that match the provided filter.
     *
     * - Throws:
     *   - `LogicError` if the provided session is inactive.
     */
    public func listMongoDatabases(
        _ filter: Document? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[MongoDatabase]> {
        return self.listDatabaseNames(filter, session: session).map { $0.map { self.db($0) } }
    }

    /**
     * Get a list of names of databases.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `EventLoopFuture<[String]>` containing names of databases that match the provided filter.
     *
     * - Throws:
     *   - `LogicError` if the provided session is inactive.
     */
    public func listDatabaseNames(
        _ filter: Document? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[String]> {
        let operation = ListDatabasesOperation(client: self, filter: filter, nameOnly: true)
        return self.executeOperationAsync(operation, session: session).flatMapThrowing { result in
            guard case let .names(names) = result else {
                throw InternalError(message: "Invalid result")
            }
            return names
        }
    }

    /**
     * Gets a `MongoDatabase` instance for the given database name. If an option is not specified in the optional
     * `DatabaseOptions` param, the database will inherit the value from the parent client or the default if
     * the client’s option is not set. To override an option inherited from the client (e.g. a read concern) with the
     * default value, it must be explicitly specified in the options param (e.g. ReadConcern(), not nil).
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
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster -
     * excluding system collections and the "config", "local", and "admin" databases.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *
     * - Returns: a `ChangeStream` on all collections in all databases in a cluster.
     *
     * - Throws:
     *   - `CommandError` if an error occurs on the server while creating the change stream.
     *   - `InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch(
        _ pipeline: [Document] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil
    ) throws -> ChangeStream<ChangeStreamEvent<Document>> {
        return try self.watch(pipeline, options: options, session: session, withFullDocumentType: Document.self)
    }

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster -
     * excluding system collections and the "config", "local", and "admin" databases. Associates the specified
     * `Codable` type `T` with the `fullDocument` field in the `ChangeStreamEvent`s emitted by the returned
     * `ChangeStream`.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the `fullDocument` field of the emitted `ChangeStreamEvent`s will be
     *                           decoded to.
     *
     * - Returns: A `ChangeStream` on all collections in all databases in a cluster.
     *
     * - Throws:
     *   - `CommandError` if an error occurs on the server while creating the change stream.
     *   - `InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<FullDocType: Codable>(
        _ pipeline: [Document] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withFullDocumentType _: FullDocType.Type
    )
        throws -> ChangeStream<ChangeStreamEvent<FullDocType>> {
        return try self.watch(
            pipeline,
            options: options,
            session: session,
            withEventType: ChangeStreamEvent<FullDocType>.self
        )
    }

    /**
     * Starts a `ChangeStream` on a `MongoClient`. Allows the client to observe all changes in a cluster -
     * excluding system collections and the "config", "local", and "admin" databases. Associates the specified
     * `Codable` type `T` with the returned `ChangeStream`.
     *
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withEventType: The type that the entire change stream response will be decoded to and that will be returned
     *                    when iterating through the change stream.
     *
     * - Returns: A `ChangeStream` on all collections in all databases in a cluster.
     *
     * - Throws:
     *   - `CommandError` if an error occurs on the server while creating the change stream.
     *   - `InvalidArgumentError` if the options passed formed an invalid combination.
     *   - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<EventType: Codable>(
        _ pipeline: [Document] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withEventType _: EventType.Type
    ) throws -> ChangeStream<EventType> {
        let operation = try WatchOperation<Document, EventType>(
            target: .client(self),
            pipeline: pipeline,
            options: options
        )
        return try self.executeOperation(operation, session: session)
    }

    /// Executes an `Operation` using this `MongoClient` and an optionally provided session.
    internal func executeOperation<T: Operation>(
        _ operation: T,
        using connection: Connection? = nil,
        session: ClientSession? = nil
    ) throws -> T.OperationResult {
        return try self.operationExecutor.execute(operation, using: connection, client: self, session: session).wait()
    }

    /// Executes an `Operation` asynchronously using this `MongoClient` and an optionally provided session.
    internal func executeOperationAsync<T: Operation>(
        _ operation: T,
        using connection: Connection? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<T.OperationResult> {
        return self.operationExecutor.execute(operation, using: connection, client: self, session: session)
    }
}

extension MongoClient: Equatable {
    public static func == (lhs: MongoClient, rhs: MongoClient) -> Bool {
        return lhs._id == rhs._id
    }
}
