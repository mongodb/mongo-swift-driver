// begin lambda connection example 1
import AWSLambdaRuntime
import Foundation
import MongoSwift
import NIO

struct Input: Codable {
    let number: Double
}

struct Response: Codable {
    let ok: Double
}

@main
final class MongoHandler: LambdaHandler {
    typealias Event = Input
    typealias Output = Response

    let elg: EventLoopGroup
    let mongoClient: MongoClient

    required init(context _: LambdaInitializationContext) async throws {
        let uri = ProcessInfo.processInfo.environment["MONGODB_URI"] ?? "mongodb://localhost:27017"
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        self.mongoClient = try MongoClient(uri, using: self.elg)
    }

    deinit {
        // clean up driver resources
        try? mongoClient.syncClose()
        cleanupMongoSwift()

        // shut down EventLoopGroup
        try? elg.syncShutdownGracefully()
    }

    func handle(_: Event, context _: LambdaContext) async throws -> Output {
        let db = self.mongoClient.db("db")
        let response = try await db.runCommand(["ping": 1])
        return try BSONDecoder().decode(Output.self, from: response)
    }
}
// end lambda connection example 1
