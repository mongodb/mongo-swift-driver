import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class ChangeStreamTest: MongoSwiftTestCase {
    func testChangeStreamOnAClient() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let client = try MongoClient()
        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 0) else {
            print("Skipping test case for server version \(try client.serverVersion())")
            return
        }

        let changeStream = try client.watch()
        let db1 = client.db("db1")
        defer { try? db1.drop() }
        let coll1 = db1.collection("coll1")
        let coll2 = db1.collection("coll2")
        try coll1.insertOne(["a": 1])
        try coll2.insertOne(["x": 123])

        let res1 = changeStream.next()
        // expect the change stream to contain a change document for the `insert` operation
        expect(res1).toNot(beNil())
        expect(res1?.operationType).to(equal(.insert))
        expect(res1?.fullDocument?["a"]).to(bsonEqual(1))
        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res1?._id))

        let res2 = changeStream.next()
        // expect the change stream to contain a document for changes on a different collection in the same database
        expect(res2).toNot(beNil())
        expect(res2?.operationType).to(equal(.insert))
        expect(res2?.fullDocument?["x"]).to(bsonEqual(123))
        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res2?._id))

        let db2 = client.db("db2")
        defer { try? db1.drop() }
        let coll3 = db2.collection("coll3")
        try coll3.insertOne(["y": 321])
        let res4 = changeStream.next()
        // expect the change stream to contain a document for changes on a collection in a different database
        expect(res4).toNot(beNil())
        expect(res4?.operationType).to(equal(.insert))
        expect(res4?.fullDocument?["y"]).to(bsonEqual(321))
        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res4?._id))
    }

    func testChangeStreamOnADatabase() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let client = try MongoClient()
        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 0) else {
            print("Skipping test case for server version \(try client.serverVersion())")
            return
        }

        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let changeStream = try db.watch()

        // expect the first iteration to be nil since no changes have been made to the database.
        expect(changeStream.next()).to(beNil())

        let coll = db.collection(self.getCollectionName(suffix: "1"))
        try coll.insertOne(["a": 1])

        // test that the change stream contains a change document for the `insert` operation
        let res1 = changeStream.next()
        expect(res1).toNot(beNil())
        expect(res1?.operationType).to(equal(.insert))
        expect(res1?.fullDocument?["a"]).to(bsonEqual(1))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res1?._id))

        // expect the change stream to contain a change document for the `drop` operation
        try db.drop()
        let res2 = changeStream.next()
        expect(res2).toNot(beNil())
        expect(res2?.operationType).to(equal(.drop))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res2?._id))
    }

    func testChangeStreamOnACollection() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let client = try MongoClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let changeStream = try coll.watch(options: options)

        // expect the change stream to contain a change document for the `insert` operation
        try coll.insertOne(["x": 1])
        let res1 = changeStream.next()
        expect(res1).toNot(beNil())
        expect(res1?.operationType).to(equal(.insert))
        expect(res1?.fullDocument?["x"]).to(bsonEqual(1))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res1?._id))

        try coll.updateOne(filter: ["x": 1], update: ["$set": ["x": 2] as Document])
        let res2 = changeStream.next()

        // expect the change stream to contain a change document for the `update` operation
        expect(res2).toNot(beNil())
        expect(res2?.operationType).to(equal(.update))
        expect(res2?.fullDocument?["x"]).to(bsonEqual(2))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res2?._id))

        // expect the change stream contains a change document for the `find` operation
        try coll.findOneAndDelete(["x": 2])
        let res3 = changeStream.next()
        expect(res3).toNot(beNil())
        expect(res3?.operationType).to(equal(.delete))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(res3?._id))
    }

    func testChangeStreamWithPipeline() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let client = try MongoClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let pipeline: [Document] = [["$match": ["fullDocument.a": 1] as Document]]
        let changeStream = try coll.watch(pipeline, options: options)

        try coll.insertOne(["a": 1])
        let res1 = changeStream.next()

        expect(res1).toNot(beNil())
        expect(res1?.operationType).to(equal(.insert))
        expect(res1?.fullDocument?["a"]).to(bsonEqual(1))
        // expect the change stream to not contain a change event for the this insert
        try coll.insertOne(["b": 2])
        let res2 = changeStream.next()
        expect(res2).to(beNil())
    }

    func testChangeStreamResumeTokenError() throws {
         guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let client = try MongoClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let pipeline: [Document] = [["$project": ["_id": 0] as Document]]
        let changeStream = try coll.watch(pipeline, options: options)
        try coll.insertOne(["a": 1])
        expect(try changeStream.nextOrError()).to(throwError(RuntimeError.internalError(message: "")))
    }
}
