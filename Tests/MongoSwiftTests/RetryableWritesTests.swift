import Foundation
import MongoSwift
import Nimble
import XCTest

enum TestOperationResult {
    case cursor(MongoCursor<Document>)
    case document(Document)
    case insertOne(InsertOneResult)
    case insertMany(InsertManyResult)
}

let modelMap = [
    "insertOne": InsertOneModel.self
]

//private struct TestOperation: Decodable {
//    let name: String
//    let arguments: Document?
//
//    func execute(client: MongoClient, db: MongoDatabase, collection: MongoCollection<Document>)
//    throws -> TestOperationResult {
//        switch self.name {
//        case "bulkWrite":
//            guard let requests = self.arguments?["requests"] else {
//                throw UserError.logicError(message: "missing requests field")
//            }
//            let models = try requests.map {
//                guard let requestType = $0["name"], let arguments = $0["arguments"] as? Document else {
//                    throw RuntimeError.internalError(message: "missing request type")
//                }
//                switch requestType {
//                case "insertOne":
//                    return try BSONDecoder().decode(InsertOne.self, from: arguments)
//                default:
//                    throw RuntimeError.internalError(message: "missing stuff")
//                }
//            }
//
//            var options: BulkWriteOptions?
//            if let optionsDoc = self.arguments?["options"] {
//                options = try BSONDecoder().decode(BulkWriteOptions, from: optionsDoc)
//            }
//
//            try collection.bulkWrite(models, options: options)
//        default:
//            throw RuntimeError.internalError(message: "not implemented operation \(self.name) yet")
//        }
//    }
//}

private struct CollectionTestInfo: Decodable {
    let name: String?
    let data: [Document]
}

private struct TestOutcome: Decodable {
    var error: Bool = false
    let result: Document?
    let collection: CollectionTestInfo
}

private struct TestRequirement: Decodable {
    let minServerVersion: ServerVersion?
    let maxServerVersion: ServerVersion?
    let topology: [String]?

    var met: Bool {
        if let minVersion = self.minServerVersion {
            guard minVersion.isLessThanOrEqualTo(MongoSwiftTestCase.serverVersion) else {
                return false
            }
        }
        if let maxVersion = self.maxServerVersion {
            guard maxVersion.isGreaterThanOrEqualTo(MongoSwiftTestCase.serverVersion) else {
                return false
            }
        }
        if let topologies = self.topology {
            guard topologies.contains(MongoSwiftTestCase.topologyType.rawValue) else {
                return false
            }
        }
        return true
    }
}

private struct RetryableWritesTest: Decodable {
    let description: String
    let outcome: Document
    let operation: AnyCRUDOp

    let clientOptions: Document?
    let useMultipleMongoses: Bool?
    let failPoint: Document?
}

private struct RetryableWritesTestFile: Decodable {
    let runOn: [TestRequirement]?
    let data: [Document]
    let tests: [RetryableWritesTest]
}

final class RetryableWritesTests: MongoSwiftTestCase {
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
            return try JSONDecoder().decode(RetryableWritesTestFile.self, from: data)
        }

        for testFile in tests {
            if let requirements = testFile.runOn {
                guard requirements.contains(where: { $0.met }) else {
                    continue
                }
            }

            for test in testFile.tests {
                print("Running \(test.description)")
                let client = try MongoClient(MongoSwiftTestCase.connStr)
                let db = client.db(type(of: self).testDatabase)
                let collection = db.collection(self.getCollectionName(suffix: test.description))

                if let failPoint = test.failPoint {
                    try db.runCommand(failPoint)
                }

                if testFile.data.count > 0 {
                    try collection.insertMany(testFile.data)
                }


            }
        }
    }
}