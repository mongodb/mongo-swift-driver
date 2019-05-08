import Foundation
@testable import MongoSwift

//final class CRUDTests: MongoSwiftTestCase {
//    func testReadOperations() throws {
//        let testFilesPath = MongoSwiftTestCase.specsPath + "/crud/tests/read"
//        try runTests(at: testFilesPath)
//    }
//
//    func testWriteOperations() throws {
//        let testFilesPath = MongoSwiftTestCase.specsPath + "/crud/tests/write"
//        try runTests(at: testFilesPath)
//    }
//
//    func runTests(at path: String) throws {
//        let client = try MongoClient()
//        let db = client.db(type(of: self).testDatabase)
//        defer { try? db.drop() }
//
//        for (fileName, file) in try parseFiles(at: path) {
//            guard try client.serverVersionIsInRange(file.minServerVersion, file.maxServerVersion) else {
//                continue
//            }
//
//            let collection = db.collection(self.getCollectionName(suffix: fileName))
//            try collection.insertMany(file.data)
//
//            // insert data
//            // check server version
//            for test in file.tests {
//                try test.run(using: collection)
//            }
//
//            try collection.drop()
//        }
//    }
//}

//func parseFiles(at path: String) throws -> [(String, CRUDFile)] {
//    let testFiles = try FileManager.default.contentsOfDirectory(atPath: path).filter { $0.hasSuffix(".json") }
//    return try testFiles.map { fileName in
//        let testFilePath = URL(fileURLWithPath: "\(path)/\(fileName)")
//        let document = try Document(fromJSONFile: testFilePath)
//        return (fileName, try BSONDecoder().decode(CRUDFile.self, from: document))
//    }
//}

//struct CRUDFile: Decodable {
//    let data: [Document]
//    let minServerVersion: String?
//    let maxServerVersion: String?
//    let tests: [CRUDTest]
//}
//
//struct CRUDTest: Decodable {
//    let description: String
//    let testCase: CRUDOp
//    let outcome: Document
//
//    private enum CodingKeys: String, CodingKey {
//        case description, operation, outcome
//    }
//
//    private enum NestedCodingKeys: String, CodingKey {
//        case name
//    }
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.description = try container.decode(String.self, forKey: .description)
//        self.outcome = try container.decode(Document.self, forKey: .outcome)
//        let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .operation)
//
//    }
//
//    func run(using collection: MongoCollection<Document>) throws {
//        try self.testCase.run(using: collection)
//    }
//}

protocol BulkWriteResultConvertible {
    var bulkResultValue: BulkWriteResult { get }
}

extension BulkWriteResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult { return self }
}

extension InsertManyResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        return BulkWriteResult(insertedCount: self.insertedCount, insertedIds: self.insertedIds)
    }
}

extension InsertOneResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        return BulkWriteResult(insertedCount: 1, insertedIds: [0: self.insertedId])
    }
}

extension UpdateResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        var upsertedIds: [Int: BSONValue]?
        if let upsertedId = self.upsertedId {
            upsertedIds = [0: upsertedId]
        }

        return BulkWriteResult(matchedCount: self.matchedCount,
                               modifiedCount: self.modifiedCount,
                               upsertedCount: self.upsertedCount,
                               upsertedIds: upsertedIds)
    }
}

extension DeleteResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        return BulkWriteResult(deletedCount: self.deletedCount)
    }
}

enum TestOperationResult: Decodable, Equatable {
    case int(Int)
    case array([BSONValue])
    case document(Document)
    case bulkWrite(BulkWriteResult)

    public init?(from doc: Document?) {
        guard let doc = doc else {
            return nil
        }
        self = .document(doc)
    }

    public init?(from result: BulkWriteResultConvertible?) {
        guard let result = result else {
            return nil
        }
        self = .bulkWrite(result.bulkResultValue)
    }

    public init(from cursor: MongoCursor<Document>) {
        self = .array(cursor.map { $0 })
    }

