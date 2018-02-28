import Foundation
@testable import MongoSwift
import XCTest

final class CollectionTests: XCTestCase {
    static var allTests: [(String, (CollectionTests) -> () throws -> Void)] {
        return [
            ("testCount", testCount),
            ("testInsertOne", testInsertOne),
            ("testAggregate", testAggregate),
            ("testDrop", testDrop),
            ("testInsertMany", testInsertMany),
            ("testFind", testFind),
            ("testDeleteOne", testDeleteOne),
            ("testDeleteMany", testDeleteMany),
            ("testReplaceOne", testReplaceOne),
            ("testUpdateOne", testUpdateOne),
            ("testUpdateMany", testUpdateMany)
        ]
    }

    var coll: MongoSwift.Collection!

    let doc1: Document = ["_id": 1, "cat": "dog"]
    let doc2: Document = ["_id": 2, "cat": "cat"]

    /// Set up a single test - run before each testX function
    override func setUp() {
        super.setUp()
        do {
            coll = try Client().db("collectionTest").collection("coll1")
        } catch {
            XCTFail("Setup failed: \(error)")
        }
    }

    /// Teardown a single test - run after each testX function
    override func tearDown() {
        super.tearDown()
        do {
            try coll.drop()
        } catch {
            XCTFail("Dropping test collection collectionTest.coll1 failed: \(error)")
        }

    }

    override class func tearDown() {
        super.tearDown()
        do {
            print("drop DB")
            // drop database here
        } catch {
            XCTFail("Dropping test database collectionTest failed: \(error)")
        }
    }

    func testCount() throws {
        try coll.insertOne(doc1)
        XCTAssertEqual(try coll.count(), 1)
        let options = CountOptions(limit: 5, maxTimeMS: 1000, skip: 5)
        let countWithOptions = try coll.count(options: options)
        XCTAssertEqual(countWithOptions, 0)
    }

    func testInsertOne() throws {
        guard let result = try coll.insertOne(doc1) else {
            XCTFail("No result from insertion")
            return
        }
        XCTAssertEqual(result.insertedId as? Int, 1)

        try coll.insertOne(doc2)
        XCTAssertEqual(try coll.count(), 2)
    }

    func testAggregate() throws {
        try coll.insertMany([doc1, doc2])
        let agg = Array(try coll.aggregate([["$project": ["_id": 0, "cat": 1] as Document]]))
        XCTAssertEqual(agg, [["cat": "dog"], ["cat": "cat"]] as [Document])
    }

    func testDrop() throws {
        try coll.insertMany([doc1, doc2])
        try coll.drop()
        XCTAssertEqual(try coll.count(), 0)
        // insert something so we don't error when trying to drop
        // in the cleanup func
        try coll.insertOne(doc1)
    }

    func testInsertMany() throws {
        try coll.insertMany([doc1, doc2])
        XCTAssertEqual(try coll.count(), 2)
    }

    func testFind() throws {
        try coll.insertMany([doc1, doc2])
        let findResult = try coll.find(["cat": "cat"])
        XCTAssertEqual(findResult.next(), ["_id": 2, "cat": "cat"])
        XCTAssertNil(findResult.next())
    }

    func testDeleteOne() throws {
        try coll.insertMany([doc1, doc2])
        guard let deleteOneResult = try coll.deleteOne(["cat": "cat"]) else {
            XCTFail("No result from deleteOne")
            return
        }
        XCTAssertEqual(deleteOneResult.deletedCount, 1)
    }

    func testDeleteMany() throws {
        try coll.insertMany([doc1, doc2])
        guard let deleteManyResult = try coll.deleteMany([:]) else {
            XCTFail("No result from deleteMany")
            return
        }
        XCTAssertEqual(deleteManyResult.deletedCount, 2)
    }

    func testReplaceOne() throws {
        try coll.insertOne(doc1)
        guard let replaceOneResult = try coll.replaceOne(
            filter: ["_id": 1], replacement: ["apple": "banana"]) else {
            XCTFail("No result from replaceOne")
            return
        }

        XCTAssertEqual(replaceOneResult.matchedCount, 1)
        XCTAssertEqual(replaceOneResult.modifiedCount, 1)
    }

    func testUpdateOne() throws {
        try coll.insertMany([doc1, doc2])
        guard let updateOneResult = try coll.updateOne(
            filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document]) else {
            XCTFail("No result from updateOne")
            return
        }

        XCTAssertEqual(updateOneResult.matchedCount, 1)
        XCTAssertEqual(updateOneResult.modifiedCount, 1)
    }

    func testUpdateMany() throws {
        try coll.insertMany([doc1, doc2])
        guard let updateManyResult = try coll.updateMany(
            filter: [:], update: ["$set": ["apple": "pear"] as Document]) else {
            XCTFail("No result from updateMany")
            return
        }

        XCTAssertEqual(updateManyResult.matchedCount, 2)
        XCTAssertEqual(updateManyResult.modifiedCount, 2)
    }
}
