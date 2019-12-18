import Kitura
import MongoSwift

/// A Codable type that matches the data in our home.kittens collection.
private struct Kitten: Codable {
    var name: String
    var color: String
}

/// A single collection with type `Kitten`. This allows us to directly retrieve instances of    
/// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.   
private let collection = try MongoClient().db("home").collection("kittens", withType: Kitten.self)

private let router: Router = {
    let router = Router()

    router.get("kittens") { _, response, _ in
        let cursor = try collection.find()
        let results = Array(cursor)
        if let error = cursor.error {
            throw error
        }
        response.send(results)
    }

    return router
}()

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
