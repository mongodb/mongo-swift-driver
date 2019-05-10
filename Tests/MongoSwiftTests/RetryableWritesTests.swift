import Foundation
@testable import MongoSwift
import Nimble
import XCTest

private struct TestRequirement: Decodable {
    let minServerVersion: ServerVersion?
    let maxServerVersion: ServerVersion?
    let topology: [String]?

    func isMet(by version: ServerVersion) -> Bool {
        if let minVersion = self.minServerVersion {
            guard minVersion <= version else {
                print("minVersion \(minVersion) > \(version)")
                return false
            }
        }
        if let maxVersion = self.maxServerVersion {
            guard maxVersion >= version else {
                return false
            }
        }
        if let topologies = self.topology?.map({ TopologyDescription.TopologyType(from: $0) }) {
            guard topologies.contains(MongoSwiftTestCase.topologyType) else {
                return false
            }
        }
        return true
    }
}

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

    /// The optional configureFailPoint command document to run to configure a fail point on the primary server.
    /// This option and useMultipleMongoses: true are mutually exclusive.
    let failPoint: Document?
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

final class RetryableWritesTests: MongoSwiftTestCase {
    /// If a failpoint was set on the current test being run, the command in this document will disable it.
    var disableFailPointCommand: Document?

    override func tearDown() {
        if let cmd = self.disableFailPointCommand {
            do {
                let client = try MongoClient(MongoSwiftTestCase.connStr)
                try client.db("admin").runCommand(cmd)
            } catch {
                print("couldn't disable failpoints after failure: \(error)")
            }
        }
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
            var testFile = try JSONDecoder().decode(RetryableWritesTestFile.self, from: data)
            testFile.name = fileName
            return testFile
        }

        for testFile in tests {
            let setupClient = try MongoClient(MongoSwiftTestCase.connStr)
            let version = try setupClient.serverVersion()

            if let requirements = testFile.runOn {
                guard requirements.contains(where: { $0.isMet(by: version) }) else {
                    print("Skipping tests from file \(testFile.name) for server version \(version)")
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
                    // Need to re-order so command is first key
                    var commandDoc = ["configureFailPoint": failPoint["configureFailPoint"]!] as Document
                    for (k, v) in failPoint {
                        guard k != "configureFailPoint" else {
                            continue
                        }

                        // Need to convert error codes to int32's due to c driver bug (CDRIVER-3121)
                        if k == "data", var data = v as? Document,
                           var wcErr = data["writeConcernError"] as? Document,
                           let code = wcErr["code"] as? BSONNumber {
                            wcErr["code"] = code.int32Value
                            data["writeConcernError"] = wcErr
                            commandDoc["data"] = data
                        } else {
                            commandDoc[k] = v
                        }
                    }
                    try setupClient.db("admin").runCommand(commandDoc)
                    self.disableFailPointCommand =
                            ["configureFailPoint": failPoint["configureFailPoint"]!, "mode": "off"] as Document
                }

                try test.run(client: client, db: db, collection: collection)

                if let cmd = self.disableFailPointCommand {
                    try client.db("admin").runCommand(cmd)
                }
            }
        }
    }
}
