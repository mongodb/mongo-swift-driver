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

    let collName = "coll" + String(describing: Date())
    let doc1: Document = ["_id": 1, "cat": "dog"]
    let doc2: Document = ["_id": 2, "cat": "cat"]

    func getCollection() throws -> MongoSwift.Collection {
        return try Client().db("local").collection(collName)
    }

    func testCount() throws {
        let coll = try getCollection()
        try coll.insertOne(doc1)
        XCTAssertEqual(try coll.count(), 1)

        let options = CountOptions(limit: 5, maxTimeMS: 1000, skip: 5)
        let countWithOptions = try coll.count(options: options)
        XCTAssertEqual(countWithOptions, 0)
        try coll.drop()
    }

    func testInsertOne() throws {
        let coll = try getCollection()
        guard let result = try coll.insertOne(doc1) else {
            XCTFail("No result from insertion")
            return
        }
        XCTAssertEqual(result.insertedId as? Int, 1)

        try coll.insertOne(doc2)
        XCTAssertEqual(try coll.count(), 2)
        try coll.drop()
    }

    func testAggregate() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        let agg = Array(try coll.aggregate([["$project": ["_id": 0, "cat": 1] as Document]]))
        XCTAssertEqual(agg, [["cat": "dog"], ["cat": "cat"]] as [Document])
        try coll.drop()
    }

    func testDrop() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        try coll.drop()
        XCTAssertEqual(try coll.count(), 0)
    }

    func testInsertMany() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        XCTAssertEqual(try coll.count(), 2)
        try coll.drop()
    }

    func testFind() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        let findResult = try coll.find(["cat": "cat"])
        XCTAssertEqual(findResult.next(), ["_id": 2, "cat": "cat"])
        XCTAssertNil(findResult.next())
        try coll.drop()
    }

    func testDeleteOne() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        guard let deleteOneResult = try coll.deleteOne(["cat": "cat"]) else {
            XCTFail("No result from deleteOne")
            return
        }
        XCTAssertEqual(deleteOneResult.deletedCount, 1)
        try coll.drop()
    }

    func testDeleteMany() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        guard let deleteManyResult = try coll.deleteMany([:]) else {
            XCTFail("No result from deleteMany")
            return
        }
        XCTAssertEqual(deleteManyResult.deletedCount, 2)
        try coll.drop()
    }

    func testReplaceOne() throws {
        let coll = try getCollection()
        try coll.insertOne(doc1)
        guard let replaceOneResult = try coll.replaceOne(
            filter: ["_id": 1], replacement: ["apple": "banana"]) else {
            XCTFail("No result from replaceOne")
            return
        }

        XCTAssertEqual(replaceOneResult.matchedCount, 1)
        XCTAssertEqual(replaceOneResult.modifiedCount, 1)
        try coll.drop()
    }

    func testUpdateOne() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        guard let updateOneResult = try coll.updateOne(
            filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document]) else {
            XCTFail("No result from updateOne")
            return
        }

        XCTAssertEqual(updateOneResult.matchedCount, 1)
        XCTAssertEqual(updateOneResult.modifiedCount, 1)
        try coll.drop()

    }

    func testUpdateMany() throws {
        let coll = try getCollection()
        try coll.insertMany([doc1, doc2])
        guard let updateManyResult = try coll.updateMany(
            filter: [:], update: ["$set": ["apple": "pear"] as Document]) else {
            XCTFail("No result from updateMany")
            return
        }

        XCTAssertEqual(updateManyResult.matchedCount, 2)
        XCTAssertEqual(updateManyResult.modifiedCount, 2)
        try coll.drop()
    }
}
