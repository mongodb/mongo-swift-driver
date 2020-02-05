import Foundation
@testable import MongoSwift
import NIO
import PerfectHTTP
import PerfectHTTPServer

/// A Codable type that matches the data in our home.kittens collection.
struct Kitten: Codable {
    var name: String
    var color: String
}

let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let mongoClient = try MongoClient(using: elg)

/// A single collection with type `Kitten`. This allows us to directly retrieve instances of
/// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
let collection = mongoClient.db("home").collection("kittens", withType: Kitten.self)

private var routes = Routes()
routes.add(method: .get, uri: "/kittens") { _, response in
    collection.find().flatMap { cursor in
        cursor.all()
    }.flatMapThrowing { results in
        response.setHeader(.contentType, value: "application/json")
        let json = try JSONEncoder().encode(results)
        response.setBody(bytes: Array(json))
        response.completed()
    }.whenFailure { error in
        response.setBody(string: "Error: \(error)")
        response.completed()
    }
}

try HTTPServer.launch(name: "localhost", port: 8080, routes: routes)
