import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class ChangeStreamTest: MongoSwiftTestCase {
    func testChangeStream() throws {
        let decoder = BSONDecoder()
        let client = try MongoClient()

        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }

        let session = try client.startSession()
        let options = ChangeStreamOptions()
        let opts = try encodeOptions(options: options, session: session)
        let pipeline: Document = []

        let changeStreamPtr: OpaquePointer = mongoc_database_watch(db._database, pipeline._bson, opts?._bson)
        var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            replyPtr.deinitialize(count: 1)
            replyPtr.deallocate()
        }
        expect(try ChangeStream<ChangeStreamDocument<Document>>(stealing: changeStreamPtr,
                                                                client: client,
                                                                session: session,
                                                                decoder: decoder))
                                                                .toNot(throwError())
    }

    func testChangeStreamOnADatabase() throws {
        let client = try MongoClient()

        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }

        let options = ChangeStreamOptions()
        let session = try client.startSession()
        let opts = try encodeOptions(options: options, session: session)
        let pipeline: Document = []

        let changeStreamPtr: OpaquePointer = mongoc_database_watch(db._database, pipeline._bson, opts?._bson)
        var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            replyPtr.deinitialize(count: 1)
            replyPtr.deallocate()
        }

        let decoder = BSONDecoder()
        let changeStream = try ChangeStream<ChangeStreamDocument<Document>>(stealing: changeStreamPtr,
                                                                            client: client,
                                                                            decoder: decoder)
        // expect the first iteration to be nil since no changes have been made to the database.
        expect(changeStream.next()).to(beNil())

        let coll = try db.collection(self.getCollectionName(suffix: "1"))
        try coll.insertOne(["a": 1], session: session)

        // test that the change stream contains a change document for the `insert` operation.
        let res1 = changeStream.next()
        expect(res1).toNot(beNil())
        expect(res1?.operationType).to(equal(.insert))

        // test that the change stream contains a change document for the `drop` operation.
        try db.drop()
        let res2 = changeStream.next()
        expect(res2).toNot(beNil())
        expect(res2?.operationType).to(equal(.drop))
    }

    func testChangeStreamOnACollection() throws {
        let client = try MongoClient()

        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }

        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))
        let session = try client.startSession()
        let options = ChangeStreamOptions()
        let opts = try encodeOptions(options: options, session: session)
        let pipeline: Document = []

        let changeStreamPtr: OpaquePointer = mongoc_collection_watch(coll._collection, pipeline._bson, opts?._bson)
        var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            replyPtr.deinitialize(count: 1)
            replyPtr.deallocate()
        }

        let decoder = BSONDecoder()
       let changeStream = try ChangeStream<ChangeStreamDocument<Document>>(stealing: changeStreamPtr,
                                                                           client: client,
                                                                           session: session,
                                                                           decoder: decoder)
       // expect the first iteration to be nil since no changes have been made to the collection.
        expect(changeStream.next()).to(beNil())

        // test that the change stream contains a change document for the `insert` operation.
        try coll.insertOne(["x": 1], session: session)
        let res1 = changeStream.next()
        expect(res1).toNot(beNil())
        expect(res1?.operationType).to(equal(.insert))

        try coll.updateOne(filter: ["x": 1], update: ["$set": ["x": 2] as Document], session: session)
        let res2 = changeStream.next()
        // test that the change stream contains a change document for the `update` operation.
        expect(res2).toNot(beNil())
        expect(res2?.operationType).to(equal(.update))

        // test that the change stream contains a change document for the `find` operation.
        try coll.findOneAndDelete(["x": 2], session: session)
        let res3 = changeStream.next()
        expect(res3).toNot(beNil())
        expect(res3?.operationType).to(equal(.delete))
    }
}
