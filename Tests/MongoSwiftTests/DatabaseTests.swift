import Foundation
@testable import MongoSwift
import XCTest

final class DatabaseTests: XCTestCase {
    static var allTests: [(String, (DatabaseTests) -> () throws -> Void)] {
        return [
            ("testDatabase", testDatabase)
        ]
    }

    func testDatabase() {
    	do {
    		let client = try Client(connectionString: "mongodb://localhost:27017/")
    		let db = try client.db("test")

    		// generate a collection name based on current datetime,
    		// so we won't choose a name that already exists 
    		let collname = "coll" + String(describing: Date())

        	let command: Document = ["create": collname]
        	let res: Document = try db.runCommand(command: command)

        	XCTAssertEqual(res["ok"] as? Double, 1.0)

        	try db.collection(name: collname)
        	try db.listCollections()

    	} catch {
    		XCTFail("Error: \(error)")
    	}
    }
}
