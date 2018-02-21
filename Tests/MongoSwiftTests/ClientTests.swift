import Foundation
@testable import MongoSwift
import XCTest

final class ClientTests: XCTestCase {
    static var allTests: [(String, (ClientTests) -> () throws -> Void)] {
        return [
            ("testClient", testClient),
            ("testListDatabases", testListDatabases)
        ]
    }

    func testClient() {
        guard let client = try? Client(connectionString: "mongodb://localhost:27017/") else {
            XCTAssert(false, "failed to create a client")
            return
        }

        guard let databases = try? client.listDatabases() else {
            XCTAssert(false, "failed to list databases")
        }
    }

    func testListDatabases() {
        guard let client = try? Client(connectionString: "mongodb://localhost:27017/") else {
            XCTAssert(false, "failed to create a client")
            return
        }

        guard let databases = try? client.listDatabases(options: ListDatabasesOptions(nameOnly: true)) else {
            XCTAssert(false, "failed to list databases")
            return
        }

        XCTAssertEqual(Array(databases) as [Document], [
            ["name": "admin"] as Document,
            ["name": "config"] as Document,
            ["name": "local"] as Document
        ])
    }
}
