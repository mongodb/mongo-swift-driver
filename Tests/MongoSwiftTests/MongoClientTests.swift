@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class MongoClientTests: MongoSwiftTestCase {
    func testUsingClosedClient() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrLogError() }
        let client = try MongoClient(using: elg)
        try client.close().wait()
        expect(try client.listDatabases().wait()).to(throwError(MongoClient.ClosedClientError))
    }

    func testListDatabases() throws {
        try self.withTestClient { client in
            let dbs = try client.listDatabases().wait()
            expect(dbs.count).to(beGreaterThan(0))

            let dbNames = try client.listDatabaseNames().wait()
            expect(dbNames.count).to(beGreaterThan(0))

            let dbObjects = try client.listMongoDatabases().wait()
            expect(dbObjects.count).to(beGreaterThan(0))
        }
    }

    func testClientIdGeneration() throws {
        let ids = try (0...2).map { _ in
            try self.withTestClient { $0._id }
        }
        expect(ids.sorted()).to(equal(ids))
        expect(ids[1]).to(equal(ids[0] + 1))
        expect(ids[2]).to(equal(ids[1] + 1))
    }
}
