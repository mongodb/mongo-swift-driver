import MongoSwiftSync
import Nimble
import TestsCommon

/// A enumeration of the different objects a `TestOperation` may be performed against.
enum TestOperationObject: RawRepresentable, Decodable {
    case client, database, collection, gridfsbucket, testRunner, session(String)

    public var rawValue: String {
        switch self {
        case .client:
            return "client"
        case .database:
            return "database"
        case .collection:
            return "collection"
        case .gridfsbucket:
            return "gridfsbucket"
        case .testRunner:
            return "testRunner"
        case let .session(sessionName):
            return sessionName
        }
    }

    public init(rawValue: String) {
        switch rawValue {
        case "client":
            self = .client
        case "database":
            self = .database
        case "collection":
            self = .collection
        case "gridfsbucket":
            self = .gridfsbucket
        case "testRunner":
            self = .testRunner
        default:
            self = .session(rawValue)
        }
    }
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

    /// The parameters to pass to the database used for this operation.
    let databaseOptions: DatabaseOptions?

    /// The parameters to pass to the collection used for this operation.
    let collectionOptions: CollectionOptions?

    /// Present only when the operation is `runCommand`. The name of the command to run.
    let commandName: String?

    public enum CodingKeys: String, CodingKey {
        case object, result, error, databaseOptions, collectionOptions, commandName = "command_name"
    }

    public init(from decoder: Decoder) throws {
        self.operation = try AnyTestOperation(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.object = try container.decode(TestOperationObject.self, forKey: .object)
        self.result = try container.decodeIfPresent(TestOperationResult.self, forKey: .result)
        self.error = try container.decodeIfPresent(Bool.self, forKey: .error)
        self.databaseOptions = try container.decodeIfPresent(DatabaseOptions.self, forKey: .databaseOptions)
        self.collectionOptions = try container.decodeIfPresent(CollectionOptions.self, forKey: .collectionOptions)
        self.commandName = try container.decodeIfPresent(String.self, forKey: .commandName)
    }

    // swiftlint:disable cyclomatic_complexity

    /// Runs the operation and asserts its results meet the expectation.
    func validateExecution(
        client: MongoClient,
        dbName: String,
        collName: String?,
        sessions: [String: ClientSession]
    ) throws {
        let database = client.db(dbName, options: self.databaseOptions)
        var collection: MongoCollection<Document>?

        if let collName = collName {
            collection = database.collection(collName, options: self.collectionOptions)
        }

        let target: TestOperationTarget
        switch self.object {
        case .client:
            target = .client(client)
        case .database:
            target = .database(database)
        case .collection:
            guard let collection = collection else {
                throw TestError(message: "got collection object but was not provided a collection")
            }
            target = .collection(collection)
        case .gridfsbucket:
            throw TestError(message: "gridfs tests should be skipped")
        case let .session(sessionName):
            guard let session = sessions[sessionName] else {
                throw TestError(message: "got session object but was not provided a session")
            }
            target = .session(session)
        case .testRunner:
            target = .testRunner(database)
        }

        do {
            let result = try self.operation.execute(on: target, sessions: sessions)
            expect(self.error ?? false)
                .to(beFalse(), description: "expected to fail but succeeded with result \(String(describing: result))")
            if let expectedResult = self.result {
                expect(result?.matches(expected: expectedResult)).to(beTrue())
            }
        } catch {
            if case let .error(expectedErrorResult) = self.result {
                try expectedErrorResult.checkErrorResult(error)
            } else {
                expect(self.error ?? false).to(beTrue(), description: "expected no error, got \(error)")
            }
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

    /// Execute against the provided session.
    case session(ClientSession)

    /// Execute against the provided test runner.
    case testRunner(MongoDatabase)
}

/// Protocol describing the behavior of a spec test "operation"
protocol TestOperation: Decodable {
    /// Execute the operation given the context.
    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult?
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
        case "startTransaction":
            self.op = (try? container.decode(StartTransaction.self, forKey: .arguments)) ?? StartTransaction()
        case "createCollection":
            self.op = try container.decode(CreateCollection.self, forKey: .arguments)
        case "dropCollection":
            self.op = try container.decode(DropCollection.self, forKey: .arguments)
        case "createIndex":
            self.op = try container.decode(CreateIndex.self, forKey: .arguments)
        case "runCommand":
            self.op = try container.decode(RunCommand.self, forKey: .arguments)
        case "assertCollectionExists":
            self.op = try container.decode(AssertCollectionExists.self, forKey: .arguments)
        case "assertCollectionNotExists":
            self.op = try container.decode(AssertCollectionNotExists.self, forKey: .arguments)
        case "assertIndexExists":
            self.op = try container.decode(AssertIndexExists.self, forKey: .arguments)
        case "assertIndexNotExists":
            self.op = try container.decode(AssertIndexNotExists.self, forKey: .arguments)
        case "assertSessionPinned":
            self.op = try container.decode(AssertSessionPinned.self, forKey: .arguments)
        case "assertSessionUnpinned":
            self.op = try container.decode(AssertSessionUnpinned.self, forKey: .arguments)
        case "assertSessionTransactionState":
            self.op = try container.decode(AssertSessionTransactionState.self, forKey: .arguments)
        case "drop":
            self.op = Drop()
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
        case "commitTransaction":
            self.op = CommitTransaction()
        case "abortTransaction":
            self.op = AbortTransaction()
        case "mapReduce", "download_by_name", "download", "count", "targetedFailPoint":
            self.op = NotImplemented(name: opName)
        default:
            throw TestError(message: "unsupported op name \(opName)")
        }
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        try self.op.execute(on: target, sessions: sessions)
    }
}

struct Aggregate: TestOperation {
    let session: String?
    let pipeline: [Document]
    let options: AggregateOptions

