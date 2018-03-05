@testable import MongoSwift
import Foundation
import XCTest

// Files to skip because we don't currently support the operations they test.
private var skippedFiles = [
	"bulkWrite-arrayFilters",
	"findOneAndDelete-collation",
	"findOneAndDelete",
	"findOneAndReplace-collation",
	"findOneAndReplace-upsert",
	"findOneAndReplace",
	"findOneAndUpdate-arrayFilters",
	"findOneAndUpdate-collation",
	"findOneAndUpdate"
]

final class CrudTests: XCTestCase {

	static var allTests: [(String, (CrudTests) -> () throws -> Void)] {
        return [
            ("testReads", testReads),
            ("testWrites", testWrites)
        ]
    }

    // Teardown at the very end of the suite by dropping the "crudTests" db.
    override class func tearDown() {
        super.tearDown()
        do {
        	try Client().db("crudTests").drop()
    	} catch {
        	XCTFail("Dropping test db crudTests failed: \(error)")
        }
    }

    // Run tests for .json files at the provided path
    func doTests(forPath: String) throws {
    	let db = try Client().db("crudTests")
    	for file in try parseFiles(atPath: forPath) {
    		// later on when running with different server versions, this would
    		// be the place to check file.minServerVersion/maxServerVersion

    		// create a new collection for this file's tests
    		let collection = try db.collection("\(file.name)")

    		print("\n------------\nExecuting tests from file \(forPath)/\(file.name).json...\n")

    		// For each file, execute the test cases contained in it
    		for test in file.tests {

    			print("Executing test: \(test.description)")

    			// for each test case, insert data anew, and then drop it all after
    			try collection.insertMany(file.data)
    			try test.execute(usingCollection: collection)
    			try test.verifyData(testCollection: collection, db: db)
    			try collection.drop()
    		}
    	}
    	print() // for readability of results
    }

    // Go through each .json file at the given path and parse the information in it.
    // Store the info in a CrudTestFile struct
    private func parseFiles(atPath path: String) throws -> [CrudTestFile] {
		var tests = [CrudTestFile]()
		let testFiles = try FileManager.default.contentsOfDirectory(atPath: path).filter { $0.hasSuffix(".json") }
		for fileName in testFiles {
			let name = fileName.components(separatedBy: ".")[0]
			if skippedFiles.contains(name) { continue }
			let testFilePath = URL(fileURLWithPath: "\(path)/\(fileName)")
			let asDocument = try Document(fromJSONFile: testFilePath)
	        tests.append(try CrudTestFile(fromDocument: asDocument, name: fileName))
		}
		return tests
	}

	// Run all the tests at the /read path
    func testReads() throws {
    	try doTests(forPath: "Tests/Specs/crud/tests/read")
    }

