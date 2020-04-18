import Foundation
import MongoSwiftSync
import Nimble
import TestsCommon

/// Struct representing a single test within a retryable-writes spec test JSON file.
private struct RetryableWritesTest: Decodable, FailPointConfigured {
    /// Description of the test.
    let description: String

    /// The expected outcome of executing the operation.
    let outcome: TestOutcome

    /// The operation to execute as part of this test case.
    let operation: AnyTestOperation

    /// Options used to configure the `MongoClient` used for this test.
    let clientOptions: ClientOptions?

    /// If true, the `MongoClient` for this test should be initialized with multiple mongos seed addresses.
    /// If false or omitted, only a single mongos address should be specified.
    /// This field has no effect for non-sharded topologies.
    let useMultipleMongoses: Bool?

    /// The optional fail point to configure before running this test.
    /// This option and useMultipleMongoses: true are mutually exclusive.
    let failPoint: FailPoint?

    var activeFailPoint: FailPoint?
}

/// Struct representing a single retryable-writes spec test JSON file.
private struct RetryableWritesTestFile: Decodable {
    private enum CodingKeys: CodingKey {
        case runOn, data, tests
    }

    /// Server version and topology requirements in order for tests from this file to be run.
    let runOn: [TestRequirement]?

    /// Data that should exist in the collection before running any of the tests.
    let data: [Document]

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
            let version = try setupClient.serverVersion()

            if let requirements = testFile.runOn {
                guard requirements.contains(where: { $0.isMet(by: version, MongoSwiftTestCase.topologyType) }) else {
                    fileLevelLog("Skipping tests from file \(fileName), deployment requirements not met.")
                    continue
                }
            }

            fileLevelLog("Executing tests from file \(fileName)...\n")
            for var test in testFile.tests {
                print("Executing test: \(test.description)")

                let clientOptions = test.clientOptions ?? ClientOptions(retryWrites: true)
                let client = try MongoClient.makeTestClient(options: clientOptions)
                let db = client.db(Self.testDatabase)
                let collection = db.collection(self.getCollectionName(suffix: test.description))

                if !testFile.data.isEmpty {
                    try collection.insertMany(testFile.data)
                }

                if let failPoint = test.failPoint {
                    try test.activateFailPoint(failPoint)
                }
                defer { test.disableActiveFailPoint() }

                var result: TestOperationResult?
                var seenError: Error?

                do {
                    result = try test.operation.op.execute(
                        on: collection,
                        sessions: [:]
                    )
                } catch {
                    if let bulkError = error as? BulkWriteError {
                        result = bulkError.result.map(TestOperationResult.bulkWrite)
                    }
                    seenError = error
                }

                if test.outcome.error ?? false {
                    expect(seenError).toNot(beNil(), description: test.description)
                } else {
                    expect(seenError).to(beNil(), description: test.description)
                }

                if let expectedResult = test.outcome.result {
                    expect(result).toNot(beNil())
                    expect(result).to(equal(expectedResult))
                }

                let verifyColl = db.collection(test.outcome.collection.name ?? collection.name)
                let foundDocs = try Array(verifyColl.find().all())
                expect(foundDocs.count).to(equal(test.outcome.collection.data.count))
                zip(foundDocs, test.outcome.collection.data).forEach {
                    expect($0).to(sortedEqual($1), description: test.description)
                }
            }
        }
    }
}
