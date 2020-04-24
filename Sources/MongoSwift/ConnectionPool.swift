import CLibMongoC
import NIOConcurrencyHelpers

/// A connection to the database.
internal class Connection {
    /// Pointer to the underlying `mongoc_client_t`.
    internal let clientHandle: OpaquePointer
    /// The pool this connection belongs to.
    private let pool: ConnectionPool

    internal init(clientHandle: OpaquePointer, pool: ConnectionPool) {
        self.clientHandle = clientHandle
        self.pool = pool
    }

    deinit {
        do {
            try self.pool.checkIn(self)
        } catch {
            assertionFailure("Failed to check connection back in: \(error)")
        }
    }
}

/// A pool of one or more connections.
internal class ConnectionPool {
    /// Represents the state of a `ConnectionPool`.
    internal enum State {
        /// Indicates that the `ConnectionPool` is open and using the associated pointer to a `mongoc_client_pool_t`.
        case open(pool: OpaquePointer)
        /// Indicates that the `ConnectionPool` is in the process of closing. Connections can be checked back in, but
        /// no new connections can be checked out.
        case closing(pool: OpaquePointer)
        /// Indicates that the `ConnectionPool` has been closed and contains no connections.
        case closed
    }

    /// The state of this `ConnectionPool`.
    private var state: State
    /// The number of connections currently checked out of the pool.
    private var connCount = 0
    /// Lock over `state` and `connCount`.
    private let stateLock = Lock()

    /// Internal helper for testing purposes that returns whether the pool is in the `closing` state.
    internal var isClosing: Bool {
        self.stateLock.withLock {
            guard case .closing = self.state else {
                return false
            }
            return true
        }
    }

    /// Internal helper for testing purposes that returns the number of connections currently checked out from the pool.
    internal var checkedOutConnections: Int {
        self.stateLock.withLock {
            self.connCount
        }
    }

    private static let PoolClosedError = LogicError(message: "ConnectionPool was already closed")

    /// Initializes the pool using the provided `ConnectionString` and options.
    internal init(from connString: ConnectionString, options: ClientOptions?) throws {
        guard let pool = mongoc_client_pool_new(connString._uri) else {
            throw InternalError(message: "Failed to initialize libmongoc client pool")
        }

        guard mongoc_client_pool_set_error_api(pool, MONGOC_ERROR_API_VERSION_2) else {
            throw InternalError(message: "Could not configure error handling on client pool")
        }

        if let maxPoolSize = options?.maxPoolSize {
            guard maxPoolSize > 0 && maxPoolSize <= UInt32.max else {
                throw InvalidArgumentError(
                    message: "Invalid maxPoolSize \(maxPoolSize): must be between 1 and \(UInt32.max)"
                )
            }
            mongoc_client_pool_max_size(pool, UInt32(maxPoolSize))
        }

        self.state = .open(pool: pool)
        if let options = options {
            self.setTLSOptions(options)
        }
    }

    deinit {
        guard case .closed = self.state else {
            assertionFailure("ConnectionPool was not closed")
            return
        }
    }

    /// Closes the pool, cleaning up underlying resources. **This method blocks until all connections are returned to
    /// the pool.**
    internal func close() throws {
        try self.stateLock.withLock {
            switch self.state {
            case let .open(pool):
                self.state = .closing(pool: pool)
            case .closing, .closed:
                throw Self.PoolClosedError
            }
        }

        // continually loop and wait to get all connections back before destroying the pool. release the lock on each
        // iteration to allow other methods to acquire the lock.
        var done = false
        while !done {
            try self.stateLock.withLock {
                if self.connCount == 0 {
                    switch self.state {
                    case .open, .closed:
                        throw InternalError(message: "ConnectionPool in unexpected state during close()")
                    case let .closing(pool):
                        mongoc_client_pool_destroy(pool)
                        self.state = .closed
                    }
                    done = true
                }
            }
        }
    }

    /// Checks out a connection. This connection will return itself to the pool when its reference count drops to 0.
    /// This method will block until a connection is available.
    internal func checkOut() throws -> Connection {
        try self.stateLock.withLock {
            switch self.state {
            case let .open(pool):
                self.connCount += 1
                return Connection(clientHandle: mongoc_client_pool_pop(pool), pool: self)
            case .closing, .closed:
                throw Self.PoolClosedError
            }
        }
    }

    /// Checks out a connection from the pool, or returns `nil` if none are currently available.
    internal func tryCheckOut() throws -> Connection? {
        try self.stateLock.withLock {
            switch self.state {
            case let .open(pool):
                guard let handle = mongoc_client_pool_try_pop(pool) else {
                    return nil
                }
                self.connCount += 1
                return Connection(clientHandle: handle, pool: self)
            case .closing, .closed:
                throw Self.PoolClosedError
            }
        }
    }

