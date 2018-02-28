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
    		let db = try client.db("local")

    		// generate a collection name based on current datetime,
    		// so we won't choose a name that already exists 
    		let coll1name = "coll1" + String(describing: Date())

            // create collection using runCommand
        	let command: Document = ["create": coll1name]
        	let res = try db.runCommand(command: command)
        	XCTAssertEqual(res, ["ok": 1.0] as Document)
            let coll1 = try db.collection(coll1name)

            // create collection using createCollection
            let coll2name = "coll2" + String(describing: Date())
            let coll2 = try db.createCollection(coll2name)

        	let collections = try db.listCollections()

            let opts = ListCollectionsOptions(filter: ["type": "view"] as Document, batchSize: nil, session: nil)
            let views = try db.listCollections(options: opts)

            try coll1.drop()
            try coll2.drop()

    	} catch {
    		XCTFail("Error: \(error)")
    	}
    }
}
