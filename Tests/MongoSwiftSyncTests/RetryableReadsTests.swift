import Foundation
import MongoSwift
import Nimble
import TestsCommon

/// Struct representing a single test within a spec test JSON file.
private struct RetryableReadsTest: SpecTest {
    let description: String

    let operations: [TestOperationDescription]

    let clientOptions: ClientOptions?

    let useMultipleMongoses: Bool?

    let skipReason: String?

    let failPoint: FailPoint?

    let expectations: [TestCommandStartedEvent]?

    var activeFailPoint: FailPoint?
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

    static let skippedTestFileNameKeywords = [
        "changeStream", // TODO: SWIFT-648: Unskip this test
        "gridfs",
        "count.",
        "count-",
        "mapReduce"
    ]
}

final class RetryableReadsTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testRetryableReads() throws {
        let tests = try retrieveSpecTestFiles(specName: "retryable-reads", asType: RetryableReadsTestFile.self)
        for (_, testFile) in tests {
            try testFile.runTests()
        }
    }
}
