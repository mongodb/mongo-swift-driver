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
            let count = try coll.count([:])
            XCTAssertEqual(count, 0)

            let options = CountOptions(collation: [:], limit: 5, maxTimeMS: 1000, skip: 5)
            let countWithOptions = try coll.count([:], options: options)
            XCTAssertEqual(count, 0)

            let doc1: Document = ["_id": 1, "cat": "dog"]
            guard let result: InsertOneResult = try coll.insertOne(doc1) else {
            	XCTFail("No result from insertion")
            	return
            }
            XCTAssertEqual(result.insertedId as? Int, 1)

            let doc2: Document = ["_id": 2, "cat": "cat"]
            try coll.insertOne(doc2)

            XCTAssertEqual(try coll.count([:]), 2)

            let stage1: Document = ["$project": ["_id": 0, "cat": 1] as Document]
            let agg = try coll.aggregate([stage1])
            let docs = Array(agg)
            XCTAssertEqual(docs, [["cat": "dog"] as Document, ["cat": "cat"] as Document])

    	} catch {
    		XCTFail("Error: \(error)")
    	}
    }
}
