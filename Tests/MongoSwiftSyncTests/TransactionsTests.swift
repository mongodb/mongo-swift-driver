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

    let clientOptions: ClientOptions?

    let failPoint: FailPoint?

    let sessionOptions: [String: ClientSessionOptions]?

    let expectations: [TestCommandStartedEvent]?

    var activeFailPoint: FailPoint?

    static let sessionNames: [String] = ["session0", "session1"]

    static let skippedTestKeywords: [String] = [
        // TODO: SWIFT-762 the following 3 require libmongoc v1.17
        "RetryableWriteError",
        "commitTransaction fails after two errors",
        "commitTransaction applies majority write concern on retries"
    ]
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

    func testTransactions() throws {
        let tests = try retrieveSpecTestFiles(specName: "transactions", asType: TransactionsTestFile.self)
        for (_, testFile) in tests {
            try testFile.runTests()
        }
    }
}
