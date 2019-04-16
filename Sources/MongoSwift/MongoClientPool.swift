import Foundation
import mongoc

public class MongoClientPool {
    internal var _pool: OpaquePointer?

    public init(_ connectionString: String = "mongodb://localhost:27017", maxPoolSize: UInt32? = 100) throws {
        var error = bson_error_t()

        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw parseMongocError(error)
        }

        defer { mongoc_uri_destroy(uri) }
        self._pool = mongoc_client_pool_new (uri)

        if let maxPoolSize = maxPoolSize {
            mongoc_client_pool_max_size(self._pool, maxPoolSize)
        }

        guard self._pool != nil  else {
            throw RuntimeError.internalError(message: "Could not create a pool")
        }

        guard mongoc_client_pool_set_error_api(self._pool, MONGOC_ERROR_API_VERSION_2) else {
            self.close()
            throw RuntimeError.internalError(message: "Could not configure error handling on the pool")
        }
    }

    public func pop() -> OpaquePointer {
        guard let pool = _pool else {
            fatalError("No client pool configured")
        }

        guard let client = mongoc_client_pool_pop(pool) else {
            fatalError("Could not pop a client from pool")
        }

        return client
    }

    public func tryPop() -> OpaquePointer? {
        guard let pool = _pool else {
            fatalError("No client pool configured")
        }

        return mongoc_client_pool_try_pop(pool)
    }

    public func push(_ client: OpaquePointer) {
        guard let pool = _pool else {
            return
        }

        mongoc_client_pool_push(pool, client)
    }

    public func client() -> MongoClient {
        guard let pool = self._pool else {
            fatalError("No client pool configured")
        }

        let ptr = pop()

        defer {
            self.push(ptr)
        }

        let client = MongoClient(fromPoolPointer: ptr)
        return client
    }

    public func db(_ name: String) -> MongoDatabase {
        let client = self.client()
        return client.db(name)
    }

    public func collection(_ db: String, name: String) -> MongoCollection<Document> {
        let db = self.db(db)
        return db.collection(name)
    }

    deinit {
        self.close()
    }

    public func close() {
        guard let pool = self._pool else {
            return
        }

        mongoc_client_pool_destroy(pool)
        self._pool = nil
    }
}
