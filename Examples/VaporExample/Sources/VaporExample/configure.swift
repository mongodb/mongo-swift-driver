import MongoSwift
import Vapor

extension Application {
    /// A global `MongoClient` for use throughout the application.
    var mongoClient: MongoClient {
        get {
            return self.storage[MongoClientKey.self]!
        }
        set {
            self.storage[MongoClientKey.self] = newValue
        }
    }

    private struct MongoClientKey: StorageKey {
        typealias Value = MongoClient
    }
}

func configure(_ app: Application) throws {
    // Initialize a client using the application's EventLoopGroup.
    let client = try MongoClient(using: app.eventLoopGroup)
    app.mongoClient = client
    try routes(app)
}
