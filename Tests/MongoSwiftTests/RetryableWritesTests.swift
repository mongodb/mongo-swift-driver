import Foundation
@testable import MongoSwift
import Nimble
import XCTest

/// Struct representing a single test within a spec test JSON file.
private struct RetryableWritesTest: Decodable, SpecTest {
    let description: String
    let outcome: TestOutcome
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
}

/// Struct representing a single retryable-writes spec test JSON file.
private struct RetryableWritesTestFile: Decodable {
    private enum CodingKeys: CodingKey {
        case runOn, data, tests
    }

    /// Name of this test case
    var name: String = ""

    /// Server version and topology requirements in order for tests from this file to be run.
    let runOn: [TestRequirement]?

    /// Data that should exist in the collection before running any of the tests.
    let data: [Document]

    /// List of tests to run in this file.
    let tests: [RetryableWritesTest]
}

final class RetryableWritesTests: MongoSwiftTestCase, FailPointConfigured {
    var activeFailPoint: FailPoint?

    override func tearDown() {
        self.disableActiveFailPoint()
    }

    override func setUp() {
        self.continueAfterFailure = false
    }

    // Teardown at the very end of the suite by dropping the db we tested on.
    override class func tearDown() {
        super.tearDown()
        do {
            try MongoClient().db(self.testDatabase).drop()
        } catch {
            print("Dropping test db \(self.testDatabase) failed: \(error)")
        }
    }

    func testRetryableWrites() throws {
        let testFilesPath = MongoSwiftTestCase.specsPath + "/retryable-writes/tests"
        let testFiles: [String] = try FileManager.default.contentsOfDirectory(atPath: testFilesPath)

        let tests: [RetryableWritesTestFile] = try testFiles.map { fileName in
            let url = URL(fileURLWithPath: "\(testFilesPath)/\(fileName)")
            let data = try String(contentsOf: url).data(using: .utf8)!
            var testFile = try BSONDecoder().decode(RetryableWritesTestFile.self, from: Document(fromJSON: data))
            testFile.name = fileName
            return testFile
        }

        for testFile in tests {
            let setupClient = try MongoClient(MongoSwiftTestCase.connStr)
            let version = try setupClient.serverVersion()

            if let requirements = testFile.runOn {
                guard requirements.contains(where: { $0.isMet(by: version, MongoSwiftTestCase.topologyType) }) else {
                    print("Skipping tests from file \(testFile.name), deployment requirements not met.")
                    continue
                }
            }

            print("\n------------\nExecuting tests from file \(testFilesPath)/\(testFile.name)...\n")
            for test in testFile.tests {
                print("Executing test: \(test.description)")

                let clientOptions = test.clientOptions ?? ClientOptions(retryWrites: true)
                let client = try MongoClient(MongoSwiftTestCase.connStr, options: clientOptions)
                let db = client.db(type(of: self).testDatabase)
                let collection = db.collection(self.getCollectionName(suffix: test.description))

                if !testFile.data.isEmpty {
                    try collection.insertMany(testFile.data)
                }

                if let failPoint = test.failPoint {
                    try self.activateFailPoint(failPoint)
                }
                defer { self.disableActiveFailPoint() }

                try test.run(client: client, db: db, collection: collection, session: nil)
            }
        }
    }
}
