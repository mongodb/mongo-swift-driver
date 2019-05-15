import Foundation
@testable import MongoSwift
import Nimble
import XCTest

/// Struct representing the contents of a collection after a spec test has been run.
internal struct CollectionTestInfo: Decodable {
    /// An optional name specifying a collection whose documents match the `data` field of this struct.
    /// If nil, whatever collection used in the test should be used instead.
    let name: String?

    /// The documents found in the collection.
    let data: [Document]
}

/// Struct representing an "outcome" defined in a spec test.
internal struct TestOutcome: Decodable {
    /// Whether an error is expected or not.
    let error: Bool?

    /// The expected result of running the operation associated with this test.
    let result: TestOperationResult?

    /// The expected state of the collection at the end of the test.
    let collection: CollectionTestInfo
}

/// Protocol defining the behavior of an individual spec test.
protocol SpecTest {
    var description: String { get }
    var outcome: TestOutcome { get }
    var operation: AnyTestOperation { get }

    /// Runs the operation with the given context and performs assertions on the result based upon the expected outcome.
    func run(client: MongoClient,
             db: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession) throws
}

/// Default implementation of a test execution.
extension SpecTest {
    internal func run(client: MongoClient,
                      db: MongoDatabase,
                      collection: MongoCollection<Document>,
                      session: ClientSession?) throws {
        var result: TestOperationResult?
        var seenError: Error?
        do {
            result = try self.operation.op.execute(
                    client: client,
                    database: db,
                    collection: collection,
                    session: session)
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

/// Protocol for allowing conversion from different result types to `BulkWriteResult`.
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

/// Enum encapsulating the possible results returned from CRUD operations.
enum TestOperationResult: Decodable, Equatable {
    /// Crud operation returns an int (e.g. `count`).
    case int(Int)

    /// Result of CRUD operations that return an array of `BSONValues` (e.g. `distinct`).
    case array([BSONValue])

    /// Result of CRUD operations that return a single `Document` (e.g. `findOneAndDelete`).
    case document(Document)

    /// Result of CRUD operations whose result can be represented by a `BulkWriteResult` (e.g. `InsertOne`).
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
        self = .array(Array(cursor))
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

    internal static func == (lhs: TestOperationResult, rhs: TestOperationResult) -> Bool {
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

/// Protocol describing the behavior of a spec test "operation"
protocol TestOperation: Decodable {
    /// Execute the operation given the context.
    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession?) throws -> TestOperationResult?
}

/// Wrapper around a `TestOperation` allowing it to be decoded from a spec test.
struct AnyTestOperation: Decodable {
    let op: TestOperation

    private enum CodingKeys: String, CodingKey {
        case name, arguments
    }

    // swiftlint:disable:next cyclomatic_complexity
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let opName = try container.decode(String.self, forKey: .name)

        switch opName {
        case "aggregate":
            self.op = try container.decode(Aggregate.self, forKey: .arguments)
        case "count":
            self.op = try container.decode(Count.self, forKey: .arguments)
        case "distinct":
            self.op = try container.decode(Distinct.self, forKey: .arguments)
        case "find":
            self.op = try container.decode(Find.self, forKey: .arguments)
        case "updateOne":
            self.op = try container.decode(UpdateOne.self, forKey: .arguments)
        case "updateMany":
            self.op = try container.decode(UpdateMany.self, forKey: .arguments)
        case "insertOne":
            self.op = try container.decode(InsertOne.self, forKey: .arguments)
        case "insertMany":
            self.op = try container.decode(InsertMany.self, forKey: .arguments)
        case "deleteOne":
            self.op = try container.decode(DeleteOne.self, forKey: .arguments)
        case "deleteMany":
            self.op = try container.decode(DeleteMany.self, forKey: .arguments)
        case "bulkWrite":
            self.op = try container.decode(BulkWrite.self, forKey: .arguments)
        case "findOneAndDelete":
            self.op = try container.decode(FindOneAndDelete.self, forKey: .arguments)
        case "findOneAndReplace":
            self.op = try container.decode(FindOneAndReplace.self, forKey: .arguments)
        case "findOneAndUpdate":
            self.op = try container.decode(FindOneAndUpdate.self, forKey: .arguments)
        case "replaceOne":
            self.op = try container.decode(ReplaceOne.self, forKey: .arguments)
        default:
            throw UserError.logicError(message: "unsupported op name \(opName)")
        }
    }
}

struct Aggregate: TestOperation {
    let pipeline: [Document]
    let options: AggregateOptions

    private enum CodingKeys: String, CodingKey { case pipeline }

    init(from decoder: Decoder) throws {
        self.options = try AggregateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pipeline = try container.decode([Document].self, forKey: .pipeline)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.aggregate(pipeline, options: self.options, session: session))
    }
}

struct Count: TestOperation {
    let filter: Document
    let options: CountOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        self.options = try CountOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return .int(try collection.count(filter, options: self.options, session: session))
    }
}

struct Distinct: TestOperation {
    let fieldName: String
    let options: DistinctOptions

