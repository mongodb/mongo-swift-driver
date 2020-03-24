@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class MongoClientTests: MongoSwiftTestCase {
    func testUsingClosedClient() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient(using: elg)
        client.syncShutdown()
        expect(try client.listDatabases().wait()).to(throwError(MongoClient.ClosedClientError))
    }

    func testConnectionPoolSize() throws {
        guard !MongoSwiftTestCase.is32Bit else {
            return
        }

        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }

        let invalidSizes = [-1, 0, Int(UInt32.max) + 1]

        for value in invalidSizes {
            let opts = ClientOptions(connectionPoolOptions: ConnectionPoolOptions(maxPoolSize: value))
            expect(try MongoClient(using: elg, options: opts)).to(throwError(errorType: InvalidArgumentError.self))
        }

        // verify size 100 is used by default
        let client1 = try MongoClient(using: elg)
        defer { client1.syncShutdown() }

        var conns: [Connection]? = try (1...100)
            .map { _ in try client1.connectionPool.tryCheckOut() }
            .compactMap { $0 }
        expect(conns?.count).to(equal(100))
        // we should now be holding all connections
        expect(try client1.connectionPool.tryCheckOut()).to(beNil())

        // release connections
        conns = nil

        // try using a custom size
        let opts = ClientOptions(connectionPoolOptions: ConnectionPoolOptions(maxPoolSize: 10))
        let client2 = try MongoClient(using: elg, options: opts)
        defer { client2.syncShutdown() }
        conns = try (1...10)
            .map { _ in try client2.connectionPool.tryCheckOut() }
            .compactMap { $0 }
        expect(conns?.count).to(equal(10))
        // we should now be holding all connections
        expect(try client2.connectionPool.tryCheckOut()).to(beNil())

        // release connections
        conns = nil
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

    // tests that when no connections are available operations won't block the thread pool.
    func testResubmittingToThreadPool() throws {
        try self.withTestNamespace { _, _, coll in
            let docs: [Document] = (1...10).map { ["x": .int32($0)] }
            _ = try coll.insertMany(docs).wait()

            let cursors = try (1...100).map { _ in try coll.find().wait() }

            // queue up more operations
            let waitingOperations = (1...MongoClient.defaultThreadPoolSize).map { _ in coll.countDocuments() }
            // cursors can still make progress even though operations are waiting
            _ = try cursors.map { try $0.toArray().wait() }
            // waiting operations can eventually finish too
            _ = try waitingOperations.map { try $0.wait() }
        }
    }
}
