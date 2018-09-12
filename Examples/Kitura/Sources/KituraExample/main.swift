import Kitura
import MongoSwift

struct Kitten: Codable {
  var name: String
  var color: String
}

let client = try MongoClient()
let collection = try client.db("home").collection("kittens", withType: Kitten.self)

let router: Router = {
  let router = Router()

  router.get("kittens") { request, response, next in
    let docs = try collection.find()
    response.send(Array(docs))
  }

  return router
}()

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
