@testable import MongoSwiftSync
import Nimble
import TestsCommon

/// A enumeration of the different objects a `TestOperation` may be performed against.
enum TestOperationObject: String, Decodable {
    case client, database, collection, gridfsbucket
}

/// Struct containing an operation and an expected outcome.
struct TestOperationDescription: Decodable {
    /// The operation to run.
    let operation: AnyTestOperation

    /// The object to perform the operation on.
    let object: TestOperationObject

    /// The return value of the operation, if any.
    let result: TestOperationResult?

    /// Whether the operation should expect an error.
    let error: Bool?

    public enum CodingKeys: CodingKey {
        case object, result, error
    }

    public init(from decoder: Decoder) throws {
        self.operation = try AnyTestOperation(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.object = try container.decode(TestOperationObject.self, forKey: .object)
        self.result = try container.decodeIfPresent(TestOperationResult.self, forKey: .result)
        self.error = try container.decodeIfPresent(Bool.self, forKey: .error)
    }

    /// Runs the operation and asserts its results meet the expectation.
    func validateExecution(
        client: MongoClient,
        database: MongoDatabase?,
        collection: MongoCollection<Document>?,
        session: ClientSession?
    ) throws {
        let target: TestOperationTarget
        switch self.object {
        case .client:
            target = .client(client)
        case .database:
            guard let database = database else {
                throw TestError(message: "got database object but was not provided a database")
            }
            target = .database(database)
        case .collection:
            guard let collection = collection else {
                throw TestError(message: "got collection object but was not provided a collection")
            }
            target = .collection(collection)
        case .gridfsbucket:
            throw TestError(message: "gridfs tests should be skipped")
        }

        do {
            let result = try self.operation.execute(on: target, session: session)
            expect(self.error ?? false)
                .to(beFalse(), description: "expected to fail but succeeded with result \(String(describing: result))")
            if let expectedResult = self.result {
                expect(result).to(equal(expectedResult))
            }
        } catch {
            expect(self.error ?? false).to(beTrue(), description: "expected no error, got \(error)")
        }
    }
}

/// Object in which an operation should be executed on.
/// Not all target cases are supported by each operation.
enum TestOperationTarget {
    /// Execute against the provided client.
    case client(MongoClient)

    /// Execute against the provided database.
    case database(MongoDatabase)

    /// Execute against the provided collection.
    case collection(MongoCollection<Document>)
}

/// Protocol describing the behavior of a spec test "operation"
protocol TestOperation: Decodable {
    /// Execute the operation given the context.
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult?
}

/// Wrapper around a `TestOperation.swift` allowing it to be decoded from a spec test.
struct AnyTestOperation: Decodable, TestOperation {
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
        case "countDocuments":
            self.op = try container.decode(CountDocuments.self, forKey: .arguments)
        case "estimatedDocumentCount":
            self.op = EstimatedDocumentCount()
        case "distinct":
            self.op = try container.decode(Distinct.self, forKey: .arguments)
        case "find":
            self.op = try container.decode(Find.self, forKey: .arguments)
        case "findOne":
            self.op = try container.decode(FindOne.self, forKey: .arguments)
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
        case "rename":
            self.op = try container.decode(RenameCollection.self, forKey: .arguments)
        case "drop":
            self.op = DropCollection()
        case "listDatabaseNames":
            self.op = ListDatabaseNames()
        case "listDatabases":
            self.op = ListDatabases()
        case "listDatabaseObjects":
            self.op = ListMongoDatabases()
        case "listIndexes":
            self.op = ListIndexes()
        case "listIndexNames":
            self.op = ListIndexNames()
        case "listCollections":
            self.op = ListCollections()
        case "listCollectionObjects":
            self.op = ListMongoCollections()
        case "listCollectionNames":
            self.op = ListCollectionNames()
        case "watch":
            self.op = Watch()
        case "mapReduce", "download_by_name", "download", "count":
            self.op = NotImplemented(name: opName)
        default:
            throw TestError(message: "unsupported op name \(opName)")
        }
    }

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        return try self.op.execute(on: target, session: session)
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to aggregate")
        }
        return try TestOperationResult(
            from: collection.aggregate(self.pipeline, options: self.options, session: session)
        )
    }
}

