import Foundation
@testable import MongoSwift
import XCTest

final class DatabaseTests: XCTestCase {
    static var allTests: [(String, (DatabaseTests) -> () throws -> Void)] {
        return [
            ("testDatabase", testDatabase)
        ]
    }

    func testDatabase() throws {
		let client = try MongoClient(connectionString: "mongodb://localhost:27017/")
		let db = try client.db("testDB")

        // create collection using runCommand
    	let command: Document = ["create": "coll1"]
    	let res = try db.runCommand(command: command)
    	XCTAssertEqual(res, ["ok": 1.0] as Document)
        let coll1 = try db.collection("coll1")

        // create collection using createCollection
        let coll2 = try db.createCollection("coll2")

    	let collections = try db.listCollections()

        let opts = ListCollectionsOptions(filter: ["type": "view"] as Document, batchSize: nil, session: nil)
        let views = try db.listCollections(options: opts)

        try db.drop()
        let dbs = try client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
        XCTAssertFalse(dbs.contains {$0 as? String == "testDB"})
    }
}
