import MongoSwift
import Vapor

extension Application {
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
    let client = try MongoClient(using: app.eventLoopGroup)
    app.mongoClient = client
    try routes(app)
}