struct CountDocuments: TestOperation {
    let filter: Document
    let options: CountDocumentsOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        self.options = try CountDocumentsOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to count")
        }
        return .int(try collection.countDocuments(self.filter, options: self.options, session: session))
    }
}

struct Distinct: TestOperation {
    let fieldName: String
    let filter: Document?
    let options: DistinctOptions

    private enum CodingKeys: String, CodingKey { case fieldName, filter }

    init(from decoder: Decoder) throws {
        self.options = try DistinctOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fieldName = try container.decode(String.self, forKey: .fieldName)
        self.filter = try container.decodeIfPresent(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to distinct")
        }
        let result = try collection.distinct(
            fieldName: self.fieldName,
            filter: self.filter ?? [:],
            options: self.options,
            session: session
        )
        return .array(result)
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to find")
        }
        return try TestOperationResult(from: collection.find(self.filter, options: self.options, session: session))
    }
}

struct FindOne: TestOperation {
    let filter: Document
    let options: FindOneOptions

    private enum CodingKeys: String, CodingKey { case filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOneOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOne")
        }
        return try TestOperationResult(from: collection.findOne(self.filter, options: self.options, session: session))
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to updateOne")
        }

        let result = try collection.updateOne(
            filter: self.filter,
            update: self.update,
            options: self.options,
            session: session
        )
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to ")
        }

        let result = try collection.updateMany(
            filter: self.filter,
            update: self.update,
            options: self.options,
            session: session
        )
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to deleteMany")
        }
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to deleteOne")
        }
        let result = try collection.deleteOne(self.filter, options: self.options, session: session)
        return TestOperationResult(from: result)
    }
}

struct InsertOne: TestOperation {
    let document: Document

    func execute(on target: TestOperationTarget, session _: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to insertOne")
        }
        return TestOperationResult(from: try collection.insertOne(self.document))
    }
}

struct InsertMany: TestOperation {
    let documents: [Document]
    let options: InsertManyOptions

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to insertMany")
        }
        let result = try collection.insertMany(self.documents, options: self.options, session: session)
        return TestOperationResult(from: result)
    }
}

/// Extension of `WriteModel` adding `Decodable` conformance.
extension WriteModel: Decodable {
    private enum CodingKeys: CodingKey {
        case name, arguments
    }

    private enum InsertOneKeys: CodingKey {
        case document
    }

    private enum DeleteKeys: CodingKey {
        case filter
    }

    private enum ReplaceOneKeys: CodingKey {
        case filter, replacement
    }

    private enum UpdateKeys: CodingKey {
        case filter, update
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)

        switch name {
        case "insertOne":
            let args = try container.nestedContainer(keyedBy: InsertOneKeys.self, forKey: .arguments)
            let doc = try args.decode(CollectionType.self, forKey: .document)
            self = .insertOne(doc)
        case "deleteOne", "deleteMany":
            let options = try container.decode(DeleteModelOptions.self, forKey: .arguments)
            let args = try container.nestedContainer(keyedBy: DeleteKeys.self, forKey: .arguments)
            let filter = try args.decode(Document.self, forKey: .filter)
            self = name == "deleteOne" ? .deleteOne(filter, options: options) : .deleteMany(filter, options: options)
        case "replaceOne":
            let options = try container.decode(ReplaceOneModelOptions.self, forKey: .arguments)
            let args = try container.nestedContainer(keyedBy: ReplaceOneKeys.self, forKey: .arguments)
            let filter = try args.decode(Document.self, forKey: .filter)
            let replacement = try args.decode(CollectionType.self, forKey: .replacement)
            self = .replaceOne(filter: filter, replacement: replacement, options: options)
        case "updateOne", "updateMany":
            let options = try container.decode(UpdateModelOptions.self, forKey: .arguments)
            let args = try container.nestedContainer(keyedBy: UpdateKeys.self, forKey: .arguments)
            let filter = try args.decode(Document.self, forKey: .filter)
            let update = try args.decode(Document.self, forKey: .update)
            self = name == "updateOne" ?
                .updateOne(filter: filter, update: update, options: options) :
                .updateMany(filter: filter, update: update, options: options)
        default:
            throw DecodingError.typeMismatch(
                WriteModel.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown write model: \(name)"
                )
            )
        }
    }
}

