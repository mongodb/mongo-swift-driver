import CLibMongoC
import Foundation
import NIO
import NIOConcurrencyHelpers

/// Options to use when creating a `MongoClient`.
public struct MongoClientOptions: CodingStrategyProvider {
    /// Specifies a custom app name. This value is used in MongoDB logs and profiling data.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/#urioption.appName
    public var appName: String?

    /// Specifies one or more compressors to use for network compression for communication between this client and
    /// mongod/mongos instances. Currently, the driver only supports compression via zlib.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/#urioption.compressors
    public var compressors: [Compressor]?

    /// Specifies the maximum time, in milliseconds, for an individual connection to establish a TCP
    /// connection to a MongoDB server before timing out.
    public var connectTimeoutMS: Int?

    /// Specifies authentication options for use with the client.
    public var credential: MongoCredential?

    /// Specifies the `DataCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var dataCodingStrategy: DataCodingStrategy?

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var dateCodingStrategy: DateCodingStrategy?

    /// When true, the client will connect directly to a single host. When false, the client will attempt to
    /// automatically discover all replica set members if a replica set name is provided. Defaults to false.
    /// It is an error to set this option to `true` when used with a mongodb+srv connection string or when multiple
    /// hosts are specified in the connection string.
    public var directConnection: Bool?

    /// Controls how often the driver checks the state of the MongoDB deployment. Specifies the interval (in
    /// milliseconds) between checks, counted from the end of the previous check until the beginning of the next one.
    /// Defaults to 10 seconds (10,000 ms). Must be at least 500ms.
    public var heartbeatFrequencyMS: Int?

    /// The size (in milliseconds) of the permitted latency window beyond the fastest round-trip time amongst all
    /// servers. By default, only servers within 15ms of the fastest round-trip time receive queries.
    public var localThresholdMS: Int?

    /// The maximum number of connections that may be associated with a connection pool created by this client at a
    /// given time. This includes in-use and available connections. Defaults to 100.
    public var maxPoolSize: Int?

    /// An alternative lower bound for heartbeatFrequencyMS, used for speeding up tests (default 500ms).
    internal var minHeartbeatFrequencyMS: Int?

    /// Specifies a ReadConcern to use for the client.
    public var readConcern: ReadConcern?

    /// Specifies a ReadPreference to use for the client.
    public var readPreference: ReadPreference?

    /// Specifies the name of the replica set the driver should connect to.
    public var replicaSet: String?

    /// Determines whether the client should retry supported read operations (on by default).
    public var retryReads: Bool?

    /// Determines whether the client should retry supported write operations (on by default).
    public var retryWrites: Bool?

    // TODO: SWIFT-1159: add versioned API docs link.
    /// Specifies a MongoDB server API version and related options.
    public var serverAPI: MongoServerAPI?

    /// Specifies how long the driver should attempt to select a server for before throwing an error. Defaults to 30
    /// seconds (30000 ms).
    public var serverSelectionTimeoutMS: Int?

    /**
     * `MongoSwift.MongoClient` provides an asynchronous API by running all blocking operations off of their
     * originating threads in a thread pool. `MongoSwiftSync.MongoClient` is implemented as a wrapper of the async
     * client which waits for each corresponding asynchronous operation to complete and then returns the result.
     * This option specifies the size of the thread pool used by the asynchronous client, and determines the max
     * number of concurrent operations that may be performed using a single client. Defaults to 5.
     */
    public var threadPoolSize: Int?

    /// Whether or not to require TLS for connections to the server. By default this is set to false.
    ///
    /// - Note: Specifying any other "tls"-prefixed option will require TLS for connections to the server.
    public var tls: Bool?

    /// Indicates whether to bypass validation of the certificate presented by the mongod/mongos instance. By default
    /// this is set to false.
    public var tlsAllowInvalidCertificates: Bool?

    /// Indicates whether to disable hostname validation for the certificate presented by the mongod/mongos instance.
    /// By default this is set to false.
    public var tlsAllowInvalidHostnames: Bool?