	// Run all the tests at the /write path
    func testWrites() throws {
    	try doTests(forPath: "Tests/Specs/crud/tests/write")
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

/// Initializes a new `CrudTest` of the appropriate subclass from a `Document` 
private func makeCrudTest(_ doc: Document) throws -> CrudTest {
	let operation: Document = try doc.get("operation")
	let opName: String = try operation.get("name")
	guard let type = testTypeMap[opName] else {
		throw TestError(message: "Unknown operation name \(opName)")
	}
	return try type.init(doc)
}

// Maps operation names to the appropriate test class to use for them. 
private var testTypeMap: [String: CrudTest.Type] = [
	"aggregate": AggregateTest.self,
	"count": CountTest.self,
	"deleteMany": DeleteTest.self,
	"deleteOne": DeleteTest.self,
	"distinct": DistinctTest.self,
	"find": FindTest.self,
	"insertMany": InsertManyTest.self,
	"insertOne": InsertOneTest.self,
	"replaceOne": ReplaceOneTest.self,
	"updateMany": UpdateTest.self,
	"updateOne": UpdateTest.self
]

/// An abstract class to represent a single test within a CrudTestFile. Subclasses must
/// implement the `execute` method themselves. 
private class CrudTest {
	let description: String
	let operationName: String
	let args: Document
	let result: BsonValue?
	let collection: Document?
	var collation: Document? { return self.args["collation"] as? Document }
	var sort: Document? { return self.args["sort"] as? Document }
	var skip: Int64? { if let s = self.args["skip"] as? Int { return Int64(s) } else { return nil } }
	var limit: Int64? { if let l = self.args["limit"] as? Int { return Int64(l) } else { return nil } }
	var batchSize: Int32? { if let b = self.args["batchSize"] as? Int { return Int32(b) } else { return nil } }
	var upsert: Bool? { return self.args["upsert"] as? Bool }

	/// Initializes a new `CrudTest` from a `Document`. 
	required init(_ test: Document) throws {
		self.description = try test.get("description")
		let operation: Document = try test.get("operation")
		self.operationName = try operation.get("name")
		self.args = try operation.get("arguments")
		let outcome: Document = try test.get("outcome")
		self.result = outcome["result"]
		self.collection = outcome["collection"] as? Document
	}

	// Subclasses should implement `execute` according to the particular operation(s) they are for. 
	func execute(usingCollection coll: MongoSwift.Collection) throws { XCTFail("Unimplemented") }

	// If the test has a `collection` field in its `outcome`, verify that the expected
	// data is present. If there is no `collection` field, do nothing. 
	func verifyData(testCollection coll: MongoSwift.Collection, db: Database) throws {
		guard let collection = self.collection else { return } // no data to verify
		let expectedData: [Document] = try collection.get("data")
		var collToCheck = coll
		if let name = collection["name"] as? String {
			collToCheck = try db.collection(name)
		}
		let result = Array(try collToCheck.find([:]))
		XCTAssertEqual(result, expectedData)
	}

	// Given an `UpdateResult`, verify that it matches the expected results in this `CrudTest`. 
	// Meant for use by subclasses whose operations return `UpdateResult`s, such as `UpdateTest` 
	// and `ReplaceOneTest`. 
	func verifyUpdateResult(_ result: UpdateResult?) {
		guard let result = result else {
			XCTFail("Missing update result")
			return
		}
		let expected = self.result as? Document
		XCTAssertEqual(result.matchedCount, expected?["matchedCount"] as? Int)
		XCTAssertEqual(result.modifiedCount, expected?["modifiedCount"] as? Int)
		if let id = result.upsertedId as? Int {
			XCTAssertEqual(expected?["upsertedId"] as? Int, id)
		}
	}
}

/// A class for executing `aggregate` tests
private class AggregateTest: CrudTest {
	override func execute(usingCollection coll: MongoSwift.Collection) throws {
		let pipeline: [Document] = try self.args.get("pipeline")
		let options = AggregateOptions(batchSize: self.batchSize, collation: self.collation)
		let cursor = try coll.aggregate(pipeline, options: options)
		if let _ = self.collection {
			// this is $out case, we need to iterate the cursor once in 
			// order to make the aggregation happen
			XCTAssertEqual(cursor.next(), nil)
		} else {
			XCTAssertEqual(Array(cursor), self.result as! [Document])
		}
	}
}

/// A class for executing `count` tests
private class CountTest: CrudTest {
	override func execute(usingCollection coll: MongoSwift.Collection) throws {
		let filter: Document = try self.args.get("filter")
		let options = CountOptions(collation: self.collation, limit: self.limit, skip: self.skip)
		let result = try coll.count(filter, options: options)
		XCTAssertEqual(result, self.result as? Int)
	}
}

/// A class for executing `deleteOne` and `deleteMany` tests
private class DeleteTest: CrudTest {
	override func execute(usingCollection coll: MongoSwift.Collection) throws {
		let filter: Document = try self.args.get("filter")
		// TODO: once CDRIVER-2527 done, send collation here 
		let options = DeleteOptions() // DeleteOptions(collation: self.collation)
		let result: DeleteResult?
		if self.operationName == "deleteOne" {
			result = try coll.deleteOne(filter, options: options)
		} else {
			result = try coll.deleteMany(filter, options: options)
		}
		let expected = self.result as? Document
		XCTAssertEqual(result?.deletedCount, expected?["deletedCount"] as? Int)
	}
}

/// A class for executing `distinct` tests
private class DistinctTest: CrudTest {
	override func execute(usingCollection coll: MongoSwift.Collection) throws {
		let filter = self.args["filter"] as? Document
		let fieldName: String = try self.args.get("fieldName")
		let options = DistinctOptions(collation: self.collation)
		let distinct = try coll.distinct(fieldName: fieldName, filter: filter ?? [:], options: options)
		XCTAssertEqual(distinct.next(), ["values": self.result, "ok": 1.0] as Document)
		XCTAssertNil(distinct.next())
	}
}

/// A class for executing `find` tests
private class FindTest: CrudTest {
	override func execute(usingCollection coll: MongoSwift.Collection) throws {
		let filter: Document = try self.args.get("filter")
		let options = FindOptions(batchSize: batchSize, collation: collation, limit: self.limit,
									skip: self.skip, sort: self.sort)
		let result = try Array(coll.find(filter, options: options))
		XCTAssertEqual(result, self.result as! [Document])
	}
}

/// A class for executing `insertMany` tests
private class InsertManyTest: CrudTest {
	// override func execute(usingCollection coll: MongoSwift.Collection) throws {
	// 	let docs: [Document] = try self.args.get("documents")
	// 	try coll.insertMany(docs)
	// 	//XCTAssertEqual(doc["_id"] as? Int, result?.insertedId as! Int)
	// }
}

/// A Class for executing `insertOne` tests
private class InsertOneTest: CrudTest {
	// override func execute(usingCollection coll: MongoSwift.Collection) throws {
	// 	let doc: Document = try self.args.get("document")
	// 	let result = try coll.insertOne(doc)
	// 	XCTAssertEqual(doc["_id"] as! Int, result?.insertedId as! Int)
	// }
}

/// A class for executing `replaceOne` tests
private class ReplaceOneTest: CrudTest {
	override func execute(usingCollection coll: MongoSwift.Collection) throws {
		let filter: Document = try self.args.get("filter")
		let replacement: Document = try self.args.get("replacement")
		let options = ReplaceOptions(collation: self.collation, upsert: self.upsert)
		let result = try coll.replaceOne(filter: filter, replacement: replacement, options: options)
		self.verifyUpdateResult(result)
	}
}

/// A class for executing `updateOne` and `updateMany` tests
private class UpdateTest: CrudTest {
	override func execute(usingCollection coll: MongoSwift.Collection) throws {
		let filter: Document = try self.args.get("filter")
		let update: Document = try self.args.get("update")
		let arrayFilters = self.args["arrayFilters"] as? [Document]
		let options = UpdateOptions(arrayFilters: arrayFilters, collation: self.collation, upsert: self.upsert)
		let result: UpdateResult?
		if self.operationName == "updateOne" {
			result = try coll.updateOne(filter: filter, update: update, options: options)
		} else {
			result = try coll.updateMany(filter: filter, update: update, options: options)
		}
		self.verifyUpdateResult(result)
	}
}

private struct TestError: LocalizedError {
	var message: String
	public var errorDescription: String { return self.message }
}
