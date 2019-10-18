@testable import MongoSwift

/// Protocol describing the behavior of a spec test "operation"
protocol TestOperation: Decodable {
    /// Execute the operation given the context.
    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession?) throws -> TestOperationResult?
}

/// Wrapper around a `TestOperation.swift` allowing it to be decoded from a spec test.
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
        case "rename":
            self.op = try container.decode(RenameCollection.self, forKey: .arguments)
        case "drop":
            self.op = DropCollection()
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
        let result = try collection.deleteOne(self.filter, options: self.options, session: session)
        return TestOperationResult(from: result)
    }
}

struct InsertOne: TestOperation {
    let document: Document

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.insertOne(self.document))
    }
}

struct InsertMany: TestOperation {
    let documents: [Document]
    let options: InsertManyOptions

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.insertMany(self.documents,
                                                                   options: self.options,
                                                                   session: session))
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
            throw DecodingError.typeMismatch(WriteModel.self,
                                             DecodingError.Context(codingPath: decoder.codingPath,
                                                                   debugDescription: "Unknown write model: \(name)"))
        }
    }
}

struct BulkWrite: TestOperation {
    let requests: [WriteModel<Document>]
    let options: BulkWriteOptions

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
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

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
        return TestOperationResult(from: try collection.replaceOne(filter: self.filter,
                                                                   replacement: self.replacement,
                                                                   options: self.options,
                                                                   session: session))
    }
}

struct RenameCollection: TestOperation {
    let to: String

    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
        let fromNamespace = database.name + "." + collection.name
        let toNamespace = database.name + "." + self.to
        let cmd: Document = ["renameCollection": .string(fromNamespace), "to": .string(toNamespace)]
        return TestOperationResult(from: try client.db("admin").runCommand(cmd))
    }
}

struct DropCollection: TestOperation {
    func execute(client: SyncMongoClient,
                 database: SyncMongoDatabase,
                 collection: SyncMongoCollection<Document>,
                 session: SyncClientSession? = nil) throws -> TestOperationResult? {
        try collection.drop()
        return nil
    }
}
