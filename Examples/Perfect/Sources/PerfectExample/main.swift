import Foundation
import MongoSwift
import PerfectHTTP
import PerfectHTTPServer

/// A Codable type that matches the data in our home.kittens collection.
private struct Kitten: Codable {
    var name: String
    var color: String
}

/// A single collection with type `Kitten`. This allows us to directly retrieve instances of
/// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
private let collection = try MongoClient().db("home").collection("kittens", withType: Kitten.self)

private var routes = Routes()
routes.add(method: .get, uri: "/kittens") { _, response in
    response.setHeader(.contentType, value: "application/json")
    do {
        let kittens = try collection.find()
        let json = try JSONEncoder().encode(Array(kittens))
        response.setBody(bytes: Array(json))
    } catch {
        print("error: \(error)")
    }
    response.completed()
}

try HTTPServer.launch(name: "localhost", port: 8080, routes: routes)
