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
            ("testUpdateMany", testUpdateMany),
            ("testDistinct", testDistinct),
            ("testCreateIndexFromModel", testCreateIndexFromModel),
            ("testCreateIndexesFromModels", testCreateIndexesFromModels),
            ("testCreateIndexFromKeys", testCreateIndexFromKeys),
            ("testCreateIndexesFromKeys", testCreateIndexesFromKeys),
            ("testDropIndexByName", testDropIndexByName),
            ("testDropIndexByModel", testDropIndexByModel),
            ("testDropIndexByKeys", testDropIndexByKeys),
            ("testDropAllIndexes", testDropAllIndexes),
            ("testListIndexes", testListIndexes)
        ]
    }

    var coll: MongoSwift.Collection!
    let doc1: Document = ["_id": 1, "cat": "dog"]
    let doc2: Document = ["_id": 2, "cat": "cat"]

    /// Set up a single test - run before each testX function
    override func setUp() {
        super.setUp()
        do {
            coll = try Client().db("collectionTest").createCollection("coll1")
            try coll.insertMany([doc1, doc2])
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
            let db = try Client().db("collectionTest")
            try db.drop()
        } catch {
            XCTFail("Dropping test database collectionTest failed: \(error)")
        }
    }

    func testCount() throws {
        XCTAssertEqual(try coll.count(), 2)
        let options = CountOptions(limit: 5, maxTimeMS: 1000, skip: 5)
        let countWithOptions = try coll.count(options: options)
        XCTAssertEqual(countWithOptions, 0)
    }

    func testInsertOne() throws {
        try coll.deleteMany([:])
        let result = try coll.insertOne(doc1)
        XCTAssertEqual(result?.insertedId as? Int, 1)

        try coll.insertOne(doc2)
        XCTAssertEqual(try coll.count(), 2)

        // try inserting a document without an ID to verify one is generated and returned
        let docNoId: Document = ["x": 1]
        let noIdResult = try coll.insertOne(docNoId)
        XCTAssertNotNil(noIdResult?.insertedId)
    }

    func testAggregate() throws {
        let agg = Array(try coll.aggregate([["$project": ["_id": 0, "cat": 1] as Document]]))
        XCTAssertEqual(agg, [["cat": "dog"], ["cat": "cat"]] as [Document])
    }

    func testDrop() throws {
        try coll.drop()
        XCTAssertEqual(try coll.count(), 0)
        // insert something so we don't error when trying to drop
        // in the cleanup func
        try coll.insertOne(doc1)
    }

    func testInsertMany() throws {
        XCTAssertEqual(try coll.count(), 2)

        // try inserting a mix of documents with and without IDs to verify they are generated
        let docNoId1: Document = ["x": 1]
        let docNoId2: Document = ["x": 2]
        let docId1: Document = ["_id": 10, "x": 8]
        let docId2: Document = ["_id": 11, "x": 9]
        let result = try coll.insertMany([docNoId1, docNoId2, docId1, docId2])
        guard let insertedIds = result?.insertedIds else {
            XCTFail("No insertedIds in InsertManyResult")
            return
        }
       XCTAssertEqual(insertedIds.count, 4)
       XCTAssertEqual(insertedIds[2] as? Int, 10)
       XCTAssertEqual(insertedIds[3] as? Int, 11)

       XCTAssertNotNil(docNoId1["_id"] as? ObjectId)
       XCTAssertNotNil(docNoId2["_id"] as? ObjectId)
    }

    func testFind() throws {
        let findResult = try coll.find(["cat": "cat"])
        XCTAssertEqual(findResult.next(), ["_id": 2, "cat": "cat"])
        XCTAssertNil(findResult.next())
    }

    func testDeleteOne() throws {
        let deleteOneResult = try coll.deleteOne(["cat": "cat"])
        XCTAssertEqual(deleteOneResult?.deletedCount, 1)
    }

    func testDeleteMany() throws {
        let deleteManyResult = try coll.deleteMany([:])
        XCTAssertEqual(deleteManyResult?.deletedCount, 2)
    }

    func testReplaceOne() throws {
        let replaceOneResult = try coll.replaceOne(
            filter: ["_id": 1], replacement: ["apple": "banana"])
        XCTAssertEqual(replaceOneResult?.matchedCount, 1)
        XCTAssertEqual(replaceOneResult?.modifiedCount, 1)
    }

    func testUpdateOne() throws {
        let updateOneResult = try coll.updateOne(
            filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document])
        XCTAssertEqual(updateOneResult?.matchedCount, 1)
        XCTAssertEqual(updateOneResult?.modifiedCount, 1)
    }

    func testUpdateMany() throws {
        let updateManyResult = try coll.updateMany(
            filter: [:], update: ["$set": ["apple": "pear"] as Document])
        XCTAssertEqual(updateManyResult?.matchedCount, 2)
        XCTAssertEqual(updateManyResult?.modifiedCount, 2)
    }

    func testDistinct() throws {
        let distinct = try coll.distinct(fieldName: "cat", filter: [:])
        XCTAssertEqual(distinct.next(), ["values": ["dog", "cat"], "ok": 1.0] as Document)
        XCTAssertNil(distinct.next())
    }

    func testCreateIndexFromModel() throws {
        let model = IndexModel(keys: ["cat": 1])
        let result = try coll.createIndex(model)
        XCTAssertEqual(result, "cat_1")

        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertEqual(indexes.next()?["name"] as? String, "cat_1")
        XCTAssertNil(indexes.next())
    }

    func testCreateIndexesFromModels() throws {
        let model1 = IndexModel(keys: ["cat": 1])
        let model2 = IndexModel(keys: ["cat": -1])
        let result = try coll.createIndexes([model1, model2])
        XCTAssertEqual(result, ["cat_1", "cat_-1"])

        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertEqual(indexes.next()?["name"] as? String, "cat_1")
        XCTAssertEqual(indexes.next()?["name"] as? String, "cat_-1")
        XCTAssertNil(indexes.next())
    }

    func testCreateIndexFromKeys() throws {
        var model = IndexModel(keys: ["cat": 1])
        var result = try coll.createIndex(model)
        XCTAssertEqual(result, "cat_1")

        let indexOptions = IndexOptions(name: "blah", unique: true)
        model = IndexModel(keys: ["cat": -1], options: indexOptions)
        result = try coll.createIndex(model)
        XCTAssertEqual(result, "blah")

        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertEqual(indexes.next()?["name"] as? String, "cat_1")

        let thirdIndex = indexes.next()
        XCTAssertNil(indexes.next(), "Expected only three indexes")
        XCTAssertEqual(thirdIndex?["name"] as? String, "blah")
        XCTAssertEqual(thirdIndex?["unique"] as? Bool, true)
    }

    func testCreateIndexesFromKeys() throws {
        let result = try coll.createIndex(["cat": 1])
        XCTAssertEqual(result, "cat_1")

        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertEqual(indexes.next()?["name"] as? String, "cat_1")
        XCTAssertNil(indexes.next())
    }

    func testDropIndexByName() throws {
        let model = IndexModel(keys: ["cat": 1])
        let result = try coll.createIndex(model)
        XCTAssertEqual(result, "cat_1")

        try coll.dropIndex("cat_1")

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertNil(indexes.next())
    }

    func testDropIndexByModel() throws {
        let model = IndexModel(keys: ["cat": 1])
        let result = try coll.createIndex(model)
        XCTAssertEqual(result, "cat_1")

        let dropResult = try coll.dropIndex(model)
        XCTAssertEqual(dropResult["ok"] as? Double, 1.0)

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertNil(indexes.next())
    }

    func testDropIndexByKeys() throws {
        let model = IndexModel(keys: ["cat": 1])
        let result = try coll.createIndex(model)
        XCTAssertEqual(result, "cat_1")

        let dropResult = try coll.dropIndex(["cat": 1])
        XCTAssertEqual(dropResult["ok"] as? Double, 1.0)

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertNil(indexes.next())
    }

    func testDropAllIndexes() throws {
        let model = IndexModel(keys: ["cat": 1])
        let result = try coll.createIndex(model)
        XCTAssertEqual(result, "cat_1")

        let dropResult = try coll.dropIndexes()
        XCTAssertEqual(dropResult["ok"] as? Double, 1.0)

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertNil(indexes.next())
    }

    func testListIndexes() throws {
        let indexes = try coll.listIndexes()
        // New collection, so expect just the _id_ index to exist. 
        XCTAssertEqual(indexes.next()?["name"] as? String, "_id_")
        XCTAssertNil(indexes.next())
    }
}
