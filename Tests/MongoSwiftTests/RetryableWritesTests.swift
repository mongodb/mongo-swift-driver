import Foundation
@testable import MongoSwift
import Nimble
import XCTest

internal struct CollectionTestInfo: Decodable {
    let name: String?
    let data: [Document]
}

internal struct TestOutcome: Decodable {
    var error: Bool? = false
    let result: TestOperationResult?
    let collection: CollectionTestInfo
}

private struct TestRequirement: Decodable {
    let minServerVersion: ServerVersion?
    let maxServerVersion: ServerVersion?
    let topology: [String]?

    func isMet(by version: ServerVersion) -> Bool {
        if let minVersion = self.minServerVersion {
            guard minVersion.isLessThanOrEqualTo(version) else {
                return false
            }
        }
        if let maxVersion = self.maxServerVersion {
            guard maxVersion.isGreaterThanOrEqualTo(version) else {
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

private struct RetryableWritesTest: Decodable {
    let description: String
    let outcome: TestOutcome
    let operation: AnyTestOperation

    let clientOptions: Document?
    let useMultipleMongoses: Bool?
    let failPoint: Document?
}

private struct RetryableWritesTestFile: Decodable {
    private enum CodingKeys: CodingKey {
        case runOn, data, tests
    }

    var name: String = ""
    let runOn: [TestRequirement]?
    let data: [Document]
    let tests: [RetryableWritesTest]
}

final class RetryableWritesTests: MongoSwiftTestCase {
    var failPoint: Document?

    override func tearDown() {
        if let failPoint = self.failPoint {
            do {
                let client = try MongoClient(MongoSwiftTestCase.connStr)
                let adminDb = client.db("admin")
                let cmd = ["configureFailPoint": failPoint["configureFailPoint"]!, "mode": "off"] as Document
                try adminDb.runCommand(cmd)
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
                let client = try MongoClient(MongoSwiftTestCase.connStr, options: ClientOptions(retryWrites: true))
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
                    try client.db("admin").runCommand(commandDoc)
                    self.failPoint = ["configureFailPoint": failPoint["configureFailPoint"]!, "mode": "off"] as Document
                }

                var result: TestOperationResult?
                var seenError: Error?
                do {
                    result = try test.operation.op.run(
                            client: client,
                            database: db,
                            collection: collection,
                            session: nil)
                } catch {
                    if case let ServerError.bulkWriteError(_, _, bulkResult, _) = error {
                        result = TestOperationResult(from: bulkResult)
                    }
                    seenError = error
                }

                if test.outcome.error ?? false {
                    expect(seenError).toNot(beNil(), description: test.description)
                } else {
                    expect(seenError).to(beNil(), description: test.description)
                }

                if let expectedResult = test.outcome.result {
                    expect(result).toNot(beNil(), description: test.description)
                    expect(result).to(equal(expectedResult), description: test.description)
                }
                let verifyColl = db.collection(test.outcome.collection.name ?? collection.name)
                zip(try Array(verifyColl.find()), test.outcome.collection.data).forEach {
                    expect($0).to(sortedEqual($1), description: test.description)
                }

                if let failPoint = self.failPoint {
                    try client.db("admin").runCommand(failPoint)
                }
            }
        }
    }
}
