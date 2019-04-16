import Foundation
import mongoc

/// A MongoDB client pool.
public class MongoClientPool {
    internal var _pool: OpaquePointer?

    /**
     * Create a new client pool of connections to a MongoDB server, for multi-threaded programs.
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to.
     *   - maxPoolSize: optional, sets the maximum number of pooled connections available, default is 100.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
     *
     * - Throws:
     *   - A `UserError.invalidArgumentError` if the connection string passed in is improperly formatted.
     *   - A `UserError.invalidArgumentError` if the connection string specifies the use of TLS but libmongoc was not
     *     built with TLS support.
     */
    public init(_ connectionString: String = "mongodb://localhost:27017", maxPoolSize: UInt32? = 100) throws {
        var error = bson_error_t()

        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw parseMongocError(error)
        }
        defer { mongoc_uri_destroy(uri) }

        self._pool = mongoc_client_pool_new(uri)
        guard self._pool != nil  else {
            throw RuntimeError.internalError(message: "Could not create a pool")
        }

        if let maxPoolSize = maxPoolSize {
            mongoc_client_pool_max_size(self._pool, maxPoolSize)
        }

        guard mongoc_client_pool_set_error_api(self._pool, MONGOC_ERROR_API_VERSION_2) else {
            self.close()
            throw RuntimeError.internalError(message: "Could not configure error handling on the pool")
        }
    }

    /**
     * Pop a client pointer from the client pool.
     * Use `MongoClient(fromPoolPointer: OpaquePointer)` to initialize a MongoClient.
     * When all is done the pointer must be pushed back into the pool.
     * This function blocks and waits for an available pointer.
     */
    public func pop() -> OpaquePointer {
        guard let pool = _pool else {
            fatalError("No client pool configured")
        }

        guard let client = mongoc_client_pool_pop(pool) else {
            fatalError("Could not pop a client from pool")
        }

        return client
    }

    /**
     * Pop a client pointer from the client pool.
     * Use `MongoClient(fromPoolPointer: OpaquePointer)` to initialize a MongoClient.
     * When all is done the pointer must be pushed back into the pool.
     * If there are no available connections this function returns nil directly.
     */
    public func tryPop() -> OpaquePointer? {
        guard let pool = _pool else {
            fatalError("No client pool configured")
        }

        guard let client = mongoc_client_pool_try_pop(pool) else {
            fatalError("Could not pop a client from pool")
        }

        return client
    }

    /**
     * Push a client pointer back into the pool.
     * Call this in a syncronous manner when all database handling is done,
     * don't call it inside `defer`.
     */
    public func push(_ client: OpaquePointer) {
        guard let pool = _pool else {
            return
        }

        mongoc_client_pool_push(pool, client)
    }

    /// Cleans up internal state.
    deinit {
        self.close()
    }

    /**
     * Closes the client pool.
     */
    public func close() {
        guard let pool = self._pool else {
            return
        }

        mongoc_client_pool_destroy(pool)
        self._pool = nil
    }
}
