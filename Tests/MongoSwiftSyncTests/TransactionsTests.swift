import Foundation
import MongoSwift
import Nimble
import TestsCommon

/// Struct representing a single test within a spec test JSON file.
private struct TransactionsTest: SpecTest {
    let description: String

    let operations: [TestOperationDescription]

    let outcome: TestOutcome?

    let skipReason: String?

    let useMultipleMongoses: Bool?

    let clientOptions: MongoClientOptions?

    let failPoint: FailPoint?

    let sessionOptions: [String: ClientSessionOptions]?

    let expectations: [TestCommandStartedEvent]?

    var activeFailPoint: FailPoint?
    var targetedHost: ServerAddress?

    static let sessionNames: [String] = ["session0", "session1"]

    static let skippedTestKeywords: [String] = []
}

/// Struct representing a single transactions spec test JSON file.
private struct TransactionsTestFile: Decodable, SpecTestFile {
    private enum CodingKeys: String, CodingKey {
        case name, runOn, databaseName = "database_name", collectionName = "collection_name", data, tests
    }

    let name: String

    let runOn: [TestRequirement]?

    let databaseName: String

    let collectionName: String?

    let data: TestData

    let tests: [TransactionsTest]

    static let skippedTestFileNameKeywords: [String] = [
        "count" // old count API was deprecated before MongoDB 4.0 and is not supported by the driver
    ]
}

final class TransactionsTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testTransactionsLegacy() throws {
        let tests = try retrieveSpecTestFiles(
            specName: "transactions",
            subdirectory: "legacy",
            asType: TransactionsTestFile.self
        )
        for (_, testFile) in tests {
            try testFile.runTests()
        }
    }

    func testTransactionsUnified() throws {
        let files = try retrieveSpecTestFiles(
            specName: "transactions",
            subdirectory: "unified",
            asType: UnifiedTestFile.self
        )
        let runner = try UnifiedTestRunner()
        try runner.runFiles(files.map { $0.1 })
    }
}
