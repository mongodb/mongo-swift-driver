@testable import MongoSwift
import Nimble
import XCTest

final class MongoCollection_BulkWriteTests: MongoSwiftTestCase {
    static var client: MongoClient?
    var coll: MongoCollection<Document>!

    /// Set up the entire suite - run once before all tests
    override class func setUp() {
        super.setUp()
        do {
            client = try MongoClient.makeTestClient()
        } catch {
            print("Setup failed: \(error)")
        }
    }

    /// Set up a single test - run before each testX function
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false

        guard let client = MongoCollection_BulkWriteTests.client else {
            return XCTFail("Client is not initialized")
        }

        coll = client.db(type(of: self).testDatabase).collection(self.getCollectionName())
    }

    /// Teardown a single test - run after each testX function
    override func tearDown() {
        do {
            try coll.drop()
        } catch let ServerError.commandError(code, _, _, _) where code == 26 {
            // ignore ns not found errors
        } catch {
            fail("encountered error when tearing down: \(error)")
        }
        super.tearDown()
    }

    /// Teardown the entire suite - run after all tests complete
    override class func tearDown() {
        client = nil

        super.tearDown()
    }

    func testEmptyRequests() {
        expect(try self.coll.bulkWrite([])).to(throwError(UserError.invalidArgumentError(message: "")))
    }

    func testInserts() throws {
        let requests: [WriteModel<Document>] = [
            .insertOne(["_id": 1, "x": 11]),
            .insertOne(["x": 22])
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.insertedCount).to(equal(2))
        expect(result.insertedIds[0]!).to(bsonEqual(1))
        expect(result.insertedIds[1]!).to(beAnInstanceOf(ObjectId.self))

        // verify inserted doc without _id was not modified.
        guard case let .insertOne(doc) = requests[1] else {
            fatalError("couldn't cast model to .insertOne")
        }
        expect(doc).to(equal(["x": 22]))

        let cursor = try coll.find()
        expect(cursor.next()).to(equal(["_id": 1, "x": 11]))
        expect(cursor.next()).to(equal(["_id": result.insertedIds[1]!, "x": 22]))
        expect(cursor.next()).to(beNil())
    }

    func testBulkWriteErrors() throws {
        let id = ObjectId()
        let id2 = ObjectId()
        let id3 = ObjectId()

        let doc = ["_id": id] as Document

        try self.coll.insertOne(doc)

        let requests: [WriteModel<Document>] = [
            .insertOne(["_id": id2]),
            .insertOne(doc),
            .updateOne(filter: ["_id": id3],
                       update: ["$set": ["asdfasdf": 1] as Document],
                       options: UpdateModelOptions(upsert: true))
        ]

        let expectedResult = BulkWriteResult(
                deletedCount: 0,
                insertedCount: 1,
                insertedIds: [0: id2],
                matchedCount: 0,
                modifiedCount: 0,
                upsertedCount: 1,
                upsertedIds: [2: id3]
        )

        // Expect a duplicate key error (11000)
        let expectedError = ServerError.bulkWriteError(
                writeErrors: [BulkWriteError(code: 11000, codeName: "DuplicateKey", message: "", index: 1)],
                writeConcernError: nil,
                otherError: nil,
                result: expectedResult,
                errorLabels: nil)

        let options = BulkWriteOptions(ordered: false)

        expect(try self.coll.bulkWrite(requests, options: options)).to(throwError(expectedError))
    }

    func testUpdates() throws {
        try createFixtures(4)

        let requests: [WriteModel<Document>] = [
            .updateOne(filter: ["_id": 2], update: ["$inc": ["x": 1] as Document], options: nil),
            .updateMany(filter: ["_id": ["$gt": 2] as Document], update: ["$inc": ["x": -1] as Document], options: nil),
            .updateOne(filter: ["_id": 5],
                       update: ["$set": ["x": 55] as Document],
                       options: UpdateModelOptions(upsert: true)),
            .updateOne(filter: ["x": 66],
                       update: ["$set": ["x": 66] as Document],
                       options: UpdateModelOptions(upsert: true)),
            .updateMany(filter: ["x": ["$gt": 50] as Document], update: ["$inc": ["x": 1] as Document], options: nil)
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.matchedCount).to(equal(5))
        expect(result.modifiedCount).to(equal(5))
        expect(result.upsertedCount).to(equal(2))
        expect(result.upsertedIds[2]!).to(bsonEqual(5))
        expect(result.upsertedIds[3]!).to(beAnInstanceOf(ObjectId.self))

        let cursor = try coll.find()
        expect(cursor.next()).to(equal(["_id": 1, "x": 11]))
        expect(cursor.next()).to(equal(["_id": 2, "x": 23]))
        expect(cursor.next()).to(equal(["_id": 3, "x": 32]))
        expect(cursor.next()).to(equal(["_id": 4, "x": 43]))
        expect(cursor.next()).to(equal(["_id": 5, "x": 56]))
        expect(cursor.next()).to(equal(["_id": result.upsertedIds[3]!, "x": 67]))
        expect(cursor.next()).to(beNil())
    }

    func testDeletes() throws {
        try createFixtures(4)

        let requests: [WriteModel<Document>] = [
            .deleteOne(["_id": 1], options: nil),
            .deleteMany(["_id": ["$gt": 2] as Document], options: nil)
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.deletedCount).to(equal(3))

        let cursor = try coll.find()
        expect(cursor.next()).to(equal(["_id": 2, "x": 22]))
        expect(cursor.next()).to(beNil())
    }

    func testMixedOrderedOperations() throws {
        try createFixtures(3)

        let requests: [WriteModel<Document>] = [
            .updateOne(filter: ["_id": ["$gt": 1] as Document],
                       update: ["$inc": ["x": 1] as Document],
                       options: nil),
            .updateMany(filter: ["_id": ["$gt": 1] as Document], update: ["$inc": ["x": 1] as Document], options: nil),
            .insertOne(["_id": 4]),
            .deleteMany(["x": ["$nin": [24, 34]] as Document], options: nil),
            .replaceOne(filter: ["_id": 4],
                        replacement: ["_id": 4, "x": 44],
                        options: ReplaceOneModelOptions(upsert: true))
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.insertedCount).to(equal(1))
        expect(result.insertedIds[2]!).to(bsonEqual(4))
        expect(result.matchedCount).to(equal(3))
        expect(result.modifiedCount).to(equal(3))
        expect(result.upsertedCount).to(equal(1))
        expect(result.upsertedIds[4]!).to(bsonEqual(4))
        expect(result.deletedCount).to(equal(2))

        let cursor = try coll.find()
        expect(cursor.next()).to(equal(["_id": 2, "x": 24]))
        expect(cursor.next()).to(equal(["_id": 3, "x": 34]))
        expect(cursor.next()).to(equal(["_id": 4, "x": 44]))
        expect(cursor.next()).to(beNil()) // cursor ends
        expect(cursor.error).to(beNil())
        expect(cursor.next()).to(beNil()) // iterate after cursor ends
        expect(cursor.error as? UserError).to(equal(UserError.logicError(message: "")))
    }

    func testUnacknowledgedWriteConcern() throws {
        let requests: [WriteModel<Document>] = [.insertOne(["_id": 1])]
        let options = BulkWriteOptions(writeConcern: try WriteConcern(w: .number(0)))
        let result = try self.coll.bulkWrite(requests, options: options)
        expect(result).to(beNil())
    }

    private func createFixtures(_ n: Int) throws {
        var documents: [Document] = []

        for i in 1...n {
            documents.append(["_id": i, "x": Int("\(i)\(i)")!])
        }

        try self.coll.insertMany(documents)
    }
}