    public init(from decoder: Decoder) throws {
        if let bulkWriteResult = try? BulkWriteResult(from: decoder) {
            self = .bulkWrite(bulkWriteResult)
        } else if let int = try? Int(from: decoder) {
            self = .int(int)
        } else if let array = try? Array<AnyBSONValue>(from: decoder) {
            self = .array(array.map { $0.value })
        } else if let doc = try? Document(from: decoder) {
            self = .document(doc)
        }
        throw DecodingError.valueNotFound(TestOperationResult.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "couldn't decode outcome"))
    }

    internal static func ==(lhs: TestOperationResult, rhs: TestOperationResult) -> Bool {
        switch (lhs, rhs) {
        case let (.bulkWrite(lhsBw), .bulkWrite(rhsBw)):
            return lhsBw == rhsBw
        case let (.int(lhsInt), .int(rhsInt)):
            return lhsInt == rhsInt
        case let (.array(lhsArray), .array(rhsArray)):
            return zip(lhsArray, rhsArray).allSatisfy { $0.bsonEquals($1) }
        case let(.document(lhsDoc), .document(rhsDoc)):
            return lhsDoc.bsonEquals(rhsDoc)
        default:
            return false
        }
    }
}

protocol TestOperation: Decodable {
    func run(client: MongoClient,
             database: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession?) throws -> TestOperationResult?
}

struct AnyTestOperation: Decodable {
    private enum CodingKeys: String, CodingKey {
        case name
    }

    let op: TestOperation

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let opName = try container.decode(String.self, forKey: .name)
        switch opName {
        case "aggregate":
            self.op = try AggregateOp(from: decoder)
        case "count":
            self.op = try CountTestCase(from: decoder)
        case "distinct":
            self.op = try DistinctTestCase(from: decoder)
        case "find":
            self.op = try FindTestCase(from: decoder)
        case "updateOne", "updateMany":
            self.op = try UpdateTestCase(from: decoder)
        case "insertOne":
            self.op = try InsertOneTestCase(from: decoder)
        case "insertMany":
            self.op = try InsertManyTestCase(from: decoder)
        case "deleteOne", "deleteMany":
            self.op = try DeleteTestCase(from: decoder)
        case "bulkWrite":
            self.op = try BulkWriteTestCase(from: decoder)
        case "findOneAndDelete":
            self.op = try FindOneAndDeleteTestCase(from: decoder)
        case "findOneAndReplace":
            self.op = try FindOneAndReplaceTestCase(from: decoder)
        case "findOneAndUpdate":
            self.op = try FindOneAndUpdateTestCase(from: decoder)
        case "replaceOne":
            self.op = try ReplaceOneTestCase(from: decoder)
        default:
            throw UserError.logicError(message: "unsupported op name \(opName)")
        }
    }
}

enum TestCaseKeys: String, CodingKey { case arguments, name }

struct AggregateOp: TestOperation {
    let pipeline: [Document]
    let options: AggregateOptions

    private enum CodingKeys: String, CodingKey { case pipeline }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(AggregateOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.pipeline = try argumentContainer.decode([Document].self, forKey: .pipeline)
    }

    func run(client: MongoClient,
             database: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.aggregate(pipeline, options: self.options))
    }
}

struct CountTestCase: TestOperation {
    let filter: Document
    let options: CountOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(CountOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
    }

    func run(client: MongoClient,
             database: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession? = nil) throws -> TestOperationResult? {
        return .int(try collection.count(filter, options: self.options))
    }
}

struct DistinctTestCase: TestOperation {
    let fieldName: String
    let options: DistinctOptions

    private enum CodingKeys: String, CodingKey { case fieldName }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(DistinctOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.fieldName = try argumentContainer.decode(String.self, forKey: .fieldName)
    }

    func run(client: MongoClient,
             database: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession? = nil) throws -> TestOperationResult? {
        return .array(try collection.distinct(fieldName: self.fieldName, options: self.options))
    }
}

struct FindTestCase: TestOperation {
    let filter: Document
    let options: FindOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(FindOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.find(self.filter, options: self.options))
    }
}

struct UpdateTestCase: TestOperation {
    let filter: Document
    let update: Document
    let options: UpdateOptions
    let type: UpdateType

    enum UpdateType: String, Decodable {
        case updateOne, updateMany
    }

