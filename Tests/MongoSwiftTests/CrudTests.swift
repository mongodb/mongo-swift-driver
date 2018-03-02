@testable import MongoSwift
import Foundation
import XCTest

final class CrudTests: XCTestCase {

	static var allTests: [(String, (CrudTests) -> () throws -> Void)] {
        return [
            ("testReads", testReads),
            ("testWrites", testWrites)
        ]
    }

    override class func tearDown() {
        super.tearDown()
        do {
        	try Client().db("crudTests").drop()
    	} catch {
        	XCTFail("Dropping test db crudTests failed: \(error)")
        }
    }

    func doTest(forPath: String) throws {
    	let db = try Client().db("crudTests")
    	for file in try parseFiles(atPath: forPath)[0...1] {
    		let collection = try db.collection("\(file.name)")
    		try collection.insertMany(file.data)
    		print("\n------------\nExecuting tests from file \(forPath)/\(file.name).json...\n")
    		for test in file.tests {
    			print("Executing test: \(test.description)")
    			try test.execute(collection, database: db)
    		}
    	}
    	print()
    }

    private func parseFiles(atPath path: String) throws -> [CrudTestFile] {
		var tests = [CrudTestFile]()
		let testFiles = try FileManager.default.contentsOfDirectory(atPath: path).filter { $0.hasSuffix(".json") }
		for fileName in testFiles {
			let testFilePath = URL(fileURLWithPath: "\(path)/\(fileName)")
			let asDocument = try Document(fromJSONFile: testFilePath)
	        tests.append(try CrudTestFile(fromDocument: asDocument, name: fileName))
		}
		return tests
	}

    func testReads() throws {
    	try doTest(forPath: "Tests/Specs/crud/tests/read")
    }

    func testWrites() throws {
    	try doTest(forPath: "Tests/Specs/crud/tests/write")
    }

}

/// A container for the data from a single .json file. 
private struct CrudTestFile {
	let data: [Document]
	let tests: [CrudTest]
	let minServerVersion: String?
	let maxServerVersion: String?
	let name: String

	/// Initializes a new `CrudTestFile` from a `Document`. 
	init(fromDocument document: Document, name: String) throws {
		self.data = try document.get("data")
		let tests: [Document] = try document.get("tests")
        self.tests = try tests.map { try makeCrudTest($0) }
		self.minServerVersion = document["minServerVersion"] as? String
		self.maxServerVersion = document["maxServerVersion"] as? String
		self.name = name.components(separatedBy: ".")[0]
	}
}

private func makeCrudTest(_ doc: Document) throws -> CrudTest {
	let operation: Document = try doc.get("operation")
	let opName: String = try operation.get("name")
	guard let type = testTypeMap[opName] else { throw TypeError(message: "Unknown operation \(opName)") }
	return try type.init(doc)
}

private class CrudTest {
	let description: String
	let operationName: String
	let args: Document
	let result: BsonValue?
	let outCollection: Document?
	var collation: Document? { return self.args["collation"] as? Document }
	var sort: Document? { return self.args["sort"] as? Document }
	var skip: Int64? { if let s = self.args["skip"] as? Int { return Int64(s) } else { return nil } }
	var limit: Int64? { if let l = self.args["limit"] as? Int { return Int64(l) } else { return nil } }
	var batchSize: Int32? { if let b = self.args["batchSize"] as? Int { return Int32(b) } else { return nil } }

		/// Initializes a new `CrudTest` from a `Document`. 
	required init(_ test: Document) throws {
		self.description = try test.get("description")
		let operation: Document = try test.get("operation")
		self.operationName = try operation.get("name")
		self.args = try operation.get("arguments")
		let outcome: Document = try test.get("outcome")
		self.result = outcome["result"]
		self.outCollection = outcome["collection"] as? Document
	}

	func execute(_ coll: MongoSwift.Collection, database: Database) throws { XCTFail("Unimplemented") }
}

private class AggregateTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let pipeline: [Document] = try self.args.get("pipeline")
		let options = AggregateOptions(batchSize: self.batchSize, collation: self.collation)
		let cursor = try coll.aggregate(pipeline, options: options)
		if let out = self.outCollection {
			// we need to iterate the cursor once in order to make the aggregation happen
			XCTAssertEqual(cursor.next(), nil)
			let expectedData: [Document] = try out.get("data")
			let outColl = try database.collection(out["name"] as? String ?? "crudTests")
			let result = Array(try outColl.find([:]))
			XCTAssertEqual(result, expectedData)
		} else {
			XCTAssertEqual(Array(cursor), self.result as! [Document])
		}
	}
}

