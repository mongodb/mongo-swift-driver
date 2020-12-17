@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class EventLoopBoundMongoClientTests: MongoSwiftTestCase {
    func testEventLoopBoundDb() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            // TODO: SWIFT-1030 - add tests for database operations that return ChangeStream and MongoCursor
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)
            let db = elBoundClient.db(Self.testDatabase)
            expect(db.eventLoop) === expectedEventLoop

            // test the MongoDatabase operations return futures on the expected event loop
            expect(db.collection("test").eventLoop) === expectedEventLoop
            expect(db.listCollectionNames().eventLoop) === expectedEventLoop
            expect(db.runCommand(["insert": "coll", "documents": [["foo": "bar"]]]).eventLoop) === expectedEventLoop

            let res1 = db.createCollection("test")
            expect(res1.eventLoop) === expectedEventLoop
            // test the returned MongoCollection has the expected event loop
            expect(try res1.wait().eventLoop) === expectedEventLoop

            let res2 = db.listMongoCollections()
            expect(res2.eventLoop) === expectedEventLoop
            let collections = try res2.wait()
            // test the returned MongoCollections have the expected event loop
            for coll in collections {
                expect(coll.eventLoop) === expectedEventLoop
            }
        }
    }

    func testEventLoopBoundCollection() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll1 = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            // test renamed
            let res = coll1.renamed(to: self.getCollectionName(suffix: "2"))
            let coll2 = try res.wait()
            expect(res.eventLoop) === expectedEventLoop
            expect(coll2.eventLoop) === expectedEventLoop

            // test drop
            expect(coll2.drop().eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionReads() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            // TODO: SWIFT-1030 - add tests for collection operations that return MongoCursor
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll1 = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            // test countDocuments
            let res1 = coll1.countDocuments()
            expect(res1.eventLoop) === expectedEventLoop

            // test estimatedDocumentCount
            let res2 = coll1.estimatedDocumentCount()
            expect(res2.eventLoop) === expectedEventLoop

            // test distinct
            let res3 = coll1.distinct(fieldName: "foo", filter: [:])
            expect(res3.eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionIndexes() throws {
        // TODO: SWIFT-1030 - add tests for collection operations that return MongoCursor
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            // test createIndex
            expect(coll.createIndex([:]).eventLoop) === expectedEventLoop

            // test createIndexes
            expect(coll.createIndexes([IndexModel(keys: ["x": 1])]).eventLoop) === expectedEventLoop
            // test a createIndexes that returns a failed future
            expect(coll.createIndexes([]).eventLoop) === expectedEventLoop

            // test listIndexNames
            expect(coll.listIndexNames().eventLoop) === expectedEventLoop

            // test a dropIndex that returns a failed future
            expect(coll.dropIndex("*").eventLoop) === expectedEventLoop

            // test dropIndexes
            expect(coll.dropIndexes().eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionFindAndModify() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            coll.insertOne(["x": 1])
            expect(coll.findOneAndReplace(filter: ["x": 1], replacement: ["x": 2]).eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionBulkWrite() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            expect(coll.bulkWrite([WriteModel.insertOne(["y": 1])]).eventLoop) === expectedEventLoop
            // test a bulkWrite that returns a failed future
            expect(coll.bulkWrite([]).eventLoop) === expectedEventLoop
        }
    }
}