    private enum CodingKeys: String, CodingKey { case session, pipeline }

    init(from decoder: Decoder) throws {
        self.options = try AggregateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.pipeline = try container.decode([Document].self, forKey: .pipeline)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to aggregate")
        }
        return try TestOperationResult(
            from: collection.aggregate(self.pipeline, options: self.options, session: sessions[self.session ?? ""])
        )
    }
}

struct CountDocuments: TestOperation {
    let session: String?
    let filter: Document
    let options: CountDocumentsOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try CountDocumentsOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to count")
        }
        return .int(
            try collection.countDocuments(self.filter, options: self.options, session: sessions[self.session ?? ""]))
    }
}

struct Distinct: TestOperation {
    let session: String?
    let fieldName: String
    let filter: Document?
    let options: DistinctOptions

    private enum CodingKeys: String, CodingKey { case session, fieldName, filter }

    init(from decoder: Decoder) throws {
        self.options = try DistinctOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.fieldName = try container.decode(String.self, forKey: .fieldName)
        self.filter = try container.decodeIfPresent(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to distinct")
        }
        let result = try collection.distinct(
            fieldName: self.fieldName,
            filter: self.filter ?? [:],
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return .array(result)
    }
}

struct Find: TestOperation {
    let session: String?
    let filter: Document
    let options: FindOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = (try? container.decode(Document.self, forKey: .filter)) ?? Document()
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to find")
        }
        return try TestOperationResult(
            from: collection.find(self.filter, options: self.options, session: sessions[self.session ?? ""])
        )
    }
}

struct FindOne: TestOperation {
    let session: String?
    let filter: Document
    let options: FindOneOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOneOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOne")
        }
        return try TestOperationResult(
            from: collection.findOne(self.filter, options: self.options, session: sessions[self.session ?? ""])
        )
    }
}

struct UpdateOne: TestOperation {
    let session: String?
    let filter: Document
    let update: Document
    let options: UpdateOptions

    private enum CodingKeys: String, CodingKey { case session, filter, update }

    init(from decoder: Decoder) throws {
        self.options = try UpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.update = try container.decode(Document.self, forKey: .update)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to updateOne")
        }

        let result = try collection.updateOne(
            filter: self.filter,
            update: self.update,
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}

struct UpdateMany: TestOperation {
    let session: String?
    let filter: Document
    let update: Document
    let options: UpdateOptions

    private enum CodingKeys: String, CodingKey { case session, filter, update }

    init(from decoder: Decoder) throws {
        self.options = try UpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.update = try container.decode(Document.self, forKey: .update)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to ")
        }