private class BulkWriteTest: CrudTest {}

private class CountTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let filter: Document = try self.args.get("filter")
		let options = CountOptions(collation: self.collation, limit: self.limit, skip: self.skip)
		let result = try coll.count(filter, options: options)
		XCTAssertEqual(result, self.result as? Int)
	}
}

private class DeleteManyTest: CrudTest {}
private class DeleteOneTest: CrudTest {}

private class DistinctTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let filter = self.args["filter"] as? Document
		let fieldName: String = try self.args.get("fieldName")
		let options = DistinctOptions(collation: self.collation)
		let distinct = try coll.distinct(fieldName: fieldName, filter: filter ?? [:], options: options)
		XCTAssertEqual(distinct.next(), ["values": self.result, "ok": 1.0] as Document)
		XCTAssertNil(distinct.next())
	}
}

private class FindTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let filter: Document = try self.args.get("filter")
		let options = FindOptions(batchSize: batchSize, collation: collation, limit: self.limit,
									skip: self.skip, sort: self.sort)
		let result = try Array(coll.find(filter, options: options))
		XCTAssertEqual(result, self.result as! [Document])
	}
}

private class FindOneAndDeleteTest: CrudTest {}
private class FindOneAndReplaceTest: CrudTest {}
private class FindOneAndUpdateTest: CrudTest {}

private class InsertManyTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let documents: [Document] = try self.args.get("documents")
		print("documents: \(documents)")
		if let result = try coll.insertMany(documents) {

		} else {

		}

		// guard let expectedIds = InsertManyResult(from: expectedDoc)?.insertedIds else {
		// 	XCTFail("Could not create InsertManyResult from expected result")
		// 	return
		// }
		//XCTAssertEqual(result?.insertedIds, expectedResult.insertedIds)
	}
}

private class InsertOneTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let doc: Document = try self.args.get("document")
		let result = try coll.insertOne(doc)
		XCTAssertEqual(doc["_id"] as! Int, result?.insertedId as! Int)
	}

}

private class ReplaceOneTest: CrudTest {}

private class UpdateManyTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let filter: Document = try self.args.get("filter")
		let update: Document = try self.args.get("update")
		let arrayFilters = self.args["arrayFilters"] as? [Document]
		let options = UpdateOptions(arrayFilters: arrayFilters, collation: self.collation)
		let result = try coll.updateMany(filter: filter, update: update, options: options)
		let expectedResult = self.result as? Document
		XCTAssertEqual(result?.matchedCount, expectedResult?["matchedCount"] as? Int)
		XCTAssertEqual(result?.modifiedCount, expectedResult?["modifiedCount"] as? Int)
		// print("upserted; \(result?.upsertedId)")
		// if expectedResult?["upsertedCount"] as? Int > 0 {
		// 	print(expectedResult?["upsertedCount"] as Any)
		// 	//XCTAssertEqual((result?.upsertedId as [Any]).count, 1)
		// }
	}
}

private class UpdateOneTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let filter: Document = try self.args.get("filter")
		let update: Document = try self.args.get("update")
		let arrayFilters = self.args["arrayFilters"] as? [Document]
		let options = UpdateOptions(arrayFilters: arrayFilters, collation: self.collation)
		let result = try coll.updateOne(filter: filter, update: update, options: options)
		let expected = self.result as? Document
		XCTAssertEqual(result?.matchedCount, expected?["matchedCount"] as? Int)
		XCTAssertEqual(result?.modifiedCount, expected?["modifiedCount"] as? Int)
		if let id = result?.upsertedId as? Int {
			XCTAssertEqual(expected?["upsertedId"] as? Int, id)
		}
	}
}

private var testTypeMap: [String: CrudTest.Type] = [
	"aggregate": AggregateTest.self,
	"bulkWrite": BulkWriteTest.self,
	"count": CountTest.self,
	"deleteMany": DeleteManyTest.self,
	"deleteOne": DeleteOneTest.self,
	"distinct": DistinctTest.self,
	"find": FindTest.self,
	"findOneAndDelete": FindOneAndDeleteTest.self,
	"findOneAndReplace": FindOneAndReplaceTest.self,
	"findOneAndUpdate": FindOneAndUpdateTest.self,
	"insertMany": InsertManyTest.self,
	"insertOne": InsertOneTest.self,
	"replaceOne": ReplaceOneTest.self,
	"updateMany": UpdateManyTest.self,
	"updateOne": UpdateOneTest.self
]

private struct TypeError: LocalizedError {
	var message: String
	public var errorDescription: String { return self.message }
}