    /// Specifies the location of a local .pem file that contains the root certificate chain from the Certificate
    /// Authority. This file is used to validate the certificate presented by the mongod/mongos instance.
    public var tlsCAFile: URL?

    /// Specifies the location of a local .pem file that contains either the client’s TLS certificate or the client’s
    /// TLS certificate and key. The client presents this file to the mongod/mongos instance.
    public var tlsCertificateKeyFile: URL?

    /// Specifies the password to de-crypt the `tlsCertificateKeyFile`.
    public var tlsCertificateKeyFilePassword: String?

    /// Indicates if revocation checking (CRL / OCSP) should be disabled.
    /// On macOS, this setting has no effect.
    /// By default this is set to false.
    /// It is an error to specify both this option and `tlsDisableOCSPEndpointCheck`, either via this options struct,
    /// connection string, or a combination of both.
    public var tlsDisableCertificateRevocationCheck: Bool?

    /// Indicates if OCSP responder endpoints should not be requested when an OCSP response is not stapled.
    /// On macOS, this setting has no effect.
    /// By default this is set to false.
    public var tlsDisableOCSPEndpointCheck: Bool?

    /// When specified, TLS constraints will be relaxed as much as possible. Currently, setting this option to `true`
    /// is equivalent to setting `tlsAllowInvalidCertificates`, `tlsAllowInvalidHostnames`, and
    /// `tlsDisableCertificateRevocationCheck` to `true`.
    /// It is an error to specify both this option and any of the options enabled by it, either via this options struct,
    /// connection string, or a combination of both.
    public var tlsInsecure: Bool?

    /// Specifies the `UUIDCodingStrategy` to use for BSON encoding/decoding operations performed by this client and any
    /// databases or collections that derive from it.
    public var uuidCodingStrategy: UUIDCodingStrategy?

    // swiftlint:enable redundant_optional_initialization

    /// Specifies a WriteConcern to use for the client.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        appName: String? = nil,
        compressors: [Compressor]? = nil,
        connectTimeoutMS: Int? = nil,
        credential: MongoCredential? = nil,
        dataCodingStrategy: DataCodingStrategy? = nil,
        dateCodingStrategy: DateCodingStrategy? = nil,
        directConnection: Bool? = nil,
        heartbeatFrequencyMS: Int? = nil,
        localThresholdMS: Int? = nil,
        maxPoolSize: Int? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        replicaSet: String? = nil,
        retryReads: Bool? = nil,
        retryWrites: Bool? = nil,
        serverAPI: MongoServerAPI? = nil,
        serverSelectionTimeoutMS: Int? = nil,
        threadPoolSize: Int? = nil,
        tls: Bool? = nil,
        tlsAllowInvalidCertificates: Bool? = nil,
        tlsAllowInvalidHostnames: Bool? = nil,
        tlsCAFile: URL? = nil,
        tlsCertificateKeyFile: URL? = nil,
        tlsCertificateKeyFilePassword: String? = nil,
        tlsInsecure: Bool? = nil,
        uuidCodingStrategy: UUIDCodingStrategy? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.appName = appName
        self.compressors = compressors
        self.connectTimeoutMS = connectTimeoutMS
        self.credential = credential
        self.dataCodingStrategy = dataCodingStrategy
        self.dateCodingStrategy = dateCodingStrategy
        self.directConnection = directConnection
        self.heartbeatFrequencyMS = heartbeatFrequencyMS
        self.localThresholdMS = localThresholdMS
        self.maxPoolSize = maxPoolSize
        self.minHeartbeatFrequencyMS = nil
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.replicaSet = replicaSet
        self.retryWrites = retryWrites
        self.retryReads = retryReads
        self.serverAPI = serverAPI
        self.serverSelectionTimeoutMS = serverSelectionTimeoutMS
        self.threadPoolSize = threadPoolSize
        self.tls = tls
        self.tlsAllowInvalidCertificates = tlsAllowInvalidCertificates
        self.tlsAllowInvalidHostnames = tlsAllowInvalidHostnames
        self.tlsCAFile = tlsCAFile
        self.tlsCertificateKeyFile = tlsCertificateKeyFile
        self.tlsCertificateKeyFilePassword = tlsCertificateKeyFilePassword
        self.tlsInsecure = tlsInsecure
        self.uuidCodingStrategy = uuidCodingStrategy
        self.writeConcern = writeConcern
    }
}

