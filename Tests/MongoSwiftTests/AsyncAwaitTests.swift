#if compiler(>=5.5.2) && canImport(_Concurrency) && os(Linux)
// TODO: SWIFT-1421 remove this comment and the os(Linux) check above. if the described bug is not fixed, we'll need to
// adjust our macOS < 12 testing to skip these tests by providing a filter to `swift test`.
// we shouldn't have to check the operating system here, but there is a bug currently where on older macOS versions
// the @available checks don't work. since we don't have support for macOS 12+ in CI, we can work around this by just
// only defining the tests on Linux for now.

import Foundation
@testable import MongoSwift
import Nimble
import NIO
import NIOConcurrencyHelpers
import TestsCommon
import XCTest

@available(macOS 10.15.0, *)
final class AsyncAwaitTests: MongoSwiftTestCase {
    func testMongoClient() throws {
        testAsync {
            let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let client = try MongoClient.makeTestClient(eventLoopGroup: elg)
            let databases = try await client.listDatabases()
            expect(databases).toNot(beEmpty())
            // We don't use `withTestClient` here so we can explicity test the `async` version of `close()``.
            try await client.close()
        }
    }

    func testClientSession() throws {
        testAsync {
            try await self.withTestClient { client in
                let dbs = try await client.withSession { session -> [DatabaseSpecification] in
                    try await client.listDatabases(session: session)
                }
                expect(dbs).toNot(beEmpty())

                // the session's connection should be back in the pool.
                try await assertIsEventuallyTrue(
                    description: "Session's underlying connection should be returned to the pool"
                ) {
                    client.connectionPool.checkedOutConnections == 0
                }

                // test session is cleaned up even if closure throws an error.
                try? await client.withSession { session in
                    _ = try await client.listDatabases(session: session)
                    throw TestError(message: "intentional error thrown from withSession closure")
                }
                try await assertIsEventuallyTrue(
                    description: "Session's underlying connection should be returned to the pool"
                ) {
                    client.connectionPool.checkedOutConnections == 0
                }
            }
        }
    }

    func testTransactions() throws {
        testAsync {
            try await self.withTestNamespace { client, _, coll in
                guard try await client.supportsTransactions() else {
                    printSkipMessage(testName: self.name, reason: "Requires transactions support")
                    return
                }

                // aborted txn
                try await client.withSession { session in
                    try await session.startTransaction()
                    try await coll.insertOne(["_id": 1], session: session)
                    try await session.abortTransaction()

                    let count = try await coll.countDocuments(session: session)
                    expect(count).to(equal(0))

                    let doc = try await coll.findOne(session: session)
                    expect(doc).to(beNil())
                }

                // committed txn
                try await client.withSession { session in
                    try await session.startTransaction()
                    try await coll.insertOne(["_id": 1], session: session)
                    try await session.commitTransaction()

                    let count = try await coll.countDocuments(session: session)
                    expect(count).to(equal(1))

                    let doc = try await coll.findOne(session: session)
                    expect(doc).to(equal(["_id": 1]))
                }
            }
        }
    }

    func testMongoDatabase() throws {
        testAsync {
            try await self.withTestNamespace { _, db, _ in
                try await db.drop()
                _ = try await db.createCollection("foo")
                let collections = try await db.listCollectionNames()
                expect(collections).to(contain("foo"))
            }
        }
    }

    func testMongoCollection() throws {
        testAsync {
            try await self.withTestNamespace { _, _, coll in
                let doc: BSONDocument = ["_id": 1]
                try await coll.insertOne(doc)
                let result = try await coll.findOne()
                expect(result).to(equal(doc))
                let count = try await coll.countDocuments()
                expect(count).to(equal(1))

                try await coll.findOneAndUpdate(filter: doc, update: ["$set": ["x": 2]])
                let result2 = try await coll.findOne()
                expect(result2).to(sortedEqual(["_id": 1, "x": 2]))
            }
        }
    }