struct BulkWrite: TestOperation {
    let requests: [WriteModel<Document>]
    let options: BulkWriteOptions

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to bulk write")
        }
        let result = try collection.bulkWrite(self.requests, options: self.options, session: session)
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOneAndUpdate")
        }
        let doc = try collection.findOneAndUpdate(
            filter: self.filter,
            update: self.update,
            options: self.options,
            session: session
        )
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOneAndDelete")
        }
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOneAndReplace")
        }
        let result = try collection.findOneAndReplace(
            filter: self.filter,
            replacement: self.replacement,
            options: self.options,
            session: session
        )
        return TestOperationResult(from: result)
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

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to replaceOne")
        }
        return TestOperationResult(from: try collection.replaceOne(
            filter: self.filter,
            replacement: self.replacement,
            options: self.options,
            session: session
        ))
    }
}

struct RenameCollection: TestOperation {
    let to: String

    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to renameCollection")
        }

        let databaseName = collection.namespace.db
        let cmd: Document = [
            "renameCollection": .string(databaseName + "." + collection.name),
            "to": .string(databaseName + "." + self.to)
        ]
        return try TestOperationResult(from: collection._client.db("admin").runCommand(cmd, session: session))
    }
}

struct DropCollection: TestOperation {
    func execute(on target: TestOperationTarget, session _: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to dropCollection")
        }
        try collection.drop()
        return nil
    }
}

struct ListDatabaseNames: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .client(client) = target else {
            throw TestError(message: "client not provided to listDatabaseNames")
        }
        return try .array(client.listDatabaseNames(session: session).map { .string($0) })
    }
}

struct ListIndexes: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to listIndexes")
        }
        return try TestOperationResult(from: collection.listIndexes(session: session))
    }
}

struct ListIndexNames: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to listIndexNames")
        }
        return try .array(collection.listIndexNames(session: session).map { .string($0) })
    }
}

struct ListDatabases: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .client(client) = target else {
            throw TestError(message: "client not provided to listDatabases")
        }
        return try TestOperationResult(from: client.listDatabases(session: session))
    }
}

struct ListMongoDatabases: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .client(client) = target else {
            throw TestError(message: "client not provided to listDatabases")
        }
        _ = try client.listMongoDatabases(session: session)
        return nil
    }
}

struct ListCollections: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to listCollections")
        }
        return try TestOperationResult(from: database.listCollections(session: session))
    }
}

struct ListMongoCollections: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to listCollectionObjects")
        }
        _ = try database.listMongoCollections(session: session)
        return nil
    }
}

struct ListCollectionNames: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to listCollectionNames")
        }
        return try .array(database.listCollectionNames(session: session).map { .string($0) })
    }
}

struct Watch: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        switch target {
        case let .client(client):
            _ = try client.watch(session: session)
        case let .database(database):
            _ = try database.watch(session: session)
        case let .collection(collection):
            _ = try collection.watch(session: session)
        }
        return nil
    }
}

struct EstimatedDocumentCount: TestOperation {
    func execute(on target: TestOperationTarget, session: ClientSession?) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to estimatedDocumentCount")
        }
        return try .int(collection.estimatedDocumentCount(session: session))
    }
}

/// Dummy `TestOperation` that can be used in place of an unimplemented one (e.g. findOne)
struct NotImplemented: TestOperation {
    internal let name: String

    func execute(on _: TestOperationTarget, session _: ClientSession?) throws -> TestOperationResult? {
        throw TestError(message: "\(self.name) not implemented in the driver, skip this test")
    }
}
