import Leaf
import MongoSwift
import Vapor

extension Application {
    /// A global `MongoClient` for use throughout the application. The client is thread-safe
    /// and backed by a pool of connections so it should be shared across event loops.
    public var mongoClient: MongoClient {
        get {
            self.storage[MongoClientKey.self]!
        }
        set {
            self.storage[MongoClientKey.self] = newValue
        }
    }

    private struct MongoClientKey: StorageKey {
        typealias Value = MongoClient
    }
}

/// Configures the application.
public func configure(_ app: Application) throws {
    // serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Initialize a client using the application's `EventLoopGroup`.
    let client = try MongoClient("mongodb://localhost:27017", using: app.eventLoopGroup)
    app.mongoClient = client

    // Use LeafRenderer for views.
    app.views.use(.leaf)

    // register routes
    try routes(app)
}
