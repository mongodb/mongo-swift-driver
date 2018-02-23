import Foundation
@testable import MongoSwift
import XCTest

final class CollectionTests: XCTestCase {
    static var allTests: [(String, (CollectionTests) -> () throws -> Void)] {
        return [
            ("testCollection", testCollection)
        ]
    }

    func testCollection() {
    	do {
    		let client = try Client(connectionString: "mongodb://localhost:27017/")
    		let db = try client.db("local")
            let collName = "coll" + String(describing: Date())
            let coll = try db.createCollection(collName)

            // Test count 
            let count = try coll.count([:])
            XCTAssertEqual(count, 0)

            // Test count with options
            let options = CountOptions(collation: [:], limit: 5, maxTimeMS: 1000, skip: 5)
            let countWithOptions = try coll.count([:], options: options)
            XCTAssertEqual(count, 0)

            // Test insertOne
            let doc1: Document = ["_id": 1, "cat": "dog"]
            guard let result: InsertOneResult = try coll.insertOne(doc1) else {
            	XCTFail("No result from insertion")
            	return
            }
            XCTAssertEqual(result.insertedId as? Int, 1)

            let doc2: Document = ["_id": 2, "cat": "cat"]
            try coll.insertOne(doc2)

            // Test non-zero count
            XCTAssertEqual(try coll.count([:]), 2)

            // Test aggregate with a basic pipeline
            let stage1: Document = ["$project": ["_id": 0, "cat": 1] as Document]
            let agg = try coll.aggregate([stage1])
            let docs = Array(agg)
            XCTAssertEqual(docs, [["cat": "dog"] as Document, ["cat": "cat"] as Document])

            // Test drop
            try coll.drop()
            XCTAssertEqual(try coll.count([:]), 0)

            // Test insertMany
            try coll.insertMany([doc1, doc2])
            XCTAssertEqual(try coll.count([:]), 2)

            // Test find
            let findResult = try coll.find(["cat": "cat"])
            XCTAssertEqual(findResult.next(), ["_id": 2, "cat": "cat"])
            XCTAssertNil(findResult.next())

            // Test deleteOne
            guard let deleteOneResult = try coll.deleteOne(["cat": "cat"]) else {
                XCTFail("No result from deleteOne")
                return
            }
            XCTAssertEqual(deleteOneResult.deletedCount, 1)

            // Test deleteMany 
            try coll.insertOne(doc2)
            guard let deleteManyResult = try coll.deleteMany([:]) else {
                XCTFail("No result from deleteMany")
                return
            }
            XCTAssertEqual(deleteManyResult.deletedCount, 2)

            // We can't actually create indexes yet, but test that trying to drop the existing
            //  _id index fails:
            do {
                try coll.dropIndex(name: "_id_")
                XCTFail("Dropping _id_ index should fail")
            } catch is MongoError {
                print("error")
            }

            // Test replaceOne 
            try coll.insertOne(doc1)
            guard let replaceOneResult: UpdateResult = try coll.replaceOne(
                filter: ["_id": 1], replacement: ["apple": "banana"]) else {
                XCTFail("No result from replaceOne")
                return
            }

            XCTAssertEqual(replaceOneResult.matchedCount, 1)
            XCTAssertEqual(replaceOneResult.modifiedCount, 1)

            // Test updateOne
            try coll.insertOne(doc2)
            guard let updateOneResult: UpdateResult = try coll.updateOne(
                filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document]) else {
                XCTFail("No result from updateOne")
                return
            }

            XCTAssertEqual(updateOneResult.matchedCount, 1)
            XCTAssertEqual(updateOneResult.modifiedCount, 1)

            // test that updates worked
            XCTAssertEqual(try coll.count(["apple": "banana"]), 2)

            // Test updateMany
            guard let updateManyResult: UpdateResult = try coll.updateMany(
                filter: [:], update: ["$set": ["apple": "pear"] as Document]) else {
                XCTFail("No result from updateMany")
                return
            }

            XCTAssertEqual(updateManyResult.matchedCount, 2)
            XCTAssertEqual(updateManyResult.modifiedCount, 2)

            try coll.drop()
    	} catch {
    		XCTFail("Error: \(error)")
    	}
    }
}
