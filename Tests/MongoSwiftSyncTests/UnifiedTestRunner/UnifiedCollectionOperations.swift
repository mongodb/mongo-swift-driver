import Foundation
@testable import struct MongoSwift.AggregateOptions
@testable import struct MongoSwift.FindOptions
import MongoSwiftSync
import TestsCommon

struct UnifiedAggregate: UnifiedOperationProtocol {
    /// Aggregation pipeline.
    let pipeline: [BSONDocument]

    /// Options to use for the operation.
    let options: AggregateOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case pipeline, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                AggregateOptions.CodingKeys.allCases.map { $0.rawValue }
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pipeline = try container.decode([BSONDocument].self, forKey: .pipeline)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(AggregateOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let session = try context.entities.resolveSession(id: self.session)
        let entity = try context.entities.getEntity(from: object)

        let cursor: MongoCursor<BSONDocument>
        switch entity {
        case let .collection(coll):
            cursor = try coll.aggregate(self.pipeline, options: self.options, session: session)
        case let .database(db):
            cursor = try db.aggregate(self.pipeline, options: self.options, session: session)
        default:
            throw TestError(message: "Unsupported entity \(entity) for aggregate")
        }

        let docs = try cursor.map { try $0.get() }
        return .rootDocumentArray(docs)
    }
}

struct UnifiedCreateIndex: UnifiedOperationProtocol {
    /// The name of the index to create.
    let name: String

    /// Keys for the index.
    let keys: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        ["name", "keys", "session"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let opts = IndexOptions(name: self.name)
        let model = IndexModel(keys: self.keys, options: opts)
        _ = try collection.createIndex(model, session: session)
        return .none
    }
}

struct UnifiedBulkWrite: UnifiedOperationProtocol {
    /// Writes to perform.
    let requests: [WriteModel<BSONDocument>]

    /// Options to use for the operation.
    let options: BulkWriteOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case requests, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                BulkWriteOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(BulkWriteOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        let decodedRequests = try container.decode([TestWriteModel].self, forKey: .requests)
        self.requests = decodedRequests.map { $0.toWriteModel() }
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try collection.bulkWrite(self.requests, options: self.options, session: session) else {
            return .none
        }
        let encodedResult = try BSONEncoder().encode(result)
        return .bson(.document(encodedResult))
    }
}

struct UnifiedFind: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Options to use for the operation.
    let options: FindOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case session, filter
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOptions.CodingKeys.allCases.map { $0.rawValue }
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let cursor = try collection.find(self.filter, options: self.options, session: session)
        let docs = try cursor.map { try $0.get() }
        return .rootDocumentArray(docs)
    }
}

struct UnifiedFindOneAndReplace: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Replacement document.
    let replacement: BSONDocument

    /// Options to use for the operation.
    let options: FindOneAndReplaceOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, replacement, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOneAndReplaceOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOneAndReplaceOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.replacement = try container.decode(BSONDocument.self, forKey: .replacement)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try collection.findOneAndReplace(
            filter: filter,
            replacement: replacement,
            options: options,
            session: session
        ) else {
            return .none
        }
        return .bson(.document(result))
    }
}

struct UnifiedFindOneAndUpdate: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Update to use for this operation.
    let update: BSONDocument

    /// Options to use for the operation.
    let options: FindOneAndUpdateOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, update, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOneAndUpdateOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOneAndUpdateOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.update = try container.decode(BSONDocument.self, forKey: .update)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try collection.findOneAndUpdate(
            filter: filter,
            update: update,
            options: options,
            session: session
        ) else {
            return .none
        }
        return .rootDocument(result)
    }
}

struct UnifiedFindOneAndDelete: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    static var knownArguments: Set<String> {
        ["filter"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        guard let result = try collection.findOneAndDelete(filter) else {
            return .none
        }
        return .rootDocument(result)
    }
}

struct UnifiedDeleteOne: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Options to use for the operation.
    let options: DeleteOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case session, filter
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                DeleteOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(DeleteOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try collection.deleteOne(filter, options: options, session: session) else {
            return .none
        }
        let encoded = try BSONEncoder().encode(result)
        return .bson(.document(encoded))
    }
}

struct UnifiedDeleteMany: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    static var knownArguments: Set<String> {
        ["filter"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        guard let result = try collection.deleteMany(filter) else {
            return .none
        }
        let encoded = try BSONEncoder().encode(result)
        return .bson(.document(encoded))
    }
}

struct UnifiedInsertOne: UnifiedOperationProtocol {
    /// Document to insert.
    let document: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    /// Options to use while executing the operation.
    let options: InsertOneOptions

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case document, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                InsertOneOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.document = try container.decode(BSONDocument.self, forKey: .document)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(InsertOneOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try collection.insertOne(self.document, options: self.options, session: session) else {
            return .none
        }
        return .bson(.document(try BSONEncoder().encode(result)))
    }
}

struct UnifiedInsertMany: UnifiedOperationProtocol {
    /// Documents to insert.
    let documents: [BSONDocument]

    /// Optional identifier for a session entity to use.
    let session: String?

    /// Options to use while executing the operation.
    let options: InsertManyOptions

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case documents, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                InsertManyOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.documents = try container.decode([BSONDocument].self, forKey: .documents)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(InsertManyOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try collection.insertMany(self.documents, options: options, session: session) else {
            return .none
        }
        let encoded = try BSONEncoder().encode(result)
        return .bson(.document(encoded))
    }
}

struct UnifiedReplaceOne: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    /// Replacement document.
    let replacement: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    /// Options to use while executing the operation.
    let options: ReplaceOptions

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, replacement, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                ReplaceOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.replacement = try container.decode(BSONDocument.self, forKey: .replacement)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(ReplaceOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try collection.replaceOne(
            filter: filter,
            replacement: replacement,
            options: options,
            session: session
        ) else {
            return .none
        }
        let encoded = try BSONEncoder().encode(result)
        return .bson(.document(encoded))
    }
}

struct UnifiedCountDocuments: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    static var knownArguments: Set<String> {
        ["filter"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let result = try collection.countDocuments(filter)
        return .bson(BSON(result))
    }
}

struct UnifiedEstimatedDocumentCount: UnifiedOperationProtocol {
    let options: EstimatedDocumentCountOptions?

    static var knownArguments: Set<String> {
        Set(EstimatedDocumentCountOptions.CodingKeys.allCases.map { $0.stringValue })
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(EstimatedDocumentCountOptions.self)
    }

    init() {
        self.options = nil
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let result = try collection.estimatedDocumentCount(options: self.options)
        return .bson(BSON(result))
    }
}

struct UnifiedDistinct: UnifiedOperationProtocol {
    /// Field to retrieve distinct values for.
    let fieldName: String

    /// Filter for the query.
    let filter: BSONDocument

    static var knownArguments: Set<String> {
        ["fieldName", "filter"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let result = try collection.distinct(fieldName: self.fieldName, filter: filter)
        return .bson(.array(result))
    }
}

struct UnifiedUpdateOne: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    /// Update to perform.
    let update: BSONDocument

    static var knownArguments: Set<String> {
        ["update", "filter"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        guard let result = try collection.updateOne(filter: filter, update: update) else {
            return .none
        }
        let encoded = try BSONEncoder().encode(result)
        return .bson(.document(encoded))
    }
}

struct UnifiedUpdateMany: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    /// Update to perform.
    let update: BSONDocument

    static var knownArguments: Set<String> {
        ["update", "filter"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        guard let result = try collection.updateMany(filter: filter, update: update) else {
            return .none
        }
        let encoded = try BSONEncoder().encode(result)
        return .bson(.document(encoded))
    }
}
