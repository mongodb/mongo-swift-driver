import mongoc

/// A connection to the database.
internal struct Connection {
    /// Pointer to the underlying `mongoc_client_t`.
    internal let clientHandle: OpaquePointer

    internal init(_ clientHandle: OpaquePointer) {
        self.clientHandle = clientHandle
    }
}

/// A pool of one or more connections.
internal class ConnectionPool {
    /// Represents the state of a `ConnectionPool`.
    internal enum State {
        /// Indicates that the `ConnectionPool` is open and using the associated pointer to a `mongoc_client_pool_t`.
        case open(pool: OpaquePointer)
        /// Indicates that the `ConnectionPool` has been closed and contains no connections.
        case closed
    }

    /// The state of this `ConnectionPool`.
    internal private(set) var state: State

    /// Initializes the pool using the provided `ConnectionString`.
    internal init(from connString: ConnectionString, options: TLSOptions? = nil) throws {
        guard let pool = mongoc_client_pool_new(connString._uri) else {
            throw UserError.invalidArgumentError(message: "libmongoc not built with TLS support")
        }

        guard mongoc_client_pool_set_error_api(pool, MONGOC_ERROR_API_VERSION_2) else {
            throw RuntimeError.internalError(message: "Could not configure error handling on client pool")
        }

        self.state = .open(pool: pool)
        if let options = options {
            try self.setTLSOptions(options)
        }
    }

    /// Closes the pool if it has not been manually closed already.
    deinit {
        self.close()
    }

    /// Closes the pool, cleaning up underlying resources.
    internal func close() {
        switch self.state {
        case let .open(pool):
            mongoc_client_pool_destroy(pool)
        case .closed:
            return
        }
        self.state = .closed
    }

    /// Checks out a connection. This connection must be returned to the pool via `checkIn`.
    internal func checkOut() throws -> Connection {
        switch self.state {
        case let .open(pool):
            return Connection(mongoc_client_pool_pop(pool))
        case .closed:
            throw RuntimeError.internalError(message: "ConnectionPool was already closed")
        }
    }

    /// Returns a connection to the pool.
    internal func checkIn(_ connection: Connection) {
        switch self.state {
        case let .open(pool):
            mongoc_client_pool_push(pool, connection.clientHandle)
        case .closed:
            fatalError("ConnectionPool was already closed")
        }
    }

    /// Executes the given closure using a connection from the pool.
    internal func withConnection<T>(body: (Connection) throws -> T) throws -> T {
        let connection = try self.checkOut()
        defer { self.checkIn(connection) }
        return try body(connection)
    }

    // Sets TLS/SSL options that the user passes in through the client level. This must be called from
    // the ConnectionPool init before the pool is used.
    private func setTLSOptions(_ options: TLSOptions) throws {
        let pemFileStr = options.pemFile?.absoluteString.asCString
        let pemPassStr = options.pemPassword?.asCString
        let caFileStr = options.caFile?.absoluteString.asCString
        defer {
            pemFileStr?.deallocate()
            pemPassStr?.deallocate()
            caFileStr?.deallocate()
        }

        var opts = mongoc_ssl_opt_t()
        if let pemFileStr = pemFileStr {
            opts.pem_file = pemFileStr
        }
        if let pemPassStr = pemPassStr {
            opts.pem_pwd = pemPassStr
        }
        if let caFileStr = caFileStr {
            opts.ca_file = caFileStr
        }
        if let weakCert = options.weakCertValidation {
            opts.weak_cert_validation = weakCert
        }
        if let invalidHosts = options.allowInvalidHostnames {
            opts.allow_invalid_hostname = invalidHosts
        }
        switch self.state {
        case let .open(pool):
            mongoc_client_pool_set_ssl_opts(pool, &opts)
        case .closed:
            throw RuntimeError.internalError(message: "ConnectionPool was already closed")
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
