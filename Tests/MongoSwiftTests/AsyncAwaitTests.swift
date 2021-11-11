#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)

import Foundation
@testable import MongoSwift
import Nimble
import NIO
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

#endif
