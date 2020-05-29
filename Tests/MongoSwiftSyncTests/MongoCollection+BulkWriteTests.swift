import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

final class MongoCollection_BulkWriteTests: MongoSwiftTestCase {
    static var client: MongoClient?
    var coll: MongoCollection<BSONDocument>!

    /// Set up the entire suite - run once before all tests
    override class func setUp() {
        super.setUp()
        do {
            self.client = try MongoClient.makeTestClient()
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

        self.coll = client.db(Self.testDatabase).collection(self.getCollectionName())
    }

    /// Teardown a single test - run after each testX function
    override func tearDown() {
        do {
            try self.coll.drop()
        } catch {
            fail("encountered error when tearing down: \(error)")
        }
        super.tearDown()
    }

    /// Teardown the entire suite - run after all tests complete
    override class func tearDown() {
        self.client = nil

        super.tearDown()
    }

    func testEmptyRequests() {
        expect(try self.coll.bulkWrite([])).to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    func testInserts() throws {
        let requests: [WriteModel<BSONDocument>] = [
            .insertOne(["_id": 1, "x": 11]),
            .insertOne(["x": 22])
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.insertedCount).to(equal(2))
        expect(result.insertedIDs[0]!).to(equal(1))
        expect(result.insertedIDs[1]!.type).to(equal(.objectID))

        // verify inserted doc without _id was not modified.
        guard case let .insertOne(doc) = requests[1] else {
            fatalError("couldn't cast model to .insertOne")
        }
        expect(doc).to(equal(["x": 22]))

        let cursor = try coll.find()
        expect(try cursor.next()?.get()).to(equal(["_id": 1, "x": 11]))
        expect(try cursor.next()?.get()).to(equal(["_id": result.insertedIDs[1]!, "x": 22]))
        expect(try cursor.next()?.get()).to(beNil())
    }

    func testBulkWriteErrors() throws {
        let id = BSON.objectID()
        let id2 = BSON.objectID()
        let id3 = BSON.objectID()

        let doc = ["_id": id] as BSONDocument

        try self.coll.insertOne(doc)

        let requests: [WriteModel<BSONDocument>] = [
            .insertOne(["_id": id2]),
            .insertOne(doc),
            .updateOne(
                filter: ["_id": id3],
                update: ["$set": ["asdfasdf": 1]],
                options: UpdateModelOptions(upsert: true)
            )
        ]

        let expectedResult = BulkWriteResult.new(
            deletedCount: 0,
            insertedCount: 1,
            insertedIDs: [0: id2],
            matchedCount: 0,
            modifiedCount: 0,
            upsertedCount: 1,
            upsertedIDs: [2: id3]
        )

        // Expect a duplicate key error (11000)
        let expectedError = MongoError.BulkWriteError.new(
            writeFailures: [
                MongoError.BulkWriteFailure.new(code: 11000, codeName: "DuplicateKey", message: "", index: 1)
            ],
            writeConcernFailure: nil,
            otherError: nil,
            result: expectedResult,
            errorLabels: nil
        )

        let options = BulkWriteOptions(ordered: false)

        expect(try self.coll.bulkWrite(requests, options: options)).to(throwError(expectedError))
    }

    func testUpdates() throws {
        try self.createFixtures(4)

        let requests: [WriteModel<BSONDocument>] = [
            .updateOne(filter: ["_id": 2], update: ["$inc": ["x": 1]]),
            .updateMany(filter: ["_id": ["$gt": 2]], update: ["$inc": ["x": -1]]),
            .updateOne(
                filter: ["_id": 5],
                update: ["$set": ["x": 55]],
                options: UpdateModelOptions(upsert: true)
            ),
            .updateOne(
                filter: ["x": 66],
                update: ["$set": ["x": 66]],
                options: UpdateModelOptions(upsert: true)
            ),
            .updateMany(filter: ["x": ["$gt": 50]], update: ["$inc": ["x": 1]])
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.matchedCount).to(equal(5))
        expect(result.modifiedCount).to(equal(5))
        expect(result.upsertedCount).to(equal(2))
        expect(result.upsertedIDs[2]!).to(equal(5))
        expect(result.upsertedIDs[3]!.type).to(equal(.objectID))

        let cursor = try coll.find()
        expect(try cursor.next()?.get()).to(equal(["_id": 1, "x": 11]))
        expect(try cursor.next()?.get()).to(equal(["_id": 2, "x": 23]))
        expect(try cursor.next()?.get()).to(equal(["_id": 3, "x": 32]))
        expect(try cursor.next()?.get()).to(equal(["_id": 4, "x": 43]))
        expect(try cursor.next()?.get()).to(equal(["_id": 5, "x": 56]))
        expect(try cursor.next()?.get()).to(equal(["_id": result.upsertedIDs[3]!, "x": 67]))
        expect(try cursor.next()?.get()).to(beNil())
    }

    func testDeletes() throws {
        try self.createFixtures(4)

        let requests: [WriteModel<BSONDocument>] = [
            .deleteOne(["_id": 1]),
            .deleteMany(["_id": ["$gt": 2]])
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.deletedCount).to(equal(3))

        let cursor = try coll.find()
        expect(try cursor.next()?.get()).to(equal(["_id": 2, "x": 22]))
        expect(try cursor.next()?.get()).to(beNil())
    }

    func testMixedOrderedOperations() throws {
        try self.createFixtures(3)

        let requests: [WriteModel<BSONDocument>] = [
            .updateOne(
                filter: ["_id": ["$gt": 1]],
                update: ["$inc": ["x": 1]],
                options: nil
            ),
            .updateMany(filter: ["_id": ["$gt": 1]], update: ["$inc": ["x": 1]]),
            .insertOne(["_id": 4]),
            .deleteMany(["x": ["$nin": [24, 34]]]),
            .replaceOne(
                filter: ["_id": 4],
                replacement: ["_id": 4, "x": 44],
                options: ReplaceOneModelOptions(upsert: true)
            )
        ]

        let result: BulkWriteResult! = try self.coll.bulkWrite(requests)

        expect(result.insertedCount).to(equal(1))
        expect(result.insertedIDs[2]!).to(equal(4))
        expect(result.matchedCount).to(equal(3))
        expect(result.modifiedCount).to(equal(3))
        expect(result.upsertedCount).to(equal(1))
        expect(result.upsertedIDs[4]!).to(equal(4))
        expect(result.deletedCount).to(equal(2))

        let cursor = try coll.find()
        expect(try cursor.next()?.get()).to(equal(["_id": 2, "x": 24]))
        expect(try cursor.next()?.get()).to(equal(["_id": 3, "x": 34]))
        expect(try cursor.next()?.get()).to(equal(["_id": 4, "x": 44]))
        expect(cursor.next()).to(beNil()) // cursor ends
        expect(try cursor.next()?.get())
            .to(throwError(errorType: MongoError.LogicError.self)) // iterate after cursor ends
    }

    func testUnacknowledgedWriteConcern() throws {
        let requests: [WriteModel<BSONDocument>] = [.insertOne(["_id": 1])]
        let options = BulkWriteOptions(writeConcern: try WriteConcern(w: .number(0)))
        let result = try self.coll.bulkWrite(requests, options: options)
        expect(result).to(beNil())
    }

    private func createFixtures(_ n: Int) throws {
        var documents: [BSONDocument] = []

        for i in 1...n {
            documents.append(["_id": BSON(i), "x": BSON(Int("\(i)\(i)")!)])
        }

        try self.coll.insertMany(documents)
    }
}