    private enum CodingKeys: String, CodingKey { case fieldName }

    init(from decoder: Decoder) throws {
        self.options = try DistinctOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fieldName = try container.decode(String.self, forKey: .fieldName)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return .array(try collection.distinct(fieldName: self.fieldName, options: self.options, session: session))
    }
}

struct Find: TestOperation {
    let filter: Document
    let options: FindOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.find(self.filter, options: self.options, session: session))
    }
}

struct UpdateOne: TestOperation {
    let filter: Document
    let update: Document
    let options: UpdateOptions

    private enum CodingKeys: String, CodingKey { case filter, update }

    init(from decoder: Decoder) throws {
        self.options = try UpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.update = try container.decode(Document.self, forKey: .update)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        let result = try collection.updateOne(filter: self.filter,
                                              update: self.update,
                                              options: self.options,
                                              session: session)
        return TestOperationResult(from: result)
    }
}

struct UpdateMany: TestOperation {
    let filter: Document
    let update: Document
    let options: UpdateOptions

    private enum CodingKeys: String, CodingKey { case filter, update }

    init(from decoder: Decoder) throws {
        self.options = try UpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.update = try container.decode(Document.self, forKey: .update)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        let result = try collection.updateMany(filter: self.filter,
                                               update: self.update,
                                               options: self.options,
                                               session: session)
        return TestOperationResult(from: result)
    }
}

struct DeleteMany: TestOperation {
    let filter: Document
    let options: DeleteOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        self.options = try DeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        let result = try collection.deleteMany(self.filter, options: self.options, session: session)
        return TestOperationResult(from: result)
    }
}

struct DeleteOne: TestOperation {
    let filter: Document
    let options: DeleteOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        self.options = try DeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        let result = try collection.deleteOne(self.filter, options: self.options, session: session)
        return TestOperationResult(from: result)
    }
}

struct InsertOne: TestOperation {
    let document: Document

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.insertOne(self.document))
    }
}

struct InsertMany: TestOperation {
    let documents: [Document]
    let options: InsertManyOptions

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.insertMany(self.documents,
                                                                   options: self.options,
                                                                   session: session))
    }
}

/// Wrapper around a `WriteModel` adding `Decodable` conformance.
struct AnyWriteModel: Decodable {
    let model: WriteModel

    private enum CodingKeys: CodingKey {
        case name, arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        switch name {
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
                                             DecodingError.Context(codingPath: decoder.codingPath,
                                                                   debugDescription: "Unknown write model: \(name)"))
        }
    }
}

struct BulkWrite: TestOperation {
    let requests: [AnyWriteModel]
    let options: BulkWriteOptions

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        let result = try collection.bulkWrite(self.requests.map { $0.model }, options: self.options, session: session)
        return TestOperationResult(from: result)
    }
}

struct FindOneAndUpdate: TestOperation {
    let filter: Document
    let update: Document
    let options: FindOneAndUpdateOptions

    private enum CodingKeys: String, CodingKey { case filter, update }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndUpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.update = try container.decode(Document.self, forKey: .update)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        let doc = try collection.findOneAndUpdate(filter: self.filter,
                                                  update: self.update,
                                                  options: self.options,
                                                  session: session)
        return TestOperationResult(from: doc)
    }
}

struct FindOneAndDelete: TestOperation {
    let filter: Document
    let options: FindOneAndDeleteOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndDeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        let result = try collection.findOneAndDelete(self.filter, options: self.options, session: session)
        return TestOperationResult(from: result)
    }
}

struct FindOneAndReplace: TestOperation {
    let filter: Document
    let replacement: Document
    let options: FindOneAndReplaceOptions

    private enum CodingKeys: String, CodingKey { case filter, replacement }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndReplaceOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.replacement = try container.decode(Document.self, forKey: .replacement)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.findOneAndReplace(filter: self.filter,
                                                                          replacement: self.replacement,
                                                                          options: self.options,
                                                                          session: session))
    }
}

struct ReplaceOne: TestOperation {
    let filter: Document
    let replacement: Document
    let options: ReplaceOptions

    private enum CodingKeys: String, CodingKey { case filter, replacement }

    init(from decoder: Decoder) throws {
        self.options = try ReplaceOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.replacement = try container.decode(Document.self, forKey: .replacement)
    }

    func execute(client: MongoClient,
                 database: MongoDatabase,
                 collection: MongoCollection<Document>,
                 session: ClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.replaceOne(filter: self.filter,
                                                                   replacement: self.replacement,
                                                                   options: self.options,
                                                                   session: session))
    }
}
