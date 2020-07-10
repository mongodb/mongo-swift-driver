import CLibMongoC
import Foundation
import NIOConcurrencyHelpers

/// A connection to the database.
internal class Connection {
    /// Pointer to the underlying `mongoc_client_t`.
    private let clientHandle: OpaquePointer
    /// The pool this connection belongs to.
    private let pool: ConnectionPool

    internal init(clientHandle: OpaquePointer, pool: ConnectionPool) {
        self.clientHandle = clientHandle
        self.pool = pool
    }

    internal func withMongocConnection<T>(_ body: (OpaquePointer) throws -> T) rethrows -> T {
        try body(self.clientHandle)
    }

    deinit {
        do {
            try self.pool.checkIn(self)
        } catch {
            assertionFailure("Failed to check connection back in: \(error)")
        }
    }
}

extension NSCondition {
    fileprivate func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try body()
    }
}

/// A pool of one or more connections.
internal class ConnectionPool {
    /// Represents the state of a `ConnectionPool`.
    private enum State {
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
    private let stateLock = NSCondition()

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

    internal static let PoolClosedError = MongoError.LogicError(message: "ConnectionPool was already closed")

    /// Initializes the pool using the provided `ConnectionString`.
    internal init(from connString: ConnectionString) throws {
        let pool: OpaquePointer = try connString.withMongocURI { uriPtr in
            guard let pool = mongoc_client_pool_new(uriPtr) else {
                throw MongoError.InternalError(message: "Failed to initialize libmongoc client pool")
            }
            return pool
        }

        self.state = .open(pool: pool)

        guard mongoc_client_pool_set_error_api(pool, MONGOC_ERROR_API_VERSION_2) else {
            fatalError("Could not configure error handling on client pool")
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

            while self.connCount > 0 {
                // wait for signal from checkIn().
                self.stateLock.wait()
            }

            switch self.state {
            case .open, .closed:
                throw MongoError.InternalError(
                    message: "ConnectionPool in unexpected state \(self.state) during close()"
                )
            case let .closing(pool):
                mongoc_client_pool_destroy(pool)
                self.state = .closed
            }
        }
    }

    /// Checks out a connection. This connection will return itself to the pool when its reference count drops to 0.
    /// This method will block until a connection is available. Throws an error if the pool is in the process of
    /// closing or has finished closing.
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

    /// Checks out a connection from the pool, or returns `nil` if none are currently available. Throws an error if the
    /// pool is not open. This method may block waiting on the state lock as well as libmongoc's locks and thus must be
    // run within the thread pool.
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

    /// Checks a connection into the pool. Accepts the connection if the pool is still open or in the process of
    /// closing; throws an error if the pool has already finished closing. This method may block waiting on the state
    /// lock as well as libmongoc's locks, and thus must be run within the thread pool.
    fileprivate func checkIn(_ connection: Connection) throws {
        try self.stateLock.withLock {
            switch self.state {
            case let .open(pool), let .closing(pool):
                connection.withMongocConnection { connPtr in
                    mongoc_client_pool_push(pool, connPtr)
                }

                self.connCount -= 1
                // signal to close() that we are updating the count.
                self.stateLock.signal()
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

    /// Selects a server according to the specified parameters and returns a description of a suitable server to use.
    /// Throws an error if a server cannot be selected. This method will start up SDAM in libmongoc if it hasn't been
    /// started already. This method may block.
    internal func selectServer(forWrites: Bool, readPreference: ReadPreference? = nil) throws -> ServerDescription {
        try self.withConnection { conn in
            try conn.withMongocConnection { connPtr in
                try ReadPreference.withOptionalMongocReadPreference(from: readPreference) { rpPtr in
                    var error = bson_error_t()
                    guard let desc = mongoc_client_select_server(
                        connPtr,
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
    }

    /// Retrieves the connection string used to create this pool. If SDAM has been started in libmongoc, the getters
    /// on the returned connection string will return any values that were retrieved from TXT records. Throws an error
    /// if the connection string cannot be retrieved.
    internal func getConnectionString() throws -> ConnectionString {
        try self.withConnection { connection in
            try connection.withMongocConnection { connPtr in
                guard let uri = mongoc_client_get_uri(connPtr) else {
                    throw MongoError.InternalError(message: "Couldn't retrieve client's connection string")
                }
                return ConnectionString(copying: uri)
            }
        }
    }

    /// Sets the provided APM callbacks on this pool, using the provided client as the "context" value. **This method
    /// may only be called before any connections are checked out of the pool.** Ideally this code would just live in
    /// `ConnectionPool.init`. However, the client we accept here has to be fully initialized before we can pass it
    /// as the context. In order for it to be fully initialized its pool must exist already.
    internal func setAPMCallbacks(callbacks: OpaquePointer, client: MongoClient) {
        // lock isn't needed as this is called before pool is in use.
        switch self.state {
        case let .open(pool):
            mongoc_client_pool_set_apm_callbacks(pool, callbacks, Unmanaged.passUnretained(client).toOpaque())
        case .closing, .closed:
            // this method is called via `initializeMonitoring()`, which is called from `MongoClient.init`.
            // unless we have a bug it's impossible that the pool is already closed.
            fatalError("ConnectionPool in unexpected state \(self.state) while setting APM callbacks")
        }
    }
}
