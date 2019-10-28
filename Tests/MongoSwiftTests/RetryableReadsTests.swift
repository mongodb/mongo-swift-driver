import Foundation
import MongoSwift
import Nimble
import XCTest

/// Struct representing a single test within a spec test JSON file.
private struct RetryableReadsTest: SpecTest {
    let description: String

    let operations: [TestOperationDescription]

    let clientOptions: ClientOptions?

    let useMultipleMongoses: Bool?

    let skipReason: String?

    let failPoint: FailPoint?

    let expectations: [TestCommandStartedEvent]?
}

/// Struct representing a single retryable-writes spec test JSON file.
private struct RetryableReadsTestFile: Decodable, SpecTestFile {
    private enum CodingKeys: String, CodingKey {
        case name, runOn, databaseName = "database_name", collectionName = "collection_name", data, tests
    }

    let name: String

    let runOn: [TestRequirement]?

    let databaseName: String

    let collectionName: String?

    let data: TestData

    let tests: [RetryableReadsTest]
}

final class RetryableReadsTests: MongoSwiftTestCase, FailPointConfigured {
    var activeFailPoint: FailPoint?

    override func tearDown() {
        self.disableActiveFailPoint()
    }

    override func setUp() {
        self.continueAfterFailure = false
    }

    func testRetryableReads() throws {
        let skippedTestKeywords = [
            "findOne", // TODO: SWIFT-643: Unskip this test
            "changeStream", // TODO: SWIFT-648: Unskip this test
            "gridfs",
            "count.",
            "count-",
            "mapReduce"
        ]

        let tests = try retrieveSpecTestFiles(specName: "retryable-reads", asType: RetryableReadsTestFile.self)
        for (_, testFile) in tests {
            guard skippedTestKeywords.allSatisfy({ !testFile.name.contains($0) }) else {
                fileLevelLog("Skipping tests from file \(testFile.name)...")
                continue
            }
            try testFile.runTests(parent: self)
        }
    }
}
