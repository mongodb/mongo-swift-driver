@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class MongoClientTests: MongoSwiftTestCase {
    func testUsingClosedClient() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient(using: elg)
        try client.syncClose()
        expect(try client.listDatabases().wait()).to(throwError(errorType: ChannelError.self))
    }

    func verifyPoolSize(_ client: MongoClient, size: Int) throws {
        let conns = try (1...size)
            .map { _ in try client.connectionPool.tryCheckOut() }
            .compactMap { $0 }
        expect(conns.count).to(equal(size))
        // we should now be holding all connections
        expect(try client.connectionPool.tryCheckOut()).to(beNil())
    }

    func testConnectionPoolSize() throws {
        guard !MongoSwiftTestCase.is32Bit else {
            return
        }

        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }

        let invalidSizes = [-1, 0, Int(UInt32.max) + 1]

        for value in invalidSizes {
            let opts = MongoClientOptions(maxPoolSize: value)
            expect(try MongoClient(using: elg, options: opts)).to(throwError(errorType: InvalidArgumentError.self))
        }

        // verify size 100 is used by default
        try self.withTestClient { client in
            try verifyPoolSize(client, size: 100)
        }

        // try using a custom size
        let opts = MongoClientOptions(maxPoolSize: 10)
        try self.withTestClient(options: opts) { client in
            try verifyPoolSize(client, size: 10)
        }

        // test setting custom size via URI
        let uri = "mongodb://localhost:27017/?maxPoolSize=5"
        try self.withTestClient(uri) { client in
            try verifyPoolSize(client, size: 5)
        }

        // test that options struct value overrides URI value
        try self.withTestClient(uri, options: opts) { client in
            try verifyPoolSize(client, size: 10)
        }
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

    func testConnectionPoolClose() throws {
        let ns = MongoNamespace(db: "connPoolTest", collection: "foo")

        // clean up this test's namespace after we're done
        defer { try? self.withTestNamespace(ns: ns) { _, _, _ in } }

        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg)

        // create a cursor
        let collection = client.db(ns.db).collection(ns.collection!)
        _ = try collection.insertMany([["x": 1], ["x": 2]]).wait()
        let cursor = try collection.find().wait()

        // create a session
        let session = client.startSession()
        // run a command to trigger starting libmongoc session
        _ = try client.listDatabases(session: session).wait()

        // start the client's closing process
        let closeFuture = client.close()

        // the pool should enter the closing state, with 2 connections out
        expect(client.connectionPool.isClosing).toEventually(beTrue())
        expect(client.connectionPool.checkedOutConnections).to(equal(2))

        // calling a method that will request a new connection errors
        expect(try client.listDatabases().wait()).to(throwError(errorType: LogicError.self))

        // cursor can still be used and successfully killed while closing occurs
        expect(try cursor.next().wait()).toNot(throwError())
        try cursor.kill().wait()

        // still in closing state; got connection back from cursor
        expect(client.connectionPool.isClosing).to(beTrue())
        expect(client.connectionPool.checkedOutConnections).to(equal(1))

        // attempting to use session succeeds
        expect(try client.listDatabases(session: session).wait()).toNot(throwError())
        // ending session succeeds
        expect(try session.end().wait()).toNot(throwError())

        // once session releases connection, the pool can close
        expect(client.connectionPool.isClosing).toEventually(beFalse())
        expect(client.connectionPool.checkedOutConnections).to(equal(0))

        // wait to ensure all resource cleanup happens correctly
        try closeFuture.wait()
    }
}
