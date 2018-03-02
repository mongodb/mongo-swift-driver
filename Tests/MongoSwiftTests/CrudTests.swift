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
        self.tests = try tests.map { try CrudTest(fromDocument: $0) }

	}
}

/// A container for one of the tests contained in a .json file. 
private struct CrudTest {
	let description: String
	let operationName: String
	let args: Document
	let result: BsonValue?
	let collection: Document?

	/// Initializes a new `CrudTest` from a `Document`. 
	public init(fromDocument test: Document) throws {
		self.description = try test.getTyped("description")
		let operation: Document = try test.getTyped("operation")
		self.operationName = try operation.getTyped("name")
		self.args = try operation.getTyped("arguments")

		let outcome: Document = try test.getTyped("outcome")
		self.result = outcome["result"]
		self.collection = outcome["collection"] as? Document
	}

	func execute(_ coll: MongoSwift.Collection, database: Database) throws {
		print("------------\nExecuting test: \(self.description)")

		var skip: Int64?
		let skipAsInt = self.args["skip"] as? Int
		if let s = skipAsInt { skip = Int64(s) }

		var limit: Int64?
		let limitAsInt = self.args["limit"] as? Int
		if let l = limitAsInt { limit = Int64(l) }

		let collation = self.args["collation"] as? Document

		var batchSize: Int32?
		let batchSizeAsInt = self.args["batchSize"] as? Int
		if let l = batchSizeAsInt { batchSize = Int32(l) }

		let sort = try self.args["sort"] as? Document

		switch self.operationName {

		case "distinct":
			let filter = try self.args["filter"] as? Document
			let fieldName: String = try self.args.getTyped("fieldName")
			let options = DistinctOptions(collation: collation)
			let distinct = try coll.distinct(fieldName: fieldName, filter: filter ?? [:], options: options)
			XCTAssertEqual(distinct.next(), ["values": self.result, "ok": 1.0] as Document)
			XCTAssertNil(distinct.next())

		case "find":
			let filter: Document = try self.args.getTyped("filter")
			let options = FindOptions(batchSize: batchSize, collation: collation,
									limit: limit, skip: skip, sort: sort)
			let result = try coll.find(filter, options: options)
			let resultArray: [Document] = Array(result)
			XCTAssertEqual(resultArray, self.result as! [Document])

		case "count":
			let filter: Document = try self.args.getTyped("filter")
			let options = CountOptions(collation: collation, limit: limit, skip: skip)
			let result = try coll.count(filter, options: options)
			XCTAssertEqual(result, self.result as? Int)

		case "aggregate":
			let pipeline: [Document] = try self.args.getTyped("pipeline")
			let options = AggregateOptions(batchSize: batchSize, collation: collation)
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

		case "bulkWrite":
			print("bulkWrite")

		case "deleteMany":
			print("deleteMany")

		case "deleteOne":
			print("deleteOne")

		case "findOneAndDelete":
			print("findOneAndDelete")

		case "findOneAndReplace":
			print("findOneAndReplace")

		case "findOneAndUpdate":
			print("findOneAndUpdate")

		case "insertMany":
			print("insertMany")

		case "insertOne":
			print("insertOne")

		case "replaceOne":
			print("replaceOne")

		case "updateMany":
			print("updateMany")

		case "updateOne":
			print("updateOne")

		default:
			XCTFail("Operation name '\(self.operationName)' did not match any expected values")
		}

	}
}

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
    		print("\n\n\n------------\nExecuting tests from file \(forPath)/\(file.name)...")
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
