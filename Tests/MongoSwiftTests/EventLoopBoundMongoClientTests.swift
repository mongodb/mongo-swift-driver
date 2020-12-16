@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class EventLoopBoundMongoClientTests: MongoSwiftTestCase {
    func testEventLoopBoundDb() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)
            expect(elBoundClient.db(Self.testDatabase).eventLoop) === expectedEventLoop
        }
    }

    func testCollection() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            expect(db.collection("test").eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollection() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll1 = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            // test renamed
            let res1 = coll1.renamed(to: self.getCollectionName(suffix: "2"))
            let coll2 = try res1.wait()
            expect(res1.eventLoop) === expectedEventLoop
            expect(coll2.eventLoop) === expectedEventLoop

            // test drop
            let res2 = coll2.drop()
            expect(res2.eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionReads() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient { client in
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
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient { client in
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

        try self.withTestClient { client in
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

        try self.withTestClient { client in
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
