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
        let res = try db.runCommand(command)
        XCTAssertEqual(res["ok"] as? Double, 1.0)
        _ = try db.collection("coll1")

        // create collection using createCollection
        _ = try db.createCollection("coll2")

    	_ = try db.listCollections()

        let opts = ListCollectionsOptions(filter: ["type": "view"] as Document, batchSize: nil, session: nil)
        _ = try db.listCollections(options: opts)

        try db.drop()
        let dbs = try client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
        XCTAssertFalse(dbs.contains {$0["name"] as? String == "testDB"})
    }
}
