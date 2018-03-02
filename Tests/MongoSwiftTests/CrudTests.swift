@testable import MongoSwift
import Foundation
import XCTest

struct TypeError: LocalizedError {
	let message: String
	public var errorDescription: String? { return message }
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
		// set up server versions, if applicable 
		self.minServerVersion = document["minServerVersion"] as? String
		self.maxServerVersion = document["maxServerVersion"] as? String
		self.name = name

        self.data = try document.getTyped("data")

        let tests: [Document] = try document.getTyped("tests")
        self.tests = try tests.map { try makeCrudTest($0) }

	}
}

private func makeCrudTest(_ doc: Document) throws -> CrudTest {
	let operation: Document = try doc.getTyped("operation")
	let opName: String = try operation.getTyped("name")
	switch opName {
	case "aggregate":
		return try AggregateTest(doc)
	case "bulkWrite":
		return try BulkWriteTest(doc)
	case "count":
		return try CountTest(doc)
	case "deleteMany":
		return try DeleteManyTest(doc)
	case "deleteOne":
		return try DeleteOneTest(doc)
	case "distinct":
		return try DistinctTest(doc)
	case "find":
		return try FindTest(doc)
	case "findOneAndDelete":
		return try FindOneAndDeleteTest(doc)
	case "findOneAndReplace":
		return try FindOneAndReplaceTest(doc)
	case "findOneAndUpdate":
		return try FindOneAndUpdateTest(doc)
	case "insertMany":
		return try InsertManyTest(doc)
	case "insertOne":
		return try InsertOneTest(doc)
	case "replaceOne":
		return try ReplaceOneTest(doc)
	case "updateMany":
		return try UpdateManyTest(doc)
	case "updateOne":
		return try UpdateOneTest(doc)
	default:
		return try CrudTest(doc)
	}
}

private class CrudTest {

	let description: String
	let operationName: String
	let args: Document
	let result: BsonValue?
	let collection: Document?

	var collation: Document? { return self.args["collation"] as? Document }

	var skip: Int64? {
		let skipAsInt = self.args["skip"] as? Int
		if let s = skipAsInt { return Int64(s) }
		return nil
	}

	var limit: Int64? {
		let limitAsInt = self.args["limit"] as? Int
		if let l = limitAsInt { return Int64(l) }
		return nil
	}

	var batchSize: Int32? {
		let batchSizeAsInt = self.args["batchSize"] as? Int
		if let b = batchSizeAsInt { return Int32(b) }
		return nil
	}

	var sort: Document? { return self.args["sort"] as? Document }

	func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		XCTFail("Unimplemented")
	}

	/// Initializes a new `CrudTest` from a `Document`. 
	public init(_ test: Document) throws {
		self.description = try test.getTyped("description")
		let operation: Document = try test.getTyped("operation")
		self.operationName = try operation.getTyped("name")
		self.args = try operation.getTyped("arguments")

		let outcome: Document = try test.getTyped("outcome")
		self.result = outcome["result"]
		self.collection = outcome["collection"] as? Document
	}

}

private class AggregateTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let pipeline: [Document] = try self.args.getTyped("pipeline")
		let options = AggregateOptions(batchSize: self.batchSize, collation: self.collation)
		let result = try coll.aggregate(pipeline, options: options)
		if let coll = self.collection {
			let expectedData: [Document] = try coll.getTyped("data")
			if let name = coll["name"] as? String {
				let testColl = try database.collection(name)
				let results = try testColl.find([:])
				let resultsArray = Array(results)
				//XCTAssertEqual(resultsArray, expectedData)
			} else {

			}
		} else {
			let resultArray: [Document] = Array(result)
			XCTAssertEqual(resultArray, self.result as! [Document])
		}
	}
}

private class BulkWriteTest: CrudTest {}

private class CountTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let filter: Document = try self.args.getTyped("filter")
		let options = CountOptions(collation: self.collation, limit: self.limit, skip: self.skip)
		let result = try coll.count(filter, options: options)
		XCTAssertEqual(result, self.result as? Int)
	}
}

private class DeleteManyTest: CrudTest {}
private class DeleteOneTest: CrudTest {}

private class DistinctTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		let filter = try self.args["filter"] as? Document
		let fieldName: String = try self.args.getTyped("fieldName")
		let options = DistinctOptions(collation: self.collation)
		let distinct = try coll.distinct(fieldName: fieldName, filter: filter ?? [:], options: options)
		XCTAssertEqual(distinct.next(), ["values": self.result, "ok": 1.0] as Document)
		XCTAssertNil(distinct.next())
	}
}

private class FindTest: CrudTest {
	override func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		print("Executing test: \(self.description)")
		let filter: Document = try self.args.getTyped("filter")
		let options = FindOptions(batchSize: batchSize, collation: collation, limit: self.limit, skip: self.skip, sort: self.sort)
		let result = try coll.find(filter, options: options)
		let resultArray: [Document] = Array(result)
		XCTAssertEqual(resultArray, self.result as! [Document])
	}
}

private class FindOneAndDeleteTest: CrudTest {}
private class FindOneAndReplaceTest: CrudTest {}
private class FindOneAndUpdateTest: CrudTest {}
private class InsertManyTest: CrudTest {}
private class InsertOneTest: CrudTest {}
private class ReplaceOneTest: CrudTest {}
private class UpdateManyTest: CrudTest {}
private class UpdateOneTest: CrudTest {}

private func parseFiles(atPath path: String) throws -> [CrudTestFile] {
	var tests = [CrudTestFile]()
	let testFiles = try FileManager.default.contentsOfDirectory(atPath: path).filter { $0.hasSuffix(".json") }
	for fileName in testFiles {
		let testFilePath = URL(fileURLWithPath: "\(path)/\(fileName)")
        let testFileData = try String(contentsOf: testFilePath, encoding: .utf8)
        guard let document = try? Document(fromJSON: testFileData) else {
        	XCTFail("Unable to create document from test file at \(testFilePath)")
        	return []
        }
        let asStruct = try CrudTestFile(fromDocument: document, name: fileName)
        tests.append(asStruct)
	}
	return tests
}

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
            let db = try Client().db("crudTests")
            try db.drop()
        } catch {
            XCTFail("Dropping test database crudTests failed: \(error)")
        }
    }

    func doTest(forPath: String) throws {
    	let db = try Client().db("crudTests")
    	let testFiles = try parseFiles(atPath: forPath)
    	for file in testFiles {
    		let collection = try db.collection("\(file.name.components(separatedBy: ".")[0])")
    		try collection.insertMany(file.data)
    		print("\n------------\nExecuting tests from file \(forPath)/\(file.name)...\n")
    		for test in file.tests {
    			try test.execute(collection, database: db)
    		}
    	}
    }

    func testReads() throws {
    	try doTest(forPath: "Tests/Specs/crud/tests/read")
    }

    func testWrites() throws {
    	try doTest(forPath: "Tests/Specs/crud/tests/write")
    }

}