    func testConcurrentClientUsage() throws {
        testAsync {
            try await self.withTestNamespace { _, db, _ in
                defer {
                    db.syncDropOrFail()
                }
                try await withThrowingTaskGroup(of: Int.self) { group in
                    for i in 1...20 {
                        group.addTask {
                            let coll = db.collection("concurrent-client-test-\(i)")
                            for j in 1...100 {
                                try await coll.insertOne(["_id": .int32(Int32(j))])
                            }
                            return try await coll.countDocuments()
                        }
                    }

                    for try await result in group {
                        expect(result).to(equal(100))
                    }
                }
            }
        }
    }
}

@available(macOS 10.15.0, *)
final class MongoCursorAsyncAwaitTests: MongoSwiftTestCase {
    func testAsyncSequenceConformance() throws {
        testAsync {
            try await self.withTestNamespace { _, _, coll in
                let docsToInsert: [BSONDocument] = [["_id": 1], ["_id": 2], ["_id": 3]]
                try await coll.insertMany(docsToInsert)

                // iterating via a for loop
                var foundDocs = [BSONDocument]()
                let sortOpts = FindOptions(sort: ["_id": 1])
                for try await doc in try await coll.find(options: sortOpts) {
                    foundDocs.append(doc)
                }
                expect(foundDocs).to(equal(docsToInsert))

                // manual iteration with next()
                let cursor = try await coll.find(options: sortOpts)
                let first = try await cursor.next()
                expect(first).to(equal(docsToInsert[0]))
                let second = try await cursor.next()
                expect(second).to(equal(docsToInsert[1]))
                let third = try await cursor.next()
                expect(third).to(equal(docsToInsert[2]))
                let fourth = try await cursor.next()
                expect(fourth).to(beNil())
                let isAlive = try await cursor.isAlive()
                expect(isAlive).to(beFalse())
            }
        }
    }

    // Test that a tailable cursor that is continually polling the server can be killed by cancelling the parent Task.
    func testTailableCursorHandlesTaskCancellation() throws {
        testAsync {
            let opts = CreateCollectionOptions(capped: true, size: 5)
            try await self.withTestNamespace(collectionOptions: opts) { _, _, coll in
                try await coll.insertMany([["x": 1], ["x": 2], ["x": 3]])

                let group = DispatchGroup()
                group.enter()

                let docCount = NIOAtomic<Int>.makeAtomic(value: 0)

                let cursorTask = Task.detached {
                    do {
                        let cursor = try await coll.find(options: FindOptions(cursorType: .tailable))
                        for try await _ in cursor {
                            _ = docCount.add(1)
                        }
                    } catch {
                        XCTFail("\(error)")
                    }
                    group.leave()
                }

                // Wait until we iterate all of the existing documents in the cursor.
                try await assertIsEventuallyTrue(description: "all documents should be received") {
                    docCount.load() == 3
                }

                // Insert another doc and confirm the document count goes up. This means the loop keeps
                // going, as expected.
                try await coll.insertOne(["x": 4])
                try await assertIsEventuallyTrue(description: "Fourth document should be received") {
                    docCount.load() == 4
                }

                // Cancel the child task, which should break us out of the loop.
                cursorTask.cancel()

                // If the test got to the end, it means we successfully broke out of the loop and left the group.
                group.wait()
            }
        }
    }

    func testCleanupUponDeinitialization() throws {
        testAsync {
            try await self.withTestNamespace { client, _, coll in
                try await coll.insertMany([["_id": 1], ["_id": 2], ["_id": 3]])

                let monitor = client.addCommandMonitor()
                monitor.enable()

                do {
                    let cursor = try await coll.find(options: FindOptions(batchSize: 1))
                    _ = try await cursor.next()
                    expect(client.connectionPool.checkedOutConnections).to(equal(1))
                }

                try await assertIsEventuallyTrue(description: "killCursors command is observed") {
                    !monitor.commandStartedEvents(withNames: ["killCursors"]).isEmpty
                }

                try await assertIsEventuallyTrue(description: "Connection should be returned to pool") {
                    client.connectionPool.checkedOutConnections == 0
                }
            }
        }
    }
}

