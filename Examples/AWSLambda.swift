// begin lambda connection example 1
import AWSLambdaRuntime
import Foundation
import MongoSwift
import NIO

let uri = ProcessInfo.processInfo.environment["MONGODB_URI"] ?? "mongodb://localhost:27017"
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(uri, using: elg)

defer {
    // clean up driver resources
    try? client.syncClose()
    cleanupMongoSwift()

    // shut down EventLoopGroup
    try? elg.syncShutdownGracefully()
}

struct Input: Codable {
    let number: Double
}

struct Response: Codable {
    let ok: Int
}

Lambda.run { (_, _: Input, callback: @escaping (Result<Response, Error>) -> Void) in
    let db = client.db("db")
    let result = db.runCommand(["ping": 1]).flatMapThrowing { document in
        try BSONDecoder().decode(Response.self, from: document)
    }
    result.whenSuccess { response in
        callback(.success(response))
    }
    result.whenFailure { error in
        callback(.failure(error))
    }
}

// end lambda connection example 1
