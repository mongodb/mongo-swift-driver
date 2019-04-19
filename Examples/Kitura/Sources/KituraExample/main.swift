import Kitura
import MongoSwift

private struct Kitten: Codable {
    var name: String
    var color: String
}

private let router: Router = {
    let router = Router()

    router.get("kittens") { _, response, _ in
        let client = try MongoClient()
        let collection = client.db("home").collection("kittens", withType: Kitten.self)
        let docs = try collection.find()
        response.send(Array(docs))
    }

    return router
}()

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
