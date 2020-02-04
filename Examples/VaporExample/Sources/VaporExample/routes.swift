import MongoSwift
import Vapor

/// A Codable type that matches the data in our home.kittens collection.
struct Kitten: Content {
    var name: String
    var color: String
}

func routes(_ app: Application) throws {
    /// A collection with type `Kitten`. This allows us to directly retrieve instances of
    /// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
    let collection = app.mongoClient.db("home").collection("kittens", withType: Kitten.self)

    app.get("kittens") { _ -> EventLoopFuture<[Kitten]> in
        collection.find().flatMap { cursor in
            cursor.toArray()
        }
    }
}