/// Options to use when retrieving a `MongoDatabase` from a `MongoClient`.
public struct MongoDatabaseOptions: CodingStrategyProvider {
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

// sourcery: skipSyncExport
/// A MongoDB Client providing an asynchronous, SwiftNIO-based API.
public class MongoClient {
    /// The pool of connections backing this client.
    internal let connectionPool: ConnectionPool

    /// Executor responsible for executing operations on behalf of this client and its child objects.
    internal let operationExecutor: OperationExecutor

    /// Default size for a client's NIOThreadPool.
    internal static let defaultThreadPoolSize = 5

    /// Default maximum size for connection pools created by this client.
    internal static let defaultMaxConnectionPoolSize = 100

    /// Indicates whether this client has been closed. A lock around this variable is not needed because:
    /// - This value is only modified on success of `ConnectionPool.close()`. That method will succeed exactly once.
    /// - This value is only read in `deinit`. That occurs exactly once after the above modification is complete.
    private var wasClosed = false

    /// Handlers for command monitoring events.
    internal var commandEventHandlers: [CommandEventHandler]

    /// Handlers for SDAM monitoring events.
    internal var sdamEventHandlers: [SDAMEventHandler]

    /// Counter for generating client _ids.
    internal static var clientIDGenerator = NIOAtomic<Int>.makeAtomic(value: 0)

