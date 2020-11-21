import Foundation
@testable import struct MongoSwift.AggregateOptions
@testable import struct MongoSwift.FindOptions
import MongoSwiftSync

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

    func execute(on object: UnifiedOperation.Object, entities: EntityMap) throws -> UnifiedOperationResult {
        let collection = try entities.getEntityAsCollection(from: object)
        let session = try entities.resolveSession(id: self.session)
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
}
