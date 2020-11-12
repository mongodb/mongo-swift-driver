import Foundation
@testable import struct MongoSwift.FindOptions
import MongoSwiftSync
import TestsCommon

// File containing the TestOperations executed on a collections.

struct Aggregate: TestOperation {
    let session: String?
    let pipeline: [BSONDocument]
    let options: AggregateOptions

    private enum CodingKeys: String, CodingKey { case session, pipeline }

    init(from decoder: Decoder) throws {
        self.options = try AggregateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.pipeline = try container.decode([BSONDocument].self, forKey: .pipeline)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let cursor =
            try collection.aggregate(self.pipeline, options: self.options, session: sessions[self.session ?? ""])
        return try TestOperationResult(from: cursor)
    }
}

struct CountDocuments: TestOperation {
    let session: String?
    let filter: BSONDocument
    let options: CountDocumentsOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try CountDocumentsOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        .int(try collection.countDocuments(self.filter, options: self.options, session: sessions[self.session ?? ""]))
    }
}

struct Distinct: TestOperation {
    let session: String?
    let fieldName: String
    let filter: BSONDocument?
    let options: DistinctOptions

    private enum CodingKeys: String, CodingKey { case session, fieldName, filter }

    init(from decoder: Decoder) throws {
        self.options = try DistinctOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.fieldName = try container.decode(String.self, forKey: .fieldName)
        self.filter = try container.decodeIfPresent(BSONDocument.self, forKey: .filter)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
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
    let filter: BSONDocument
    let options: FindOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = (try container.decodeIfPresent(BSONDocument.self, forKey: .filter)) ?? BSONDocument()
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        try TestOperationResult(
            from: try collection.find(self.filter, options: self.options, session: sessions[self.session ?? ""])
        )
    }
}

struct FindOne: TestOperation {
    let session: String?
    let filter: BSONDocument
    let options: FindOneOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOneOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let doc = try collection.findOne(self.filter, options: self.options, session: sessions[self.session ?? ""])
        return TestOperationResult(from: doc)
    }
}

struct UpdateOne: TestOperation {
    let session: String?
    let filter: BSONDocument
    let update: BSONDocument
    let options: UpdateOptions

    private enum CodingKeys: String, CodingKey { case session, filter, update }

    init(from decoder: Decoder) throws {
        self.options = try UpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.update = try container.decode(BSONDocument.self, forKey: .update)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
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
    let filter: BSONDocument
    let update: BSONDocument
    let options: UpdateOptions

    private enum CodingKeys: String, CodingKey { case session, filter, update }

    init(from decoder: Decoder) throws {
        self.options = try UpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.update = try container.decode(BSONDocument.self, forKey: .update)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
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
    let filter: BSONDocument
    let options: DeleteOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try DeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let result =
            try collection.deleteMany(self.filter, options: self.options, session: sessions[self.session ?? ""])
        return TestOperationResult(from: result)
    }
}

struct DeleteOne: TestOperation {
    let session: String?
    let filter: BSONDocument
    let options: DeleteOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try DeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let result = try collection.deleteOne(self.filter, options: self.options, session: sessions[self.session ?? ""])
        return TestOperationResult(from: result)
    }
}

struct InsertOne: TestOperation {
    let session: String?
    let document: BSONDocument

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let result = try collection.insertOne(self.document, session: sessions[self.session ?? ""])
        return TestOperationResult(from: result)
    }
}

struct InsertMany: TestOperation {
    let session: String?
    let documents: [BSONDocument]
    let options: InsertManyOptions?

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
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
    private enum InsertOneKeys: String, CodingKey, CaseIterable {
        case document
    }

    private enum DeleteKeys: String, CodingKey, CaseIterable {
        case filter
    }

    private enum ReplaceOneKeys: String, CodingKey, CaseIterable {
        case filter, replacement
    }

    private enum UpdateKeys: String, CodingKey, CaseIterable {
        case filter, update
    }

    private enum TestKey: CodingKey {
        case name
    }

    public init(from decoder: Decoder) throws {
        // Unfortunately, the representation of bulk write models in older spec tests e.g. retryable writes
        // is significantly different from the representation in the unified runner. Depending on the presence of a
        // top-level key "name" we detect which style this file uses.
        let container = try decoder.container(keyedBy: TestKey.self)
        if try container.decodeIfPresent(String.self, forKey: .name) != nil {
            self = try Self.oldDecode(from: decoder)
        } else {
            self = try Self.unifiedDecode(from: decoder)
        }
    }

