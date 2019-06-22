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
    /// Represents the mode of a `ConnectionPool`.
    private enum Mode {
        /// Indicates that we are in single-client mode using the associated pointer to a `mongoc_client_t`.
        case single(client: OpaquePointer)
        /// Indicates that we are in pooled mode using the associated pointer to a `mongoc_client_pool_t`.
        case pooled(pool: OpaquePointer)
        /// Indicates that the `ConnectionPool` has been closed and contains no connections.
        case none
    }

    /// The mode of this `ConnectionPool`.
    private var mode: Mode

    /// Initializes the pool in single mode using the provided pointer to a `mongoc_client_t`.
    internal init(stealing pointer: OpaquePointer) {
        self.mode = .single(client: pointer)

        // This call may fail, and if it does, either the error api version was already set or the client was derived
        // from a pool. In either case, the error handling in MongoSwift will be incorrect unless the correct api
        // version was set by the caller.
        mongoc_client_set_error_api(pointer, MONGOC_ERROR_API_VERSION_2)
    }

    /// Initializes the pool in pooled mode using the provided `ConnectionString`.
    internal init(from connString: ConnectionString) throws {
        // TODO SWIFT-374: this initializer should actually create a `mongoc_client_pool_t` and do appropriate setup
        // on that.
        guard let clientHandle = mongoc_client_new_from_uri(connString._uri) else {
            throw UserError.invalidArgumentError(message: "libmongoc not built with TLS support")
        }

        guard mongoc_client_set_error_api(clientHandle, MONGOC_ERROR_API_VERSION_2) else {
            throw RuntimeError.internalError(message: "Could not configure error handling on client")
        }

        self.mode = .single(client: clientHandle)
    }

    /// Closes the pool if it has not been manually closed already.
    deinit {
        self.close()
    }

    /// Closes the pool, cleaning up underlying resources.
    internal func close() {
        switch self.mode {
        case let .single(clientHandle):
            mongoc_client_destroy(clientHandle)
        case .pooled:
            fatalError("Pooled mode is not yet implemented")
        case .none:
            return
        }
        self.mode = .none
    }

    /// Checks out a connection. This connection must be returned to the pool via `checkIn`.
    internal func checkOut() throws -> Connection {
        switch self.mode {
        case let .single(clientHandle):
            return Connection(clientHandle)
        case .pooled:
            fatalError("Pooled mode is not yet implemented")
        case .none:
            throw RuntimeError.internalError(message: "ConnectionPool was already closed")
        }
    }

    /// Returns a connection to the pool.
    internal func checkIn(_ connection: Connection) {
        switch self.mode {
        case .single:
            return
        case .pooled:
            fatalError("Pooled mode is not yet implemented")
        case .none:
            fatalError("ConnectionPool was already closed")
        }
    }

    /// Executes the given closure using a connection from the pool.
    internal func withConnection<T>(body: (Connection) throws -> T) throws -> T {
        let connection = try self.checkOut()
        defer { self.checkIn(connection) }
        return try body(connection)
    }

    /// Sets APM callbacks to be used for all connections in the pool.
    internal func setAPMCallbacks(client: MongoClient, callbacks: OpaquePointer) {
        switch self.mode {
        case let .single(clientHandle):
            // we can pass the MongoClient as unretained because the callbacks are stored on clientHandle, so if the
            // callback is being executed, this pool and therefore its parent `MongoClient` must still be valid.
            mongoc_client_set_apm_callbacks(clientHandle, callbacks, Unmanaged.passUnretained(client).toOpaque())
        case .pooled:
            fatalError("Pooled mode is not yet implemented")
        case .none:
            fatalError("ConnectionPool was already closed")
        }
    }
}
