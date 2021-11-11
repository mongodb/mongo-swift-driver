#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)

import Foundation
@testable import MongoSwift
import Nimble
import NIO
import NIOConcurrencyHelpers
import TestsCommon
import XCTest

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
}

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
        let opts = CreateCollectionOptions(capped: true, size: 5)
        try self.withTestNamespace(collectionOptions: opts) { _, _, coll in
            let group = DispatchGroup()
            group.enter()
            Task.detached {
                let docCount = NIOAtomic<Int>.makeAtomic(value: 0)
                try await coll.insertMany([["x": 1], ["x": 2], ["x": 3]])
                let childTask = Task.detached {
                    do {
                        let cursor = try await coll.find(options: FindOptions(cursorType: .tailable))
                        // This loop should block once it gets past the first three documents.
                        for try await _ in cursor {
                            _ = docCount.add(1)
                        }
                    } catch {
                        XCTFail("\(error)")
                    }
                    // We either successfully broke out of the loop, or encountered an error and failed.
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
                childTask.cancel()
            }
            group.wait()
            // If the test got to the end, it means we successfully broke out of the loop and left the group.
        }
    }
}
#endif
