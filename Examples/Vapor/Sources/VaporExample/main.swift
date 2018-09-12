import Vapor
import MongoSwift

struct Kitten: Content {
  var name: String
  var color: String
}

let app = try Application()
let router = try app.make(Router.self)
let client = try MongoClient()
let collection = try client.db("home").collection("kittens", withType: Kitten.self)

router.get("kittens") { req -> [Kitten] in
  let docs = try collection.find()
  return Array(docs)
}

try app.run()