@available(macOS 10.15.0, *)
final class ChangeStreamAsyncAwaitTests: MongoSwiftTestCase {
    func testIteration() throws {
        testAsync {
            try await self.withTestNamespace { client, _, coll in
                guard try await client.supportsChangeStreamOnCollection() else {
                    printSkipMessage(testName: self.name, reason: "Requires change streams support")
                    return
                }

                let changeStream = try await coll.watch()

                let docsToInsert: [BSONDocument] = [["_id": 1], ["_id": 2], ["_id": 3]]
                for doc in docsToInsert {
                    try await coll.insertOne(doc)
                }

                // manual iteration with next()
                let first = try await changeStream.next()
                expect(first?.fullDocument).to(equal(docsToInsert[0]))
                let second = try await changeStream.next()
                expect(second?.fullDocument).to(equal(docsToInsert[1]))
                let third = try await changeStream.next()
                expect(third?.fullDocument).to(equal(docsToInsert[2]))
                let isAlive = try await changeStream.isAlive()
                expect(isAlive).to(beTrue())
            }
        }
    }

    // Test that a change stream that is continually polling the server can be killed by cancelling the parent Task.
    func testHandlesTaskCancellation() throws {
        testAsync {
            try await self.withTestNamespace { client, _, coll in
                guard try await client.supportsChangeStreamOnCollection() else {
                    printSkipMessage(testName: self.name, reason: "Requires change streams support")
                    return
                }

                let group = DispatchGroup()
                group.enter()

                let eventCount = NIOAtomic<Int>.makeAtomic(value: 0)
                let calledWatch = NIOAtomic<Bool>.makeAtomic(value: false)

                let csTask = Task.detached {
                    do {
                        let changeStream = try await coll.watch()
                        calledWatch.store(true)
                        for try await _ in changeStream {
                            _ = eventCount.add(1)
                        }
                    } catch {
                        XCTFail("\(error)")
                    }
                    group.leave()
                }

                // Wait until the change stream has been opened before we start inserting data.
                try await assertIsEventuallyTrue(description: "change stream should be started") {
                    calledWatch.load()
                }

                for doc: BSONDocument in [["_id": 1], ["_id": 2], ["_id": 3]] {
                    try await coll.insertOne(doc)
                }

                // Wait until we iterate all of the existing events in the change stream.
                try await assertIsEventuallyTrue(description: "all events should be received") {
                    eventCount.load() == 3
                }

                // Insert another doc and confirm the event count goes up. This means the loop keeps
                // going, as expected.
                try await coll.insertOne(["_id": 4])
                try await assertIsEventuallyTrue(description: "Fourth event should be received") {
                    eventCount.load() == 4
                }

                // Cancel the child task, which should break us out of the loop.
                csTask.cancel()

                // If the test got to the end, it means we successfully broke out of the loop and left the group.
                group.wait()
            }
        }
    }

    func testCleanupUponDeinitialization() throws {
        testAsync {
            try await self.withTestNamespace { client, _, coll in
                guard try await client.supportsChangeStreamOnCollection() else {
                    printSkipMessage(testName: self.name, reason: "Requires change streams support")
                    return
                }

                let monitor = client.addCommandMonitor()
                monitor.enable()

                do {
                    let cs = try await coll.watch()
                    try await coll.insertOne(["x": 1])
                    _ = try await cs.next()
                    expect(client.connectionPool.checkedOutConnections).to(equal(1))
                }

                try await assertIsEventuallyTrue(description: "killCursors command is observed") {
                    !monitor.commandStartedEvents(withNames: ["killCursors"]).isEmpty
                }

                try await assertIsEventuallyTrue(description: "Connection should be returned to pool") {
                    client.connectionPool.checkedOutConnections == 0
                }
            }
        }
    }
}
#endif
