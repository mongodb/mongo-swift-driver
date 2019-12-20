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
}