    private enum OldCodingKeys: CodingKey {
        case name, arguments
    }

    static func oldDecode(from decoder: Decoder) throws -> Self {
        let container = try decoder.container(keyedBy: OldCodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)

        switch name {
        case "insertOne":
            let args = try container.nestedContainer(keyedBy: InsertOneKeys.self, forKey: .arguments)
            let doc = try args.decode(CollectionType.self, forKey: .document)
            return .insertOne(doc)
        case "deleteOne", "deleteMany":
            let options = try container.decode(DeleteModelOptions.self, forKey: .arguments)
            let args = try container.nestedContainer(keyedBy: DeleteKeys.self, forKey: .arguments)
            let filter = try args.decode(BSONDocument.self, forKey: .filter)
            return name == "deleteOne" ? .deleteOne(filter, options: options) : .deleteMany(filter, options: options)
        case "replaceOne":
            let options = try container.decode(ReplaceOneModelOptions.self, forKey: .arguments)
            let args = try container.nestedContainer(keyedBy: ReplaceOneKeys.self, forKey: .arguments)
            let filter = try args.decode(BSONDocument.self, forKey: .filter)
            let replacement = try args.decode(CollectionType.self, forKey: .replacement)
            return .replaceOne(filter: filter, replacement: replacement, options: options)
        case "updateOne", "updateMany":
            let options = try container.decode(UpdateModelOptions.self, forKey: .arguments)
            let args = try container.nestedContainer(keyedBy: UpdateKeys.self, forKey: .arguments)
            let filter = try args.decode(BSONDocument.self, forKey: .filter)
            let update = try args.decode(BSONDocument.self, forKey: .update)
            return name == "updateOne" ?
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

    enum NewCodingKeys: String, CodingKey {
        // Only one of these will ever be present.
        case insertOne, deleteOne, deleteMany, replaceOne, updateOne, updateMany
    }

    static func unifiedDecode(from decoder: Decoder) throws -> Self {
        let container = try decoder.container(keyedBy: NewCodingKeys.self)

        let model: WriteModel
        let matchedKey: NewCodingKeys

        if let nested = try? container.nestedContainer(keyedBy: InsertOneKeys.self, forKey: .insertOne) {
            let doc = try nested.decode(CollectionType.self, forKey: .document)
            model = .insertOne(doc)
            matchedKey = .insertOne
        } else if let nested = try? container.nestedContainer(keyedBy: DeleteKeys.self, forKey: .deleteOne) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let options = try container.decode(DeleteModelOptions.self, forKey: .deleteOne)
            model = .deleteOne(filter, options: options)
            matchedKey = .deleteOne
        } else if let nested = try? container.nestedContainer(keyedBy: DeleteKeys.self, forKey: .deleteMany) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let options = try container.decode(DeleteModelOptions.self, forKey: .deleteMany)
            model = .deleteMany(filter, options: options)
            matchedKey = .deleteMany
        } else if let nested = try? container.nestedContainer(keyedBy: ReplaceOneKeys.self, forKey: .replaceOne) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let replacement = try nested.decode(CollectionType.self, forKey: .replacement)
            let options = try container.decode(ReplaceOneModelOptions.self, forKey: .replaceOne)
            model = .replaceOne(filter: filter, replacement: replacement, options: options)
            matchedKey = .replaceOne
        } else if let nested = try? container.nestedContainer(keyedBy: UpdateKeys.self, forKey: .updateOne) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let update = try nested.decode(BSONDocument.self, forKey: .update)
            let options = try container.decode(UpdateModelOptions.self, forKey: .updateOne)
            model = .updateOne(filter: filter, update: update, options: options)
            matchedKey = .updateOne
        } else if let nested = try? container.nestedContainer(keyedBy: UpdateKeys.self, forKey: .updateMany) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let update = try nested.decode(BSONDocument.self, forKey: .update)
            let options = try container.decode(UpdateModelOptions.self, forKey: .updateMany)
            model = .updateMany(filter: filter, update: update, options: options)
            matchedKey = .updateMany
        } else {
            throw DecodingError.typeMismatch(
                WriteModel.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown write model"
                )
            )
        }

        let rawArgs = try container.decode(BSONDocument.self, forKey: matchedKey).keys
        for arg in rawArgs where !Self.knownArgsForWriteModelTypes[matchedKey.rawValue]!.contains(arg) {
            throw TestError(message: "Unsupported argument for bulkWrite \(matchedKey.rawValue): \(arg)")
        }

        return model
    }

    static var knownArgsForWriteModelTypes: [String: Set<String>] {
        [
            "insertOne": Set(InsertOneKeys.allCases.map { $0.stringValue }),
            "deleteOne": Set(DeleteKeys.allCases.map { $0.stringValue } + DeleteModelOptions().propertyNames),
            "deleteMany": Set(DeleteKeys.allCases.map { $0.stringValue } + DeleteModelOptions().propertyNames),
            "updateOne": Set(UpdateKeys.allCases.map { $0.stringValue } + UpdateModelOptions().propertyNames),
            "updateMany": Set(UpdateKeys.allCases.map { $0.stringValue } + UpdateModelOptions().propertyNames),
            "replaceOne": Set(ReplaceOneKeys.allCases.map { $0.stringValue } + ReplaceOneModelOptions().propertyNames)
        ]
    }
}

