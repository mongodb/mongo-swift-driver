import MongoSwift
import Vapor

/// A Codable type that matches the data in our home.kittens collection.
private struct Kitten: Content {
    var name: String
    var color: String
}

private let app = try Application()
private let router = try app.make(Router.self)

/// A single collection with type `Kitten`. This allows us to directly retrieve instances of
/// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
private let collection = try MongoClient().db("home").collection("kittens", withType: Kitten.self)

router.get("kittens") { _ -> [Kitten] in
    let cursor = try collection.find()
    let results = Array(cursor)
    if let error = cursor.error {
        throw error
    }
    return results
}

try app.run()