    fileprivate func checkIn(_ connection: Connection) throws {
        try self.stateLock.withLock {
            switch self.state {
            case let .open(pool), let .closing(pool):
                mongoc_client_pool_push(pool, connection.clientHandle)
                self.connCount -= 1
            case .closed:
                throw Self.PoolClosedError
            }
        }
    }

    /// Executes the given closure using a connection from the pool. This method will block until a connection is
    /// available.
    internal func withConnection<T>(body: (Connection) throws -> T) throws -> T {
        let connection = try self.checkOut()
        return try body(connection)
    }

    // Sets TLS/SSL options that the user passes in through the client level. **This must only be called from
    // the ConnectionPool initializer**.
    private func setTLSOptions(_ options: ClientOptions) {
        // return early so we don't set an empty options struct on the libmongoc pool. doing so will make libmongoc
        // attempt to use TLS for connections.
        guard options.tls == true ||
            options.tlsAllowInvalidCertificates != nil ||
            options.tlsAllowInvalidHostnames != nil ||
            options.tlsCAFile != nil || options.tlsCertificateKeyFile != nil ||
            options.tlsCertificateKeyFilePassword != nil else {
            return
        }

        let keyFileStr = options.tlsCertificateKeyFile?.absoluteString.asCString
        let passStr = options.tlsCertificateKeyFilePassword?.asCString
        let caFileStr = options.tlsCAFile?.absoluteString.asCString
        defer {
            keyFileStr?.deallocate()
            passStr?.deallocate()
            caFileStr?.deallocate()
        }

        var opts = mongoc_ssl_opt_t()
        if let keyFileStr = keyFileStr {
            opts.pem_file = keyFileStr
        }
        if let passStr = passStr {
            opts.pem_pwd = passStr
        }
        if let caFileStr = caFileStr {
            opts.ca_file = caFileStr
        }
        if let weakCert = options.tlsAllowInvalidCertificates {
            opts.weak_cert_validation = weakCert
        }
        if let invalidHosts = options.tlsAllowInvalidHostnames {
            opts.allow_invalid_hostname = invalidHosts
        }

        self.stateLock.withLock {
            switch self.state {
            case let .open(pool):
                mongoc_client_pool_set_ssl_opts(pool, &opts)
            case .closing, .closed:
                // if we get here, we must have called this method outside of `ConnectionPool.init`.
                fatalError("ConnectionPool unexpectedly in .closing or .closed state")
            }
        }
    }

    /// Selects a server according to the specified parameters and returns a description of a suitable server to use.
    /// Throws an error if a server cannot be selected. This method will start up SDAM in libmongoc if it hasn't been
    /// started already. This method may block.
    internal func selectServer(forWrites: Bool, readPreference: ReadPreference? = nil) throws -> ServerDescription {
        try self.withConnection { conn in
            try ReadPreference.withOptionalMongocReadPreference(from: readPreference) { rpPtr in
                var error = bson_error_t()
                guard let desc = mongoc_client_select_server(
                    conn.clientHandle,
                    forWrites,
                    rpPtr,
                    &error
                ) else {
                    throw extractMongoError(error: error)
                }
                defer { mongoc_server_description_destroy(desc) }
                return ServerDescription(desc)
            }
        }
    }

    /// Retrieves the connection string used to create this pool. If SDAM has been started in libmongoc, the getters
    /// on the returned connection string will return any values that were retrieved from TXT records. Throws an error
    /// if the connection string cannot be retrieved.
    internal func getConnectionString() throws -> ConnectionString {
        try self.withConnection { conn in
            guard let uri = mongoc_client_get_uri(conn.clientHandle) else {
                throw InternalError(message: "Couldn't retrieve client's connection string")
            }
            return ConnectionString(copying: uri)
        }
    }

    /// Sets the provided APM callbacks on this pool, using the provided client as the "context" value. **This method
    /// may only be called before any connections are checked out of the pool.**
    internal func setAPMCallbacks(callbacks: OpaquePointer, client: MongoClient) {
        self.stateLock.withLock {
            switch self.state {
            case let .open(pool):
                mongoc_client_pool_set_apm_callbacks(pool, callbacks, Unmanaged.passUnretained(client).toOpaque())
            case .closing, .closed:
                // this method is called via `initializeMonitoring()`, which is called from `MongoClient.init`.
                // unless we have a bug it's impossible that the pool is already closed.
                fatalError("ConnectionPool unexpectedly in .closed state")
            }
        }
    }
}

extension String {
    /// Returns this String as a C string. This pointer *must* be deallocated when
    /// you are done using it. Prefer to use `String.withCString` whenever possible.
    /// taken from: https://gist.github.com/yossan/51019a1af9514831f50bb196b7180107
    fileprivate var asCString: UnsafePointer<Int8> {
        // + 1 for null terminator
        let count = self.utf8.count + 1
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: count)
        self.withCString { baseAddress in
            result.initialize(from: baseAddress, count: count)
        }
        return UnsafePointer(result)
    }
}
