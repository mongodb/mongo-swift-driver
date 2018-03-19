@testable import MongoSwift
import Nimble
import XCTest

final class ClientTests: XCTestCase {
    static var allTests: [(String, (ClientTests) -> () throws -> Void)] {
        return [
            ("testListDatabases", testListDatabases)
        ]
    }

    func testListDatabases() throws {
        let client = try MongoClient()
        let databases = try client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
        let expectedDbs: [Document] = [["name": "admin"], ["name": "config"], ["name": "local"]]
        expect(Array(databases) as [Document]).to(equal(expectedDbs))
    }
}
