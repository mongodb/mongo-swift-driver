import MongoSwiftSync
import TestsCommon

/// Intermediate representation of a bulk write model to match the test format, used for decoding purposes.
enum TestWriteModel: Decodable {
    case insertOne(BSONDocument)
    case deleteOne(BSONDocument, options: DeleteModelOptions)
    case deleteMany(BSONDocument, options: DeleteModelOptions)
    case updateOne(filter: BSONDocument, update: BSONDocument, options: UpdateModelOptions)
    case updateMany(filter: BSONDocument, update: BSONDocument, options: UpdateModelOptions)
    case replaceOne(filter: BSONDocument, replacement: BSONDocument, options: ReplaceOneModelOptions)

    enum CodingKeys: String, CodingKey {
        // Only one of these will ever be present.
        case insertOne, deleteOne, deleteMany, replaceOne, updateOne, updateMany
    }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let matchedKey: CodingKeys

        if let nested = try? container.nestedContainer(keyedBy: InsertOneKeys.self, forKey: .insertOne) {
            let doc = try nested.decode(BSONDocument.self, forKey: .document)
            self = .insertOne(doc)
            matchedKey = .insertOne
        } else if let nested = try? container.nestedContainer(keyedBy: DeleteKeys.self, forKey: .deleteOne) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let options = try container.decode(DeleteModelOptions.self, forKey: .deleteOne)
            self = .deleteOne(filter, options: options)
            matchedKey = .deleteOne
        } else if let nested = try? container.nestedContainer(keyedBy: DeleteKeys.self, forKey: .deleteMany) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let options = try container.decode(DeleteModelOptions.self, forKey: .deleteMany)
            self = .deleteMany(filter, options: options)
            matchedKey = .deleteMany
        } else if let nested = try? container.nestedContainer(keyedBy: ReplaceOneKeys.self, forKey: .replaceOne) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            let replacement = try nested.decode(BSONDocument.self, forKey: .replacement)
            let options = try container.decode(ReplaceOneModelOptions.self, forKey: .replaceOne)
            self = .replaceOne(filter: filter, replacement: replacement, options: options)
            matchedKey = .replaceOne
        } else if let nested = try? container.nestedContainer(keyedBy: UpdateKeys.self, forKey: .updateOne) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            // TODO: SWIFT-560 handle decoding pipelines properly
            let update = (try? nested.decode(BSONDocument.self, forKey: .update)) ?? [:]
            let options = try container.decode(UpdateModelOptions.self, forKey: .updateOne)
            self = .updateOne(filter: filter, update: update, options: options)
            matchedKey = .updateOne
        } else if let nested = try? container.nestedContainer(keyedBy: UpdateKeys.self, forKey: .updateMany) {
            let filter = try nested.decode(BSONDocument.self, forKey: .filter)
            // TODO: SWIFT-560 handle decoding pipelines properly
            let update = (try? nested.decode(BSONDocument.self, forKey: .update)) ?? [:]
            let options = try container.decode(UpdateModelOptions.self, forKey: .updateMany)
            self = .updateMany(filter: filter, update: update, options: options)
            matchedKey = .updateMany
        } else {
            throw DecodingError.typeMismatch(
                TestWriteModel.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown write model"
                )
            )
        }

        let rawArgs = try container.decode(BSONDocument.self, forKey: matchedKey).keys
        for arg in rawArgs where !self.knownArguments.contains(arg) {
            throw TestError(message: "Unsupported argument for bulkWrite \(matchedKey.rawValue): \(arg)")
        }
    }

    /// Known arguments for each type of write model.
    var knownArguments: Set<String> {
        switch self {
        case .insertOne:
            return Set(InsertOneKeys.allCases.map { $0.stringValue })
        case .deleteOne, .deleteMany:
            return Set(DeleteKeys.allCases.map { $0.stringValue } + DeleteModelOptions().propertyNames)
        case .updateOne, .updateMany:
            return Set(UpdateKeys.allCases.map { $0.stringValue } + UpdateModelOptions().propertyNames)
        case .replaceOne:
            return Set(ReplaceOneKeys.allCases.map { $0.stringValue } + ReplaceOneModelOptions().propertyNames)
        }
    }

    /// Converts to the WriteModel type used in the driver's public API.
    func toWriteModel() -> WriteModel<BSONDocument> {
        switch self {
        case let .insertOne(doc):
            return .insertOne(doc)
        case let .deleteOne(filter, options):
            return .deleteOne(filter, options: options)
        case let .deleteMany(filter, options):
            return .deleteMany(filter, options: options)
        case let .updateOne(filter, update, options):
            return .updateOne(filter: filter, update: update, options: options)
        case let .updateMany(filter, update, options):
            return .updateMany(filter: filter, update: update, options: options)
        case let .replaceOne(filter, replacement, options):
            return .replaceOne(filter: filter, replacement: replacement, options: options)
        }
    }
}
