@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class EventLoopBoundMongoClientTests: MongoSwiftTestCase {
    func testEventLoopBoundDb() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)
            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            expect(db.eventLoop) === expectedEventLoop

            // test the MongoDatabase operations return futures on the expected event loop
            expect(db.collection("test").eventLoop) === expectedEventLoop
            let listCollectionNamesFuture = db.listCollectionNames()
            expect(listCollectionNamesFuture.eventLoop) === expectedEventLoop
            _ = try listCollectionNamesFuture.wait()

            let runCommandFuture = db.runCommand(["insert": "coll", "documents": [["foo": "bar"]]])
            expect(runCommandFuture.eventLoop) === expectedEventLoop
            _ = try runCommandFuture.wait()

            let createCollectionFuture = db.createCollection("test")
            expect(createCollectionFuture.eventLoop) === expectedEventLoop
            // test the returned MongoCollection has the expected event loop
            expect(try createCollectionFuture.wait().eventLoop) === expectedEventLoop

            let listMongoCollectionsFuture = db.listMongoCollections()
            expect(listMongoCollectionsFuture.eventLoop) === expectedEventLoop
            let collections = try listMongoCollectionsFuture.wait()
            // test the returned MongoCollections have the expected event loop
            for coll in collections {
                expect(coll.eventLoop) === expectedEventLoop
            }

            // test aggregate
            let adminDB = elBoundClient.db("admin")
            let aggregateFuture = adminDB.aggregate([["$currentOp": [:]]])
            let aggregateCursor = try aggregateFuture.wait()
            defer { try? aggregateCursor.kill().wait() }
            expect(aggregateFuture.eventLoop) === expectedEventLoop
            expect(aggregateCursor.eventLoop) === expectedEventLoop

            // test listCollections
            let listCollectionsFuture = db.listCollections()
            let listCollectionsCursor = try listCollectionsFuture.wait()
            defer { try? listCollectionsCursor.kill().wait() }
            expect(listCollectionsFuture.eventLoop) === expectedEventLoop
            expect(listCollectionsCursor.eventLoop) === expectedEventLoop
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
            let renamedFuture = coll1.renamed(to: self.getCollectionName(suffix: "2"))
            let coll2 = try renamedFuture.wait()
            expect(renamedFuture.eventLoop) === expectedEventLoop
            expect(coll2.eventLoop) === expectedEventLoop

            // test drop
            let dropCollectionFuture = coll2.drop()
            expect(dropCollectionFuture.eventLoop) === expectedEventLoop
            _ = try dropCollectionFuture.wait()
        }
    }

    func testEventLoopBoundDatabaseChangeStreams() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let testRequirements = TestRequirement(
                minServerVersion: ServerVersion(major: 4, minor: 0, patch: 0),
                acceptableTopologies: [.replicaSet, .sharded]
            )

            let unmetRequirement = try client.getUnmetRequirement(testRequirements)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }

            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }

            let res = db.watch()
            let changeStream = try res.wait()
            defer { try? changeStream.kill().wait() }
            expect(res.eventLoop) === expectedEventLoop
            expect(changeStream.eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionChangeStreams() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let testRequirements = TestRequirement(
                acceptableTopologies: [.replicaSet, .sharded]
            )

            let unmetRequirement = try client.getUnmetRequirement(testRequirements)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }

            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            let res = coll.watch()
            let changeStream = try res.wait()
            defer { try? changeStream.kill().wait() }
            expect(res.eventLoop) === expectedEventLoop
            expect(changeStream.eventLoop) === expectedEventLoop

            // test ChangeStream methods
            expect(changeStream.isAlive().eventLoop) === expectedEventLoop
            expect(changeStream.next().eventLoop) === expectedEventLoop
            expect(changeStream.tryNext().eventLoop) === expectedEventLoop
            expect(changeStream.toArray().eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionReads() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            // test countDocuments
            let countFuture = coll.countDocuments()
            expect(countFuture.eventLoop) === expectedEventLoop
            _ = try countFuture.wait()

            // test estimatedDocumentCount
            let estimatedCountFuture = coll.estimatedDocumentCount()
            expect(estimatedCountFuture.eventLoop) === expectedEventLoop
            _ = try estimatedCountFuture.wait()

            // test distinct
            let distinctFuture = coll.distinct(fieldName: "foo", filter: [:])
            expect(distinctFuture.eventLoop) === expectedEventLoop
            _ = try distinctFuture.wait()

            // test find
            let findFuture = coll.find([:])
            let findCursor = try findFuture.wait()
            defer { try? findCursor.kill().wait() }
            expect(findFuture.eventLoop) === expectedEventLoop
            expect(findCursor.eventLoop) === expectedEventLoop

            // test aggregate
            let aggregateFuture = coll.aggregate([["$project": ["_id": 0]]])
            let aggregateCursor = try aggregateFuture.wait()
            defer { try? aggregateCursor.kill().wait() }
            expect(aggregateFuture.eventLoop) === expectedEventLoop
            expect(aggregateCursor.eventLoop) === expectedEventLoop

            // test MongoCursor methods
            expect(aggregateCursor.isAlive().eventLoop) === expectedEventLoop
            expect(aggregateCursor.next().eventLoop) === expectedEventLoop
            expect(aggregateCursor.tryNext().eventLoop) === expectedEventLoop
            expect(aggregateCursor.toArray().eventLoop) === expectedEventLoop
        }
    }

    func testEventLoopBoundCollectionIndexes() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let expectedEventLoop = elg.next()

        try self.withTestClient(eventLoopGroup: elg) { client in
            let elBoundClient = EventLoopBoundMongoClient(client: client, eventLoop: expectedEventLoop)

            let db = elBoundClient.db(Self.testDatabase)
            defer { try? db.drop().wait() }
            let coll = try db.createCollection(self.getCollectionName(suffix: "1")).wait()

            // test createIndex
            let createIndexFuture = coll.createIndex(IndexModel(keys: ["y": 1]))
            expect(createIndexFuture.eventLoop) === expectedEventLoop
            _ = try createIndexFuture.wait()

            // test createIndexes
            let createIndexesFuture = coll.createIndexes([IndexModel(keys: ["x": 1])])
            expect(createIndexesFuture.eventLoop) === expectedEventLoop
            _ = try createIndexesFuture.wait()

            // test a createIndexes that returns a failed future
            let failedCreateIndexesFuture = coll.createIndexes([])
            expect(failedCreateIndexesFuture.eventLoop) === expectedEventLoop
            expect(try failedCreateIndexesFuture.wait()).to(throwError())

            // test listIndexNames
            let listIndexNamesFuture = coll.listIndexNames()
            expect(listIndexNamesFuture.eventLoop) === expectedEventLoop
            _ = try listIndexNamesFuture.wait()

            // test a dropIndex that returns a failed future
            let dropIndexFuture = coll.dropIndex("*")
            expect(dropIndexFuture.eventLoop) === expectedEventLoop
            expect(try dropIndexFuture.wait()).to(throwError())

            // test dropIndexes
            let dropIndexesFuture = coll.dropIndexes()
            expect(dropIndexesFuture.eventLoop) === expectedEventLoop
            _ = try dropIndexesFuture.wait()

            // test listIndexes
            let listIndexesFuture = coll.listIndexes()
            let cursor = try listIndexesFuture.wait()
            defer { try? cursor.kill().wait() }
            expect(listIndexesFuture.eventLoop) === expectedEventLoop
            expect(cursor.eventLoop) === expectedEventLoop
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

            _ = try coll.insertOne(["x": 1]).wait()
            let res = coll.findOneAndReplace(filter: ["x": 1], replacement: ["x": 2])
            expect(res.eventLoop) === expectedEventLoop
            _ = try res.wait()
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

            let bulkWriteFuture = coll.bulkWrite([WriteModel.insertOne(["y": 1])])
            expect(bulkWriteFuture.eventLoop) === expectedEventLoop
            _ = try bulkWriteFuture.wait()
            // test a bulkWrite that returns a failed future
            let failedBulkWriteFuture = coll.bulkWrite([])
            expect(failedBulkWriteFuture.eventLoop) === expectedEventLoop
            expect(try failedBulkWriteFuture.wait()).to(throwError())
        }
    }
}