        let result = try collection.updateMany(
            filter: self.filter,
            update: self.update,
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}

struct DeleteMany: TestOperation {
    let session: String?
    let filter: Document
    let options: DeleteOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try DeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to deleteMany")
        }
        let result =
            try collection.deleteMany(self.filter, options: self.options, session: sessions[self.session ?? ""])
        return TestOperationResult(from: result)
    }
}

struct DeleteOne: TestOperation {
    let session: String?
    let filter: Document
    let options: DeleteOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try DeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to deleteOne")
        }
        let result = try collection.deleteOne(self.filter, options: self.options, session: sessions[self.session ?? ""])
        return TestOperationResult(from: result)
    }
}

struct InsertOne: TestOperation {
    let session: String?
    let document: Document

    private enum CodingKeys: String, CodingKey { case session, document }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.document = try container.decode(Document.self, forKey: .document)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to insertOne")
        }
        return TestOperationResult(from: try collection.insertOne(self.document, session: sessions[self.session ?? ""]))
    }
}

struct InsertMany: TestOperation {
    let session: String?
    let documents: [Document]
    let options: InsertManyOptions

    private enum CodingKeys: String, CodingKey { case session, documents }

    init(from decoder: Decoder) throws {
        self.options = (try? InsertManyOptions(from: decoder)) ?? InsertManyOptions()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.documents = try container.decode([Document].self, forKey: .documents)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to insertMany")
        }
        let result = try collection.insertMany(
            self.documents,
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}

/// Extension of `WriteModel` adding `Decodable` conformance.
extension WriteModel: Decodable {
    private enum CodingKeys: CodingKey {
        case name, arguments
    }

    private enum InsertOneKeys: CodingKey {
        case session, document
    }

    private enum DeleteKeys: CodingKey {
        case session, filter
    }

    private enum ReplaceOneKeys: CodingKey {
        case session, filter, replacement
    }

    private enum UpdateKeys: CodingKey {
        case session, filter, update
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
    let session: String?
    let requests: [WriteModel<Document>]
    let options: BulkWriteOptions

    private enum CodingKeys: CodingKey { case session, requests }

    init(from decoder: Decoder) throws {
        self.options = (try? BulkWriteOptions(from: decoder)) ?? BulkWriteOptions()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.requests = try container.decode([WriteModel<Document>].self, forKey: .requests)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to bulk write")
        }
        let result =
            try collection.bulkWrite(self.requests, options: self.options, session: sessions[self.session ?? ""])
        return TestOperationResult(from: result)
    }
}

struct FindOneAndUpdate: TestOperation {
    let session: String?
    let filter: Document
    let update: Document
    let options: FindOneAndUpdateOptions

    private enum CodingKeys: String, CodingKey { case session, filter, update }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndUpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.update = try container.decode(Document.self, forKey: .update)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOneAndUpdate")
        }
        let doc = try collection.findOneAndUpdate(
            filter: self.filter,
            update: self.update,
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: doc)
    }
}

struct FindOneAndDelete: TestOperation {
    let session: String?
    let filter: Document
    let options: FindOneAndDeleteOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndDeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOneAndDelete")
        }
        let result = try collection.findOneAndDelete(
            self.filter,
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}

struct FindOneAndReplace: TestOperation {
    let session: String?
    let filter: Document
    let replacement: Document
    let options: FindOneAndReplaceOptions

    private enum CodingKeys: String, CodingKey { case session, filter, replacement }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndReplaceOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.replacement = try container.decode(Document.self, forKey: .replacement)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to findOneAndReplace")
        }
        let result = try collection.findOneAndReplace(
            filter: self.filter,
            replacement: self.replacement,
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}

struct ReplaceOne: TestOperation {
    let session: String?
    let filter: Document
    let replacement: Document
    let options: ReplaceOptions

    private enum CodingKeys: String, CodingKey { case session, filter, replacement }

    init(from decoder: Decoder) throws {
        self.options = try ReplaceOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(Document.self, forKey: .filter)
        self.replacement = try container.decode(Document.self, forKey: .replacement)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to replaceOne")
        }
        return TestOperationResult(from: try collection.replaceOne(
            filter: self.filter,
            replacement: self.replacement,
            options: self.options,
            session: sessions[self.session ?? ""]
        ))
    }
}

