import MongoSwift
import Vapor

/// A Codable type that matches the data in our home.kittens collection.
private struct Kitten: Content {
    var name: String
    var color: String
}

/// A single collection with type `Kitten`. This allows us to directly retrieve instances of
/// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
private let collection = try MongoClient().db("home").collection("kittens", withType: Kitten.self)

private let app = try Application()
private let router = try app.make(Router.self)

router.get("kittens") { _ -> [Kitten] in
    let docs = try collection.find()
    return Array(docs)
}

try app.run()
