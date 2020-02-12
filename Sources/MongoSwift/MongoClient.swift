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
        self.operationExecutor = OperationExecutor(
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
    /// fulfilled before the `EventLoopGroup` provided to this client's constructor is shut down.
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
     * Closes this `MongoClient` in a blocking fashion.
     * Call this method exactly once when you are finished using the client. You must ensure that all operations
     * using the client have completed before calling this.
     *
     * This method must complete before the `EventLoopGroup` provided to this client's constructor is shut down.
     */
    public func syncClose() {
        self.connectionPool.close()
        self.isClosed = true
        // TODO: SWIFT-349 log any errors encountered here.
        try? self.operationExecutor.syncClose()
    }

    /// Starts a new `ClientSession` with the provided options. When you are done using this session, you must call
    /// `ClientSession.end()` on it.
    public func startSession(options: ClientSessionOptions? = nil) -> ClientSession {
        return ClientSession(client: self, options: options)
    }

    /**
     * Starts a new `ClientSession` with the provided options and passes it to the provided closure.
     * The session is only valid within the body of the closure and will be ended after the body completes.
     *
     * - Parameters:
     *   - options: Options to use when creating the session.
     *   - sessionBody: A closure which takes in a `ClientSession` and returns an `EventLoopFuture<T>`.
     *
     * - Returns:
     *    An `EventLoopFuture<T>`, the return value of the user-provided closure.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `CompatibilityError` if the deployment does not support sessions.
     *    - `LogicError` if this client has already been closed.
     */
    public func withSession<T>(
        options: ClientSessionOptions? = nil,
        _ sessionBody: (ClientSession) throws -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        let promise = self.operationExecutor.makePromise(of: T.self)
        let session = self.startSession(options: options)
        do {
            let bodyFuture = try sessionBody(session)
            // regardless of whether body's returned future succeeds we want to call session.end() once its complete.
            // only once session.end() finishes can we fulfill the returned promise. otherwise the user can't tell if
            // it is safe to close the parent client of this session, and they could inadvertently close it before the
            // session is actually ended and its parent `mongoc_client_t` is returned to the pool.
            bodyFuture.flatMap { _ in
                session.end()
            }.flatMapError { _ in
                session.end()
            }.whenComplete { _ in
                promise.completeWith(bodyFuture)
            }
        } catch {
            session.end().whenComplete { _ in
                promise.fail(error)
            }
        }

        return promise.futureResult
    }

    /**
     * Retrieves a list of databases in this client's MongoDB deployment.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter that the listed databases must pass. This filter can be based
     *     on the "name", "sizeOnDisk", "empty", or "shards" fields of the output.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns:
     *    An `EventLoopFuture<[DatabaseSpecification]>`. On success, the future contains an array of the specifications
     *    of databases matching the provided criteria.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this client has already been closed.
     *    - `EncodingError` if an error is encountered while encoding the options to BSON.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/listDatabases/
     */
    public func listDatabases(
        _ filter: Document? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[DatabaseSpecification]> {
        let operation = ListDatabasesOperation(client: self, filter: filter, nameOnly: nil)
        return self.operationExecutor.execute(operation, client: self, session: session).flatMapThrowing { result in
            guard case let .specs(dbs) = result else {
                throw InternalError(message: "Invalid result")
            }
            return dbs
        }
    }

    /**
     * Get a list of `MongoDatabase`s corresponding to the databases in this client's MongoDB deployment.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[MongoDatabase]>`. On success, the future contains an array of `MongoDatabase`s that
     *    match the provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this client has already been closed.
     */
    public func listMongoDatabases(
        _ filter: Document? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[MongoDatabase]> {
        return self.listDatabaseNames(filter, session: session).map { $0.map { self.db($0) } }
    }

    /**
     * Get the names of databases in this client's MongoDB deployment.
     *
     * - Parameters:
     *   - filter: Optional `Document` specifying a filter on the names of the returned databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[String]>`. On success, the future contains an array of names of databases that
     *    match the provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this client has already been closed.
     */
    public func listDatabaseNames(
        _ filter: Document? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[String]> {
        let operation = ListDatabasesOperation(client: self, filter: filter, nameOnly: true)
        return self.operationExecutor.execute(operation, client: self, session: session).flatMapThrowing { result in
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
     * - Returns: a `MongoDatabase` corresponding to the provided database name.
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
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    deployment.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `CommandError` if an error occurs on the server while creating the change stream.
     *    - `InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the pipeline.
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
    ) -> EventLoopFuture<ChangeStream<ChangeStreamEvent<Document>>> {
        return self.watch(pipeline, options: options, session: session, withFullDocumentType: Document.self)
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
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    deployment.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `CommandError` if an error occurs on the server while creating the change stream.
     *    - `InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the pipeline.
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
    ) -> EventLoopFuture<ChangeStream<ChangeStreamEvent<FullDocType>>> {
        return self.watch(
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
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    deployment.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `CommandError` if an error occurs on the server while creating the change stream.
     *    - `InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the pipeline.
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
    ) -> EventLoopFuture<ChangeStream<EventType>> {
        let operation = WatchOperation<Document, EventType>(
            target: .client(self),
            pipeline: pipeline,
            options: options
        )
        return self.operationExecutor.execute(operation, client: self, session: session)
    }

    /// Executes an `Operation` using this `MongoClient` and an optionally provided session.
    internal func executeOperation<T: Operation>(
        _ operation: T,
        using connection: Connection? = nil,
        session: ClientSession? = nil
    ) throws -> T.OperationResult {
        return try self.operationExecutor.execute(operation, using: connection, client: self, session: session).wait()
    }
}

extension MongoClient: Equatable {
    public static func == (lhs: MongoClient, rhs: MongoClient) -> Bool {
        return lhs._id == rhs._id
    }
}