struct RenameCollection: TestOperation {
    let session: String?
    let to: String

    private enum CodingKeys: String, CodingKey { case session, to }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.to = try container.decode(String.self, forKey: .to)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to renameCollection")
        }

        let databaseName = collection.namespace.db
        let cmd: Document = [
            "renameCollection": .string(databaseName + "." + collection.name),
            "to": .string(databaseName + "." + self.to)
        ]
        return try TestOperationResult(
            from: collection._client.db("admin").runCommand(cmd, session: sessions[self.session ?? ""])
        )
    }
}

struct Drop: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to drop")
        }
        try collection.drop()
        return nil
    }
}

struct ListDatabaseNames: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .client(client) = target else {
            throw TestError(message: "client not provided to listDatabaseNames")
        }
        return try .array(client.listDatabaseNames(session: nil).map { .string($0) })
    }
}

struct ListIndexes: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to listIndexes")
        }
        return try TestOperationResult(from: collection.listIndexes(session: nil))
    }
}

struct ListIndexNames: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to listIndexNames")
        }
        return try .array(collection.listIndexNames(session: nil).map { .string($0) })
    }
}

struct ListDatabases: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .client(client) = target else {
            throw TestError(message: "client not provided to listDatabases")
        }
        return try TestOperationResult(from: client.listDatabases(session: nil))
    }
}

struct ListMongoDatabases: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .client(client) = target else {
            throw TestError(message: "client not provided to listDatabases")
        }
        _ = try client.listMongoDatabases(session: nil)
        return nil
    }
}

struct ListCollections: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to listCollections")
        }
        return try TestOperationResult(from: database.listCollections(session: nil))
    }
}

struct ListMongoCollections: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to listCollectionObjects")
        }
        _ = try database.listMongoCollections(session: nil)
        return nil
    }
}

struct ListCollectionNames: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to listCollectionNames")
        }
        return try .array(database.listCollectionNames(session: nil).map { .string($0) })
    }
}

struct Watch: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        switch target {
        case let .client(client):
            _ = try client.watch(session: nil)
        case let .database(database):
            _ = try database.watch(session: nil)
        case let .collection(collection):
            _ = try collection.watch(session: nil)
        case .session, .testRunner:
            break
        }
        return nil
    }
}

struct EstimatedDocumentCount: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to estimatedDocumentCount")
        }
        return try .int(collection.estimatedDocumentCount(session: nil))
    }
}

struct StartTransaction: TestOperation {
    let options: TransactionOptions

    private enum CodingKeys: CodingKey {
        case options
    }

    init() {
        self.options = TransactionOptions()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.options = try container.decode(TransactionOptions.self, forKey: .options)
    }

    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .session(session) = target else {
            throw TestError(message: "session not provided to startTransaction")
        }
        _ = try session.startTransaction(options: self.options)
        return nil
    }
}

struct CommitTransaction: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .session(session) = target else {
            throw TestError(message: "session not provided to commitTransaction")
        }
        try session.commitTransaction()
        return nil
    }
}

struct AbortTransaction: TestOperation {
    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .session(session) = target else {
            throw TestError(message: "session not provided to abortTransaction")
        }
        try session.abortTransaction()
        return nil
    }
}

struct CreateCollection: TestOperation {
    let session: String?
    let collection: String

    private enum CodingKeys: String, CodingKey { case session, collection }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.collection = try container.decode(String.self, forKey: .collection)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to createCollection")
        }
        _ = try database.createCollection(self.collection, session: sessions[self.session ?? ""])
        return nil
    }
}

struct DropCollection: TestOperation {
    let session: String?
    let collection: String

    private enum CodingKeys: String, CodingKey { case session, collection }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.collection = try container.decode(String.self, forKey: .collection)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to dropCollection")
        }
        _ = try database.collection(self.collection).drop(session: sessions[self.session ?? ""])
        return nil
    }
}

struct CreateIndex: TestOperation {
    let session: String?
    let name: String
    let keys: Document

    private enum CodingKeys: String, CodingKey { case session, name, keys }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.name = try container.decode(String.self, forKey: .name)
        self.keys = try container.decode(Document.self, forKey: .keys)
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .collection(collection) = target else {
            throw TestError(message: "collection not provided to createIndex")
        }
        let indexOptions = IndexOptions(name: self.name)
        _ = try collection.createIndex(self.keys, indexOptions: indexOptions, session: sessions[self.session ?? ""])
        return nil
    }
}

