import MongoSwift
import Vapor

private struct Kitten: Content {
    var name: String
    var color: String
}

private let app = try Application()
private let router = try app.make(Router.self)

router.get("kittens") { _ -> [Kitten] in
    let client = try MongoClient()
    let collection = client.db("home").collection("kittens", withType: Kitten.self)
    let docs = try collection.find()
    return Array(docs)
}

try app.run()
