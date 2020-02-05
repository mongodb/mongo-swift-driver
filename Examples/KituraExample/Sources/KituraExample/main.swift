import Kitura
@testable import MongoSwift
import NIO

/// A Codable type that matches the data in our home.kittens collection.
struct Kitten: Codable {
    var name: String
    var color: String
}

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let mongoClient = try MongoClient(using: eventLoopGroup)
defer {
    try? mongoClient.close().wait()
    try? eventLoopGroup.syncShutdownGracefully()
}

let router: Router = {
    let router = Router()

    /// A single collection with type `Kitten`. This allows us to directly retrieve instances of
    /// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
    let collection = mongoClient.db("home").collection("kittens", withType: Kitten.self)

    router.get("kittens") { _, response, next -> Void in
        let res = collection.find().flatMap { cursor in
            cursor.all()
        }

        res.whenSuccess { results in
            response.send(results)
            next()
        }

        res.whenFailure { error in
            response.error = error
            response.send("Error: \(error)")
            next()
        }
    }

    return router
}()

let server = Kitura.addHTTPServer(onPort: 8080, with: router)
try server.setEventLoopGroup(eventLoopGroup)
Kitura.run()