struct BulkWrite: TestOperation {
    let session: String?
    let requests: [WriteModel<BSONDocument>]
    let options: BulkWriteOptions?

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let result =
            try collection.bulkWrite(self.requests, options: self.options, session: sessions[self.session ?? ""])
        return TestOperationResult(from: result)
    }
}

struct FindOneAndUpdate: TestOperation {
    let session: String?
    let filter: BSONDocument
    let update: BSONDocument
    let options: FindOneAndUpdateOptions

    private enum CodingKeys: String, CodingKey { case session, filter, update }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndUpdateOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.update = try container.decode(BSONDocument.self, forKey: .update)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
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
    let filter: BSONDocument
    let options: FindOneAndDeleteOptions

    private enum CodingKeys: String, CodingKey { case session, filter }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndDeleteOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
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
    let filter: BSONDocument
    let replacement: BSONDocument
    let options: FindOneAndReplaceOptions

    private enum CodingKeys: String, CodingKey { case session, filter, replacement }

    init(from decoder: Decoder) throws {
        self.options = try FindOneAndReplaceOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.replacement = try container.decode(BSONDocument.self, forKey: .replacement)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
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
    let filter: BSONDocument
    let replacement: BSONDocument
    let options: ReplaceOptions

    private enum CodingKeys: String, CodingKey { case session, filter, replacement }

    init(from decoder: Decoder) throws {
        self.options = try ReplaceOptions(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.replacement = try container.decode(BSONDocument.self, forKey: .replacement)
    }

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let result = try collection.replaceOne(
            filter: self.filter,
            replacement: self.replacement,
            options: self.options,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}

struct RenameCollection: TestOperation {
    let session: String?
    let to: String

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let databaseName = collection.namespace.db
        let cmd: BSONDocument = [
            "renameCollection": .string(databaseName + "." + collection.name),
            "to": .string(databaseName + "." + self.to)
        ]
        let reply = try collection._client.db("admin").runCommand(cmd, session: sessions[self.session ?? ""])
        return TestOperationResult(from: reply)
    }
}

struct Drop: TestOperation {
    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions _: [String: ClientSession]
    ) throws -> TestOperationResult? {
        try collection.drop()
        return nil
    }
}

struct ListIndexes: TestOperation {
    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions _: [String: ClientSession]
    ) throws -> TestOperationResult? {
        try TestOperationResult(from: collection.listIndexes())
    }
}

struct ListIndexNames: TestOperation {
    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions _: [String: ClientSession]
    ) throws -> TestOperationResult? {
        try .array(collection.listIndexNames().map(BSON.string))
    }
}

struct EstimatedDocumentCount: TestOperation {
    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions _: [String: ClientSession]
    ) throws -> TestOperationResult? {
        try .int(collection.estimatedDocumentCount())
    }
}

struct CreateIndex: TestOperation {
    let session: String?
    let name: String
    let keys: BSONDocument

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult? {
        let indexOptions = IndexOptions(name: self.name)
        _ = try collection.createIndex(self.keys, indexOptions: indexOptions, session: sessions[self.session ?? ""])
        return nil
    }
}
