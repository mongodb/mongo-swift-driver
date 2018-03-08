import Foundation
@testable import MongoSwift
import XCTest

final class ClientTests: XCTestCase {
    static var allTests: [(String, (ClientTests) -> () throws -> Void)] {
        return [
            ("testListDatabases", testListDatabases)
        ]
    }

    func testListDatabases() {
        guard let client = try? MongoClient(connectionString: "mongodb://localhost:27017/") else {
            XCTAssert(false, "failed to create a client")
            return
        }

        guard let databases = try? client.listDatabases(options: ListDatabasesOptions(nameOnly: true)) else {
            XCTAssert(false, "failed to list databases")
            return
        }

        // swiftlint:disable:next force_cast
        let dbNames: [String] = Array(databases).map { $0["name"] as! String }
        XCTAssertTrue(dbNames.contains("admin"))
    }
}
