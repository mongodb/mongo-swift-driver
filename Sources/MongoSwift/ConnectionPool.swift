import CLibMongoC
import Foundation
import NIO
import NIOConcurrencyHelpers
import SwiftBSON

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
        /// Indicates the `ConnectionPool` is still starting up in the background.
        case opening(future: EventLoopFuture<OpaquePointer>)
        /// Indicates that the `ConnectionPool` is open and using the associated pointer to a `mongoc_client_pool_t`.
        case open(pool: OpaquePointer)
        /// Indicates that the `ConnectionPool` failed to open due to the associated error.
        case failedToOpen(error: Error)
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

    /// Initializes the pool using the provided `MongoConnectionString`.
    internal init(
        from connString: MongoConnectionString,
        executor: OperationExecutor,
        serverAPI: MongoServerAPI?
    ) throws {
        let poolFut = executor.execute(on: nil) { () -> OpaquePointer in
            try connString.withMongocURI { uriPtr in
                var error = bson_error_t()
                // this can fail if e.g. an invalid option is specified via a TXT record.
                guard let pool = mongoc_client_pool_new_with_error(uriPtr, &error) else {
                    throw extractMongoError(error: error)
                }

                do {
                    // this should only fail due to an error of our own, e.g. calling this method multiple times or
                    // passing in an invalid error API version.
                    guard mongoc_client_pool_set_error_api(pool, MONGOC_ERROR_API_VERSION_2) else {
                        throw MongoError.InternalError(message: "Could not configure error handling on client pool")
                    }

                    // We always set min_heartbeat_frequency because the hard-coded default in the vendored mongoc
                    // was lowered to 50. Setting it here brings it to whatever was specified, or 500 if it wasn't.
                    mongoc_client_pool_set_min_heartbeat_frequency_msec(
                        pool,
                        UInt64(connString.minHeartbeatFrequencyMS)
                    )

                    // this should only fail due to an error of our own, e.g. calling this method multiple times or
                    // passing in an invalid API version.
                    try serverAPI?.withMongocServerAPI { apiPtr in
                        guard mongoc_client_pool_set_server_api(pool, apiPtr, &error) else {
                            throw extractMongoError(error: error)
                        }
                    }
                } catch {
                    // manually clean up the pool since we won't return it, which would be necessary for the usual
                    // cleanup logic to execute.
                    mongoc_client_pool_destroy(pool)
                    throw error
                }

                return pool
            }
        }

        self.state = .opening(future: poolFut)
    }

    deinit {
        guard case .closed = self.state else {
            assertionFailure("ConnectionPool was not closed")
            return
        }
    }

    /// Execute the provided closure with the pointer to the created `mongoc_client_pool_t`, potentially waiting
    /// for the pool to finish starting up first. The closure will be executed while the stateLock is held, so
    /// closure MUST NOT attempt to acquire the lock.
    ///
    /// Throws an error if the pool is closed or closing.
    private func withResolvedPool<T>(body: (OpaquePointer) throws -> T) throws -> T {
        try self.stateLock.withLock {
            switch self.state {
            case let .open(pool):
                return try body(pool)
            case let .opening(future):
                do {
                    let pool = try future.wait()
                    self.state = .open(pool: pool)
                    return try body(pool)
                } catch {
                    self.state = .failedToOpen(error: error)
                    throw error
                }
            case let .failedToOpen(error):
                throw error
            case .closed, .closing:
                throw Self.PoolClosedError
            }
        }
    }

    /// Closes the pool, cleaning up underlying resources. **This method blocks until all connections are returned to
    /// the pool.**
    internal func close() throws {
        try self.stateLock.withLock {
            switch self.state {
            case let .open(pool):
                self.state = .closing(pool: pool)
            case let .opening(future):
                do {
                    let pool = try future.wait()
                    self.state = .closing(pool: pool)
                } catch {
                    self.state = .closed
                    return
                }
            case .closing, .closed:
                throw Self.PoolClosedError
            case .failedToOpen:
                self.state = .closed
                return
            }

            while self.connCount > 0 {
                // wait for signal from checkIn().
                self.stateLock.wait()
            }

            switch self.state {
            case .open, .closed, .opening, .failedToOpen:
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
        try self.withResolvedPool { pool in
            self.connCount += 1
            return Connection(clientHandle: mongoc_client_pool_pop(pool), pool: self)
        }
    }

    /// Checks out a connection from the pool, or returns `nil` if none are currently available. Throws an error if the
    /// pool is not open. This method may block waiting on the state lock as well as libmongoc's locks and thus must be
    // run within the thread pool.
    internal func tryCheckOut() throws -> Connection? {
        try self.withResolvedPool { pool in
            guard let handle = mongoc_client_pool_try_pop(pool) else {
                return nil
            }
            self.connCount += 1
            return Connection(clientHandle: handle, pool: self)
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
            case .opening, .failedToOpen:
                fatalError("ConnectionPool in unexpected state \(self.state) while checking in a connection")
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

    /// Retrieves the connection string used to create this pool. Note that options retrieved from TXT records will not
    /// be present in this connection string. To inspect those options, use `getConnectionStringOptions`. Throws an
    /// error if the connection string cannot be retrieved.
    internal func getConnectionString() throws -> MongoConnectionString {
        try self.withConnection { connection in
            try connection.withMongocConnection { connPtr in
                guard let uri = mongoc_client_get_uri(connPtr) else {
                    throw MongoError.InternalError(message: "Couldn't retrieve client's connection string")
                }
                guard let uriString = mongoc_uri_get_string(uri) else {
                    throw MongoError.InternalError(message: "Couldn't retrieve URI string")
                }
                return try MongoConnectionString(string: String(cString: uriString))
            }
        }
    }

    /// Retrieves the options configured on the connection string used to create this pool. If SDAM has been started in
    /// libmongoc, these will include any values that were retrieved from TXT records. Note that these options will not
    /// include `authSource`; to retrieve that value, use `getConnectionStringAuthSource`. Throws an error if the
    /// connection string cannot be retrieved.
    internal func getConnectionStringOptions() throws -> BSONDocument {
        try self.withConnection { connection in
            try connection.withMongocConnection { connPtr in
                guard let uri = mongoc_client_get_uri(connPtr) else {
                    throw MongoError.InternalError(message: "Couldn't retrieve client's connection string")
                }
                guard let options = mongoc_uri_get_options(uri) else {
                    return BSONDocument()
                }
                return BSONDocument(copying: options)
            }
        }
    }

    /// Retrieves the `authSource` configured on the connection string used to create this pool. If SDAM has been
    /// started in libmongoc, this will return the up-to-date value after SRV lookup.
    internal func getConnectionStringAuthSource() throws -> String? {
        try self.withConnection { connection in
            try connection.withMongocConnection { connPtr in
                guard let uri = mongoc_client_get_uri(connPtr) else {
                    throw MongoError.InternalError(message: "Couldn't retrieve client's connection string")
                }
                guard let authSource = mongoc_uri_get_auth_source(uri) else {
                    return nil
                }
                return String(cString: authSource)
            }
        }
    }

    /// Retrieves the `defaultAuthDB` configured on the connection string used to create this pool. If SDAM has been
    /// started in libmongoc, this will return the up-to-date value after SRV lookup.
    internal func getConnectionStringAuthDB() throws -> String? {
        try self.withConnection { connection in
            try connection.withMongocConnection { connPtr in
                guard let uri = mongoc_client_get_uri(connPtr) else {
                    throw MongoError.InternalError(message: "Couldn't retrieve client's connection string")
                }
                guard let authSource = mongoc_uri_get_database(uri) else {
                    return nil
                }
                return String(cString: authSource)
            }
        }
    }

    /// Sets the provided APM callbacks on this pool, using the provided client as the "context" value. **This method
    /// may only be called before any connections are checked out of the pool.** Ideally this code would just live in
    /// `ConnectionPool.init`. However, the client we accept here has to be fully initialized before we can pass it
    /// as the context. In order for it to be fully initialized its pool must exist already.
    ///
    /// This method takes ownership of the provided `mongoc_apm_callbacks_t`, so the pointer MUST NOT be used or freed
    /// after it is passed to this method.
    internal func setAPMCallbacks(callbacks: OpaquePointer, client: MongoClient) {
        // lock isn't needed as this is called before pool is in use.
        guard case let .opening(future) = self.state else {
            // this method is called via `initializeMonitoring()`, which is called from `MongoClient.init`.
            // unless we have a bug it's impossible that the pool is already closed.
            fatalError("ConnectionPool in unexpected state \(self.state) while setting APM callbacks")
        }

        // to ensure the callbacks get set before any waiting on this future becomes unblocked, use
        // `map` to create a new future instead of .whenSuccess
        let newFut = future.map { pool -> OpaquePointer in
            mongoc_client_pool_set_apm_callbacks(pool, callbacks, Unmanaged.passUnretained(client).toOpaque())
            mongoc_apm_callbacks_destroy(callbacks)
            return pool
        }

        // this shouldn't be reached but just in case we still free the memory
        newFut.whenFailure { _ in
            mongoc_apm_callbacks_destroy(callbacks)
        }

        // update the stored future to refer to the one that sets the callbacks
        self.state = .opening(future: newFut)
    }
}