    /// A unique identifier for this client. Sets _id to the generator's current value and increments the generator.
    internal let _id = clientIDGenerator.add(1)

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
     * and the MongoClientOptions struct, the final value is set in descending order of priority: the value specified in
     * MongoClientOptions (if non-nil), the value specified in the URI, or the default value if both are unset.
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to.
     *   - eventLoopGroup: A SwiftNIO `EventLoopGroup` which the client will use for executing operations. It is the
     *                     user's responsibility to ensure the group remains active for as long as the client does, and
     *                     to ensure the group is properly shut down when it is no longer in use.
     *   - options: optional `MongoClientOptions` to use for this client
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
     *
     * - Throws:
     *   - A `MongoError.InvalidArgumentError` if the connection string passed in is improperly formatted.
     */
    public init(
        _ connectionString: String = "mongodb://localhost:27017",
        using eventLoopGroup: EventLoopGroup,
        options: MongoClientOptions? = nil
    ) throws {
        // Initialize mongoc. Repeated calls have no effect so this is safe to do every time.
        initializeMongoc()

        let connString = try ConnectionString(connectionString, options: options)
        self.operationExecutor = OperationExecutor(
            eventLoopGroup: eventLoopGroup,
            threadPoolSize: options?.threadPoolSize ?? MongoClient.defaultThreadPoolSize
        )
        self.connectionPool = try ConnectionPool(
            from: connString,
            executor: self.operationExecutor,
            serverAPI: options?.serverAPI
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
        self.sdamEventHandlers = []
        self.commandEventHandlers = []
        self.connectionPool.initializeMonitoring(client: self)
    }

    deinit {
        assert(
            self.wasClosed,
            "MongoClient was not closed before deinitialization. " +
                "Please call `close()` or `syncClose()` when the client is no longer needed."
        )
    }

    /**
     * Closes this `MongoClient`, closing all connections to the server and cleaning up internal state.
     *
     * Call this method exactly once when you are finished using the client. You must ensure that all operations using
     * the client have completed before calling this.
     *
     * The returned future will not be fulfilled until all cursors and change streams created from this client have been
     * been killed, and all sessions created from this client have been ended.
     *
     * The returned future must be fulfilled before the `EventLoopGroup` provided to this client's constructor is shut
     * down.
     */
    public func close() -> EventLoopFuture<Void> {
        let closeResult = self.operationExecutor.execute(on: nil) {
            try self.connectionPool.close()
        }
        .flatMap {
            self.operationExecutor.shutdown()
        }
        closeResult.whenComplete { _ in
            self.wasClosed = true
        }

        return closeResult
    }

    /**
     * Shuts this `MongoClient` down in a blocking fashion, closing all connections to the server and cleaning up
     * internal state.
     *
     * Call this method exactly once when you are finished using the client. You must ensure that all operations
     * using the client have completed before calling this. This method will block until all cursors and change streams
     * created from this client have been killed, and all sessions created from this client have been ended.
     *
     * This method must complete before the `EventLoopGroup` provided to this client's constructor is shut down.
     */
    public func syncClose() throws {
        try self.connectionPool.close()
        try self.operationExecutor.syncShutdown()
        self.wasClosed = true
    }

    /// Starts a new `ClientSession` with the provided options. When you are done using this session, you must call
    /// `ClientSession.end()` on it.
    public func startSession(options: ClientSessionOptions? = nil) -> ClientSession {
        ClientSession(client: self, eventLoop: nil, options: options)
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
     *    - `MongoError.LogicError` if this client has already been closed.
     */
    public func withSession<T>(
        options: ClientSessionOptions? = nil,
        _ sessionBody: (ClientSession) throws -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        let promise = self.operationExecutor.makePromise(of: T.self, on: nil)
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
     *   - filter: Optional `BSONDocument` specifying a filter that the listed databases must pass. This filter can be
     *      based on the "name", "sizeOnDisk", "empty", or "shards" fields of the output.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command.
     *
     * - Returns:
     *    An `EventLoopFuture<[DatabaseSpecification]>`. On success, the future contains an array of the specifications
     *    of databases matching the provided criteria.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this client has already been closed.
     *    - `EncodingError` if an error is encountered while encoding the options to BSON.
     *    - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *      permissions.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/listDatabases/
     */
    public func listDatabases(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[DatabaseSpecification]> {
        let operation = ListDatabasesOperation(client: self, filter: filter, nameOnly: nil, options: options)
        return self.operationExecutor.execute(
            operation,
            client: self,
            on: nil,
            session: session
        ).flatMapThrowing { result in
            guard case let .specs(dbs) = result else {
                throw MongoError.InternalError(message: "Invalid result")
            }
            return dbs
        }
    }

    /**
     * Get a list of `MongoDatabase`s corresponding to the databases in this client's MongoDB deployment.
     *
     * - Parameters:
     *   - filter: Optional `BSONDocument` specifying a filter on the names of the returned databases.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[MongoDatabase]>`. On success, the future contains an array of `MongoDatabase`s that
     *    match the provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this client has already been closed.
     *    - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *      permissions.
     */
    public func listMongoDatabases(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[MongoDatabase]> {
        self.listDatabaseNames(filter, options: options, session: session).map { $0.map { self.db($0) } }
    }

    /**
     * Get the names of databases in this client's MongoDB deployment.
     *
     * - Parameters:
     *   - filter: Optional `BSONDocument` specifying a filter on the names of the returned databases.
     *   - options: Optional `ListDatabasesOptions` specifying options for listing databases.
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[String]>`. On success, the future contains an array of names of databases that
     *    match the provided filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this client has already been closed.
     *    - `MongoError.CommandError` if options.authorizedDatabases is false and the user does not have listDatabases
     *      permissions.
     */
    public func listDatabaseNames(
        _ filter: BSONDocument? = nil,
        options: ListDatabasesOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[String]> {
        let operation = ListDatabasesOperation(client: self, filter: filter, nameOnly: true, options: options)
        return self.operationExecutor.execute(
            operation,
            client: self,
            on: nil,
            session: session
        ).flatMapThrowing { result in
            guard case let .names(names) = result else {
                throw MongoError.InternalError(message: "Invalid result")
            }
            return names
        }
    }

    /**
     * Gets a `MongoDatabase` instance for the given database name. If an option is not specified in the optional
     * `MongoDatabaseOptions` param, the database will inherit the value from the parent client or the default if
     * the client’s option is not set. To override an option inherited from the client (e.g. a read concern) with the
     * default value, it must be explicitly specified in the options param (e.g. ReadConcern.serverDefault, not nil).
     *
     * - Parameters:
     *   - name: the name of the database to retrieve
     *   - options: Optional `MongoDatabaseOptions` to use for the retrieved database
     *
     * - Returns: a `MongoDatabase` corresponding to the provided database name.
     */
    public func db(_ name: String, options: MongoDatabaseOptions? = nil) -> MongoDatabase {
        MongoDatabase(name: name, client: self, eventLoop: nil, options: options)
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
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    deployment.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *    - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *      pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch(
        _ pipeline: [BSONDocument] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<ChangeStream<ChangeStreamEvent<BSONDocument>>> {
        self.watch(pipeline, options: options, session: session, withFullDocumentType: BSONDocument.self)
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
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    deployment.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *    - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *      pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<FullDocType: Codable>(
        _ pipeline: [BSONDocument] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withFullDocumentType _: FullDocType.Type
    ) -> EventLoopFuture<ChangeStream<ChangeStreamEvent<FullDocType>>> {
        self.watch(
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
     * - Warning:
     *    If the returned change stream is alive when it goes out of scope, it will leak resources. To ensure the
     *    change stream is dead before it leaves scope, invoke `ChangeStream.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<ChangeStream>`. On success, contains a `ChangeStream` watching all collections in this
     *    deployment.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs on the server while creating the change stream.
     *    - `MongoError.InvalidArgumentError` if the options passed formed an invalid combination.
     *    - `MongoError.InvalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *      pipeline.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     *
     * - Note: Supported in MongoDB version 4.0+ only.
     */
    public func watch<EventType: Codable>(
        _ pipeline: [BSONDocument] = [],
        options: ChangeStreamOptions? = nil,
        session: ClientSession? = nil,
        withEventType _: EventType.Type
    ) -> EventLoopFuture<ChangeStream<EventType>> {
        let operation = WatchOperation<BSONDocument, EventType>(
            target: .client(self),
            pipeline: pipeline,
            options: options
        )
        return self.operationExecutor.execute(operation, client: self, on: nil, session: session)
    }

    /**
     * Returns an `EventLoopBoundMongoClient`, a wrapper around this `MongoClient` that will return `EventLoopFuture`s
     * on the specified `EventLoop`.
     *
     * - Note: This `MongoClient` must be kept alive in order to use the `EventLoopBoundMongoClient`.
     *
     * - Parameters:
     *   - eventLoop: An `EventLoop` which the returned `EventLoopBoundMongoClient` will be bound to.
     *
     * - Returns:
     *    An `EventLoopBoundMongoClient` bound to the specified `EventLoop`.
     */
    public func bound(to eventLoop: EventLoop) -> EventLoopBoundMongoClient {
        EventLoopBoundMongoClient(client: self, eventLoop: eventLoop)
    }

    /**
     * Attach a `CommandEventHandler` that will receive `CommandEvent`s emitted by this client.
     *
     * Note: the client stores a weak reference to this handler, so it must be kept alive separately in order for it
     * to continue to receive events.
     */
    public func addCommandEventHandler<T: CommandEventHandler>(_ handler: T) {
        self.commandEventHandlers.append(WeakEventHandler<T>(referencing: handler))
    }

    /**
     * Attach a callback that will receive `CommandEvent`s emitted by this client.
     *
     * Note: if the provided callback captures this client, it must do so weakly. Otherwise, it will constitute a
     * strong reference cycle and potentially result in memory leaks.
     */
    public func addCommandEventHandler(_ handlerFunc: @escaping (CommandEvent) -> Void) {
        self.commandEventHandlers.append(CallbackEventHandler(handlerFunc))
    }

    /**
     * Attach an `SDAMEventHandler` that will receive `CommandEvent`s emitted by this client.
     *
     * Note: the client stores a weak reference to this handler, so it must be kept alive separately in order for it
     * to continue to receive events.
     */
    public func addSDAMEventHandler<T: SDAMEventHandler>(_ handler: T) {
        self.sdamEventHandlers.append(WeakEventHandler(referencing: handler))
    }

    /**
     * Attach a callback that will receive `SDAMEvent`s emitted by this client.
     *
     * Note: if the provided callback captures this client, it must do so weakly. Otherwise, it will constitute a
     * strong reference cycle and potentially result in memory leaks.
     */
    public func addSDAMEventHandler(_ handlerFunc: @escaping (SDAMEvent) -> Void) {
        self.sdamEventHandlers.append(CallbackEventHandler(handlerFunc))
    }

    /// Internal method to check the `ReadConcern` that was ultimately set on this client. **This method may block
    /// and is for testing purposes only**.
    internal func getMongocReadConcern() throws -> ReadConcern? {
        try self.connectionPool.withConnection { conn in
            conn.withMongocConnection { connPtr in
                ReadConcern(copying: mongoc_client_get_read_concern(connPtr))
            }
        }
    }

    /// Internal method to check the `ReadPreference` that was ultimately set on this client. **This method may block
    /// and is for testing purposes only**.
    internal func getMongocReadPreference() throws -> ReadPreference {
        try self.connectionPool.withConnection { conn in
            conn.withMongocConnection { connPtr in
                ReadPreference(copying: mongoc_client_get_read_prefs(connPtr))
            }
        }
    }

    /// Internal method to check the `WriteConcern` that was ultimately set on this client. **This method may block
    /// and is for testing purposes only**.
    internal func getMongocWriteConcern() throws -> WriteConcern? {
        try self.connectionPool.withConnection { conn in
            conn.withMongocConnection { connPtr in
                WriteConcern(copying: mongoc_client_get_write_concern(connPtr))
            }
        }
    }
}

extension MongoClient: Equatable {
    public static func == (lhs: MongoClient, rhs: MongoClient) -> Bool {
        lhs._id == rhs._id
    }
}

/// Event handler constructed from a callback.
/// Stores a strong reference to the provided callback.
private class CallbackEventHandler<EventType> {
    private let handlerFunc: (EventType) -> Void

    fileprivate init(_ handlerFunc: @escaping (EventType) -> Void) {
        self.handlerFunc = handlerFunc
    }
}

/// Extension to make `CallbackEventHandler` an `SDAMEventHandler` when the event type is an `SDAMEvent`.
extension CallbackEventHandler: SDAMEventHandler where EventType == SDAMEvent {
    fileprivate func handleSDAMEvent(_ event: SDAMEvent) {
        self.handlerFunc(event)
    }
}

/// Extension to make `CallbackEventHandler` a `CommandEventHandler` when the event type is a `CommandEvent`.
extension CallbackEventHandler: CommandEventHandler where EventType == CommandEvent {
    fileprivate func handleCommandEvent(_ event: CommandEvent) {
        self.handlerFunc(event)
    }
}

/// Event handler that stores a weak reference to the underlying handler.
private class WeakEventHandler<T: AnyObject> {
    private weak var handler: T?

    fileprivate init(referencing handler: T) {
        self.handler = handler
    }
}

/// Extension to make `WeakEventHandler` a `CommandEventHandler` when the referenced handler is a `CommandEventHandler`.
extension WeakEventHandler: CommandEventHandler where T: CommandEventHandler {
    fileprivate func handleCommandEvent(_ event: CommandEvent) {
        self.handler?.handleCommandEvent(event)
    }
}

/// Extension to make `WeakEventHandler` an `SDAMEventHandler` when the referenced handler is an `SDAMEventHandler`.
extension WeakEventHandler: SDAMEventHandler where T: SDAMEventHandler {
    fileprivate func handleSDAMEvent(_ event: SDAMEvent) {
        self.handler?.handleSDAMEvent(event)
    }
}
