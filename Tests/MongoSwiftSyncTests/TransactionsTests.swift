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
            "retryable-abort-errorLabels", // requires libmongoc v1.17 (see CDRIVER-3462)
            "retryable-commit-errorLabels" // requires libmongoc v1.17 (see CDRIVER-3462)
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

extension DatabaseOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try? container.decode(ReadConcern.self, forKey: .readConcern)
        let readPreference = try? container.decode(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try? container.decode(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, readPreference: readPreference, writeConcern: writeConcern)
    }

    private enum CodingKeys: CodingKey {
        case readConcern, readPreference, writeConcern
    }
}

extension CollectionOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try? container.decode(ReadConcern.self, forKey: .readConcern)
        let writeConcern = try? container.decode(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, writeConcern: writeConcern)
    }

    private enum CodingKeys: CodingKey {
        case readConcern, writeConcern
    }
}

extension ClientSessionOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let causalConsistency = try? container.decode(Bool.self, forKey: .causalConsistency)
        let defaultTransactionOptions = try? container.decode(
            TransactionOptions.self,
            forKey: .defaultTransactionOptions
        )
        self.init(causalConsistency: causalConsistency, defaultTransactionOptions: defaultTransactionOptions)
    }

    private enum CodingKeys: CodingKey {
        case causalConsistency, defaultTransactionOptions
    }
}

extension TransactionOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let maxCommitTimeMS = try? container.decode(Int64.self, forKey: .maxCommitTimeMS)
        let readConcern = try? container.decode(ReadConcern.self, forKey: .readConcern)
        let readPreference = try? container.decode(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try? container.decode(WriteConcern.self, forKey: .writeConcern)
        self.init(
            maxCommitTimeMS: maxCommitTimeMS,
            readConcern: readConcern,
            readPreference: readPreference,
            writeConcern: writeConcern
        )
    }

    private enum CodingKeys: CodingKey {
        case maxCommitTimeMS, readConcern, readPreference, writeConcern
    }
}
