import Foundation
@testable import struct MongoSwift.MongoClientOptions
import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

/// Struct representing a single test within a retryable-writes spec test JSON file.
private struct RetryableWritesTest: Decodable, FailPointConfigured {
    /// Description of the test.
    let description: String

    /// The expected outcome of executing the operation.
    let outcome: TestOutcome

    /// The operation to execute as part of this test case.
    let operation: AnyTestOperation

    /// Options used to configure the `MongoClient` used for this test.
    let clientOptions: MongoClientOptions?

    /// If true, the `MongoClient` for this test should be initialized with multiple mongos seed addresses.
    /// If false or omitted, only a single mongos address should be specified.
    /// This field has no effect for non-sharded topologies.
    let useMultipleMongoses: Bool?

    /// The optional fail point to configure before running this test.
    /// This option and useMultipleMongoses: true are mutually exclusive.
    let failPoint: FailPoint?

    var activeFailPoint: FailPoint?
    var targetedHost: ServerAddress?
}

/// Struct representing a single retryable-writes spec test JSON file.
private struct RetryableWritesTestFile: Decodable {
    private enum CodingKeys: CodingKey {
        case runOn, data, tests
    }

    /// Server version and topology requirements in order for tests from this file to be run.
    let runOn: [TestRequirement]?

    /// Data that should exist in the collection before running any of the tests.
    let data: [BSONDocument]

    /// List of tests to run in this file.
    let tests: [RetryableWritesTest]
}

final class RetryableWritesTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    // Teardown at the very end of the suite by dropping the db we tested on.
    override class func tearDown() {
        super.tearDown()
        do {
            try MongoClient.makeTestClient().db(self.testDatabase).drop()
        } catch {
            print("Dropping test db \(self.testDatabase) failed: \(error)")
        }
    }

    func testRetryableWrites() throws {
        let tests = try retrieveSpecTestFiles(specName: "retryable-writes", asType: RetryableWritesTestFile.self)
        for (fileName, testFile) in tests {
            let setupClient = try MongoClient.makeTestClient()

            if let requirements = testFile.runOn {
                guard try requirements.contains(where: {
                    try setupClient.getUnmetRequirement($0) == nil
                }) else {
                    fileLevelLog("Skipping tests from file \(fileName), deployment requirements not met.")
                    continue
                }
            }

            fileLevelLog("Executing tests from file \(fileName)...\n")
            for var test in testFile.tests {
                print("Executing test: \(test.description)")

                var clientOptions = test.clientOptions ?? MongoClientOptions()
                clientOptions.minHeartbeatFrequencyMS = 50
                clientOptions.heartbeatFrequencyMS = 50
                let client = try MongoClient.makeTestClient(options: clientOptions)
                let db = client.db(Self.testDatabase)
                let collection = db.collection(self.getCollectionName(suffix: test.description))
                defer { try? collection.drop() }

                if !testFile.data.isEmpty {
                    try collection.insertMany(testFile.data)
                }

                if let failPoint = test.failPoint {
                    try test.activateFailPoint(failPoint, using: setupClient)
                }
                defer { test.disableActiveFailPoint(using: setupClient) }

                var result: TestOperationResult?
                var seenError: Error?

                do {
                    result = try test.operation.op.execute(
                        on: collection,
                        sessions: [:]
                    )
                } catch {
                    if let bulkError = error as? MongoError.BulkWriteError {
                        result = bulkError.result.map(TestOperationResult.bulkWrite)
                    }
                    seenError = error
                }

                if test.outcome.error ?? false {
                    guard let error = seenError else {
                        XCTFail("\(test.description): expected to get an error but got nil")
                        continue
                    }
                    if case let .error(errorResult) = test.outcome.result {
                        errorResult.checkErrorResult(error, description: test.description)
                    }
                } else {
                    expect(seenError).to(beNil(), description: test.description)
                    if let expectedResult = test.outcome.result {
                        expect(result).toNot(beNil())
                        expect(result).to(equal(expectedResult))
                    }
                }

                let verifyColl = db.collection(test.outcome.collection.name ?? collection.name)
                let foundDocs = try verifyColl.find().all()
                expect(foundDocs.count).to(equal(test.outcome.collection.data.count))
                zip(foundDocs, test.outcome.collection.data).forEach {
                    expect($0).to(sortedEqual($1), description: test.description)
                }
            }
        }
    }
}
