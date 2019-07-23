import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class ChangeStreamTest: MongoSwiftTestCase {
    func testChangeStream() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let client = try MongoClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))
        let session = try client.startSession()
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let opts = try encodeOptions(options: options, session: session)
        let pipeline: Document = []
        let decoder = BSONDecoder()

        let connection = try client.connectionPool.checkOut()
        try coll.withMongocCollection(from: connection) { collPtr in
            // TODO: Use MongoCollection.watch() instead `mongoc_collection_watch` of once it gets added
            let changeStreamPtr: OpaquePointer = mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
            defer {
                replyPtr.deinitialize(count: 1)
                replyPtr.deallocate()
            }
            expect(try ChangeStream<ChangeStreamDocument<Document>>(stealing: changeStreamPtr,
                                                                    client: client,
                                                                    connection: connection,
                                                                    session: session,
                                                                    decoder: decoder))
                                                                    .toNot(throwError())
        }
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
        let session = try client.startSession()
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let opts = try encodeOptions(options: options, session: session)
        let pipeline: Document = []

        let connection = try client.connectionPool.checkOut()
        try db.withMongocDatabase(from: connection) { dbPtr in
            // TODO: Use MongoDatabase.watch() instead `mongoc_database_watch` of once it gets added
            let changeStreamPtr: OpaquePointer = mongoc_database_watch(dbPtr, pipeline._bson, opts?._bson)
            var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
            defer {
                replyPtr.deinitialize(count: 1)
                replyPtr.deallocate()
            }

            let decoder = BSONDecoder()
            let changeStream = try ChangeStream<ChangeStreamDocument<Document>>(stealing: changeStreamPtr,
                                                                                client: client,
                                                                                connection: connection,
                                                                                decoder: decoder)
            // expect the first iteration to be nil since no changes have been made to the database.
            expect(changeStream.next()).to(beNil())

            let coll = db.collection(self.getCollectionName(suffix: "1"))
            try coll.insertOne(["a": 1], session: session)

            // test that the change stream contains a change document for the `insert` operation.
            let res1 = changeStream.next()
            expect(res1).toNot(beNil())
            expect(res1?.operationType).to(equal(.insert))
            expect(res1?.fullDocument?["a"]).to(bsonEqual(1))

            // test that the resumeToken is updated
            expect(changeStream.resumeToken).to(equal(res1?._id))

            // test that the change stream contains a change document for the `drop` operation.
            try db.drop()
            let res2 = changeStream.next()
            expect(res2).toNot(beNil())
            expect(res2?.operationType).to(equal(.drop))

            // test that the resumeToken is updated
            expect(changeStream.resumeToken).to(equal(res2?._id))
        }
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
        let session = try client.startSession()
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let opts = try encodeOptions(options: options, session: session)
        let pipeline: Document = []

        let connection = try client.connectionPool.checkOut()
        try coll.withMongocCollection(from: connection) { collPtr in
            // TODO: Use MongoCollection.watch() instead `mongoc_collection_watch` of once it gets added
            let changeStreamPtr: OpaquePointer = mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
            defer {
                replyPtr.deinitialize(count: 1)
                replyPtr.deallocate()
            }

            let decoder = BSONDecoder()
            let changeStream = try ChangeStream<ChangeStreamDocument<Document>>(stealing: changeStreamPtr,
                                                                                client: client,
                                                                                connection: connection,
                                                                                session: session,
                                                                                decoder: decoder)
            // expect the first iteration to be nil since no changes have been made to the collection.
            expect(changeStream.next()).to(beNil())

            // test that the change stream contains a change document for the `insert` operation.
            try coll.insertOne(["x": 1], session: session)
            let res1 = changeStream.next()
            expect(res1).toNot(beNil())
            expect(res1?.operationType).to(equal(.insert))
            expect(res1?.fullDocument?["x"]).to(bsonEqual(1))

            // test that the resumeToken is updated
            expect(changeStream.resumeToken).to(equal(res1?._id))

            try coll.updateOne(filter: ["x": 1], update: ["$set": ["x": 2] as Document], session: session)
            let res2 = changeStream.next()

            // test that the change stream contains a change document for the `update` operation.
            expect(res2).toNot(beNil())
            expect(res2?.operationType).to(equal(.update))
            expect(res2?.fullDocument?["x"]).to(bsonEqual(2))

            // test that the resumeToken is updated
            expect(changeStream.resumeToken).to(equal(res2?._id))

            // test that the change stream contains a change document for the `find` operation.
            try coll.findOneAndDelete(["x": 2], session: session)
            let res3 = changeStream.next()
            expect(res3).toNot(beNil())
            expect(res3?.operationType).to(equal(.delete))

            // test that the resumeToken is updated
            expect(changeStream.resumeToken).to(equal(res3?._id))
        }
    }
}
