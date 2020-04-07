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

    let clientOptions: TestClientOptions?

    let failPoint: FailPoint?

    let sessionOptions: [String: ClientSessionOptions]?

    let expectations: [TestCommandStartedEvent]?

    static let sessionNames: [String] = ["session0", "session1"]
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
}

final class TransactionsTests: MongoSwiftTestCase, FailPointConfigured {
    var activeFailPoint: FailPoint?

    override func tearDown() {
        self.disableActiveFailPoint()
    }

    override func setUp() {
        self.continueAfterFailure = false
    }

    func testTransactions() throws {
        let skippedTestKeywords = [
            "count", // skipped in RetryableReadsTests.swift
            "mongos-pin-auto", // useMultipleMongoses, targetedFailPoint not implemented
            "mongos-recovery-token", // useMultipleMongoses, targetedFailPoint not implemented
            "pin-mongos", // useMultipleMongoses, targetedFailPoint not implemented
            "retryable-abort-errorLabels", // requires libmongoc v1.17 (see SWIFT-762)
            "retryable-commit-errorLabels" // requires libmongoc v1.17 (see SWIFT-762)
        ]

        let tests = try retrieveSpecTestFiles(specName: "transactions", asType: TransactionsTestFile.self)
        for (_, testFile) in tests {
            guard skippedTestKeywords.allSatisfy({ !testFile.name.contains($0) }) else {
                fileLevelLog("Skipping tests from file \(testFile.name)...")
                continue
            }
            try testFile.runTests(parent: self)
        }
    }
}