    private enum CodingKeys: String, CodingKey { case filter, update }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(UpdateOptions.self, forKey: .arguments)
        self.type = try container.decode(UpdateType.self, forKey: .name)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
        self.update = try argumentContainer.decode(Document.self, forKey: .update)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        var result: UpdateResult?
        switch self.type {
        case .updateOne:
            result = try collection.updateOne(filter: self.filter, update: self.update, options: self.options)
        case .updateMany:
            result = try collection.updateMany(filter: self.filter, update: self.update, options: self.options)
        }
        return TestOperationResult(from: result)
    }
}

struct DeleteTestCase: TestOperation {
    let filter: Document
    let options: DeleteOptions
    let type: DeleteType

    enum DeleteType: String, Decodable {
        case deleteOne, deleteMany
    }

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(DeleteOptions.self, forKey: .arguments)
        self.type = try container.decode(DeleteType.self, forKey: .name)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        var result: DeleteResult?
        switch self.type {
        case .deleteOne:
            result = try collection.deleteOne(self.filter, options: self.options)
        case .deleteMany:
            result = try collection.deleteMany(self.filter, options: self.options)
        }
        return TestOperationResult(from: result)
    }
}

struct InsertOneTestCase: TestOperation {
    let document: Document

    private enum CodingKeys: String, CodingKey { case document }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.document = try argumentContainer.decode(Document.self, forKey: .document)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.insertOne(self.document))
    }
}

struct InsertManyTestCase: TestOperation {
    let documents: [Document]
    let options: InsertManyOptions

    private enum CodingKeys: String, CodingKey { case arguments }
    private enum NestedCodingKeys: String, CodingKey { case documents, options }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argumentContainer = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .arguments)
        self.documents = try argumentContainer.decode([Document].self, forKey: .documents)
        self.options = try argumentContainer.decode(InsertManyOptions.self, forKey: .options)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.insertMany(self.documents, options: self.options))
    }
}

struct BulkWriteTestCase: TestOperation {
    let requests: [Document]
    let options: BulkWriteOptions

    private enum CodingKeys: String, CodingKey { case arguments }
    private enum NestedCodingKeys: String, CodingKey { case requests, options }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argumentContainer = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .arguments)
        self.requests = try argumentContainer.decode([Document].self, forKey: .requests)
        self.options = try argumentContainer.decode(BulkWriteOptions.self, forKey: .options)
    }

    func run(client: MongoClient,
             database: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession? = nil) throws -> TestOperationResult? {
        throw RuntimeError.internalError(message: "asdf")
    }
}

struct FindOneAndUpdateTestCase: TestOperation {
    let filter: Document
    let update: Document
    let options: FindOneAndUpdateOptions

    private enum CodingKeys: String, CodingKey { case filter, update }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(FindOneAndUpdateOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
        self.update = try argumentContainer.decode(Document.self, forKey: .update)
    }

    func run(client: MongoClient,
             database: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(
                from: try collection.findOneAndUpdate(filter: self.filter, update: self.update, options: self.options))
    }
}

struct FindOneAndDeleteTestCase: TestOperation {
    let filter: Document
    let options: FindOneAndDeleteOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(FindOneAndDeleteOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.findOneAndDelete(self.filter, options: self.options))
    }
}

struct FindOneAndReplaceTestCase: TestOperation {
    let filter: Document
    let replacement: Document
    let options: FindOneAndReplaceOptions

    private enum CodingKeys: String, CodingKey { case filter, replacement }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(FindOneAndReplaceOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
        self.replacement = try argumentContainer.decode(Document.self, forKey: .replacement)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.findOneAndReplace(filter: self.filter,
                                                                          replacement: self.replacement,
                                                                          options: self.options))
    }
}

struct ReplaceOneTestCase: TestOperation {
    let filter: Document
    let replacement: Document
    let options: ReplaceOptions

    private enum CodingKeys: String, CodingKey { case filter, replacement }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestCaseKeys.self)
        self.options = try container.decode(ReplaceOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
        self.replacement = try argumentContainer.decode(Document.self, forKey: .replacement)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.replaceOne(filter: self.filter,
                                                                   replacement: self.replacement,
                                                                   options: self.options))
    }
}
