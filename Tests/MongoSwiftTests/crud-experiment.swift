import Foundation
@testable import MongoSwift
import Nimble
import XCTest

protocol SpecTest {
    var description: String { get }
    var outcome: TestOutcome { get }
    var operation: AnyTestOperation { get }

    func execute(dbName: String, collectionName: String) throws
}

extension SpecTest {
    internal func execute(client: MongoClient, db: MongoDatabase, collection: MongoCollection<Document>) throws {
        print("Executing test: \(self.description)")
        var result: TestOperationResult?
        var seenError: Error?
        do {
            result = try self.operation.op.run(
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

        if self.outcome.error ?? false {
            expect(seenError).toNot(beNil(), description: self.description)
        } else {
            expect(seenError).to(beNil(), description: self.description)
        }

        if let expectedResult = self.outcome.result {
            expect(result).toNot(beNil(), description: self.description)
            expect(result).to(equal(expectedResult), description: self.description)
        }
        let verifyColl = db.collection(self.outcome.collection.name ?? collection.name)
        zip(try Array(verifyColl.find()), self.outcome.collection.data).forEach {
            expect($0).to(sortedEqual($1), description: self.description)
        }
    }
}

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
        if let insertOneResult = try? InsertOneResult(from: decoder) {
            self = .bulkWrite(insertOneResult.bulkResultValue)
        } else if let updateResult = try? UpdateResult(from: decoder), updateResult.upsertedId != nil {
            self = .bulkWrite(updateResult.bulkResultValue)
        } else if let bulkWriteResult = try? BulkWriteResult(from: decoder) {
            self = .bulkWrite(bulkWriteResult)
        } else if let int = try? Int(from: decoder) {
            self = .int(int)
        } else if let array = try? [AnyBSONValue](from: decoder) {
            self = .array(array.map { $0.value })
        } else if let doc = try? Document(from: decoder) {
            self = .document(doc)
        } else {
            throw DecodingError.valueNotFound(TestOperationResult.self,
                                              DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "couldn't decode outcome")
            )
        }
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
            return lhsDoc.sortedEquals(rhsDoc)
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
            self.op = try Aggregate(from: decoder)
        case "count":
            self.op = try Count(from: decoder)
        case "distinct":
            self.op = try Distinct(from: decoder)
        case "find":
            self.op = try Find(from: decoder)
        case "updateOne", "updateMany":
            self.op = try Update(from: decoder)
        case "insertOne":
            self.op = try InsertOne(from: decoder)
        case "insertMany":
            self.op = try InsertMany(from: decoder)
        case "deleteOne", "deleteMany":
            self.op = try Delete(from: decoder)
        case "bulkWrite":
            self.op = try BulkWrite(from: decoder)
        case "findOneAndDelete":
            self.op = try FindOneAndDelete(from: decoder)
        case "findOneAndReplace":
            self.op = try FindOneAndReplace(from: decoder)
        case "findOneAndUpdate":
            self.op = try FindOneAndUpdate(from: decoder)
        case "replaceOne":
            self.op = try ReplaceOne(from: decoder)
        default:
            throw UserError.logicError(message: "unsupported op name \(opName)")
        }
    }
}

enum TestOperationKeys: String, CodingKey { case arguments, name }

struct Aggregate: TestOperation {
    let pipeline: [Document]
    let options: AggregateOptions

    private enum CodingKeys: String, CodingKey { case pipeline }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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

struct Count: TestOperation {
    let filter: Document
    let options: CountOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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

struct Distinct: TestOperation {
    let fieldName: String
    let options: DistinctOptions

    private enum CodingKeys: String, CodingKey { case fieldName }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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

struct Find: TestOperation {
    let filter: Document
    let options: FindOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
        self.options = try container.decode(FindOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.find(self.filter, options: self.options))
    }
}

struct Update: TestOperation {
    let filter: Document
    let update: Document
    let options: UpdateOptions
    let type: UpdateType

    enum UpdateType: String, Decodable {
        case updateOne, updateMany
    }

    private enum CodingKeys: String, CodingKey { case filter, update }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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

struct Delete: TestOperation {
    let filter: Document
    let options: DeleteOptions
    let type: DeleteType

    enum DeleteType: String, Decodable {
        case deleteOne, deleteMany
    }

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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

struct InsertOne: TestOperation {
    let document: Document

    private enum CodingKeys: String, CodingKey { case document }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.document = try argumentContainer.decode(Document.self, forKey: .document)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.insertOne(self.document))
    }
}

struct InsertMany: TestOperation {
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

struct BulkWriteRequest: Decodable {
    let model: WriteModel
    let name: String

    private enum CodingKeys: CodingKey {
        case name, arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        switch self.name {
        case "insertOne":
            self.model = try container.decode(InsertOneModel.self, forKey: .arguments)
        case "deleteOne":
            self.model = try container.decode(DeleteOneModel.self, forKey: .arguments)
        case "deleteMany":
            self.model = try container.decode(DeleteManyModel.self, forKey: .arguments)
        case "replaceOne":
            self.model = try container.decode(ReplaceOneModel.self, forKey: .arguments)
        case "updateOne":
            self.model = try container.decode(UpdateOneModel.self, forKey: .arguments)
        case "updateMany":
            self.model = try container.decode(UpdateManyModel.self, forKey: .arguments)
        default:
            throw DecodingError.typeMismatch(WriteModel.self,
                                             DecodingError.Context(
                                                     codingPath: decoder.codingPath,
                                                     debugDescription: "Malformatted bulk request")
            )
        }
    }
}

struct BulkWrite: TestOperation {
    let requests: [BulkWriteRequest]
    let options: BulkWriteOptions

    private enum CodingKeys: String, CodingKey { case arguments }
    private enum NestedCodingKeys: String, CodingKey { case requests, options }


    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argumentContainer = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .arguments)
        self.requests = try argumentContainer.decode([BulkWriteRequest].self, forKey: .requests)
        self.options = try argumentContainer.decode(BulkWriteOptions.self, forKey: .options)
    }

    func run(client: MongoClient,
             database: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession? = nil) throws -> TestOperationResult? {
        let models = self.requests.map { $0.model }
        return TestOperationResult(from: try collection.bulkWrite(models, options: self.options))
    }
}

struct FindOneAndUpdate: TestOperation {
    let filter: Document
    let update: Document
    let options: FindOneAndUpdateOptions

    private enum CodingKeys: String, CodingKey { case filter, update }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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

struct FindOneAndDelete: TestOperation {
    let filter: Document
    let options: FindOneAndDeleteOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
        self.options = try container.decode(FindOneAndDeleteOptions.self, forKey: .arguments)
        let argumentContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
        self.filter = try argumentContainer.decode(Document.self, forKey: .filter)
    }

    func run(client: MongoClient, database: MongoDatabase, collection: MongoCollection<Document>, session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.findOneAndDelete(self.filter, options: self.options))
    }
}

struct FindOneAndReplace: TestOperation {
    let filter: Document
    let replacement: Document
    let options: FindOneAndReplaceOptions

    private enum CodingKeys: String, CodingKey { case filter, replacement }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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

struct ReplaceOne: TestOperation {
    let filter: Document
    let replacement: Document
    let options: ReplaceOptions

    private enum CodingKeys: String, CodingKey { case filter, replacement }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TestOperationKeys.self)
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
