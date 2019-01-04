import MongoSwift
import Vapor

private struct Kitten: Content {
  var name: String
  var color: String
}

private let app = try Application()
private let router = try app.make(Router.self)
private let client = try MongoClient()
private let collection = try client.db("home").collection("kittens", withType: Kitten.self)

router.get("kittens") { _ -> [Kitten] in
  let docs = try collection.find()
  return Array(docs)
}

try app.run()