struct RunCommand: TestOperation {
    let session: String?
    let command: Document
    let readPreference: ReadPreference

    private enum CodingKeys: String, CodingKey { case session, command, readPreference }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.command = try container.decode(Document.self, forKey: .command)
        self.readPreference = (try? container.decode(ReadPreference.self, forKey: .readPreference)) ??
            ReadPreference.primary
    }

    func execute(on target: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard case let .database(database) = target else {
            throw TestError(message: "database not provided to runCommand")
        }
        let runCommandOptions = RunCommandOptions(readPreference: self.readPreference)
        let result = try database.runCommand(
            self.command,
            options: runCommandOptions,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}

struct AssertCollectionExists: TestOperation {
    let database: String
    let collection: String

    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .testRunner(database) = target else {
            throw TestError(message: "database not provided to assertCollectionExists")
        }
        let client = try MongoClient.makeTestClient()
        let collectionNames = try client.db(database.name).listCollectionNames(session: nil)
        expect(collectionNames).to(contain(self.collection))
        return nil
    }
}

struct AssertCollectionNotExists: TestOperation {
    let database: String
    let collection: String

    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .testRunner(database) = target else {
            throw TestError(message: "database not provided to assertCollectionNotExists")
        }
        let client = try MongoClient.makeTestClient()
        let collectionNames = try client.db(database.name).listCollectionNames(session: nil)
        expect(collectionNames).toNot(contain(self.collection))
        return nil
    }
}

struct AssertIndexExists: TestOperation {
    let database: String
    let collection: String
    let index: String

    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .testRunner(database) = target else {
            throw TestError(message: "database not provided to assertIndexExists")
        }
        let client = try MongoClient.makeTestClient()
        let indexNames = try client.db(database.name).collection(self.collection).listIndexNames(session: nil)
        expect(indexNames).to(contain(self.index))
        return nil
    }
}

struct AssertIndexNotExists: TestOperation {
    let database: String
    let collection: String
    let index: String

    func execute(on target: TestOperationTarget, sessions _: [String: ClientSession])
        throws -> TestOperationResult? {
        guard case let .testRunner(database) = target else {
            throw TestError(message: "database not provided to assertIndexNotExists")
        }
        let client = try MongoClient.makeTestClient()
        let indexNames = try client.db(database.name).collection(self.collection).listIndexNames(session: nil)
        expect(indexNames).toNot(contain(self.index))
        return nil
    }
}

struct AssertSessionPinned: TestOperation {
    let session: String?

    private enum CodingKeys: String, CodingKey { case session }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
    }

    func execute(on _: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard let serverId = sessions[self.session ?? ""]?.serverId else {
            throw TestError(message: "active session not provided to assertSessionPinned")
        }
        expect(serverId).to(equal(0))
        return nil
    }
}

struct AssertSessionUnpinned: TestOperation {
    let session: String?

    private enum CodingKeys: String, CodingKey { case session }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
    }

    func execute(on _: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard let serverId = sessions[self.session ?? ""]?.serverId else {
            throw TestError(message: "active session not provided to assertSessionPinned")
        }
        expect(serverId).toNot(equal(0))
        return nil
    }
}

struct AssertSessionTransactionState: TestOperation {
    let session: String?
    let state: ClientSession.TransactionState

    private enum CodingKeys: String, CodingKey { case session, state }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.state = try container.decode(ClientSession.TransactionState.self, forKey: .state)
    }

    func execute(on _: TestOperationTarget, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard let transactionState = sessions[self.session ?? ""]?.transactionState else {
            throw TestError(message: "active session not provided to assertSessionTransactionState")
        }
        expect(transactionState).to(equal(self.state))
        return nil
    }
}

/// Dummy `TestOperation` that can be used in place of an unimplemented one (e.g. findOne)
struct NotImplemented: TestOperation {
    internal let name: String

    func execute(on _: TestOperationTarget, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        throw TestError(message: "\(self.name) not implemented in the driver, skip this test")
    }
}
