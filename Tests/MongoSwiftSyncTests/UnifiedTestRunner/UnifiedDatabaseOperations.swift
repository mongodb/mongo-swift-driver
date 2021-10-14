import MongoSwiftSync
import SwiftBSON
struct UnifiedCreateCollection: UnifiedOperationProtocol {
    /// The collection to create.
    let collection: String

    /// Optional identifier for a session entity to use.
    let session: String?

    let options: CreateCollectionOptions

    enum CodingKeys: String, CodingKey, CaseIterable {
        case collection, session
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(CreateCollectionOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.collection = try container.decode(String.self, forKey: .collection)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                CreateCollectionOptions().propertyNames
        )
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let db = try context.entities.getEntity(from: object).asDatabase()
        let session = try context.entities.resolveSession(id: self.session)
        _ = try db.createCollection(self.collection, options: self.options, session: session)
        return .none
    }
}

struct UnifiedDropCollection: UnifiedOperationProtocol {
    /// The collection to drop.
    let collection: String

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        ["collection", "session"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let db = try context.entities.getEntity(from: object).asDatabase()
        let session = try context.entities.resolveSession(id: self.session)
        try db.collection(self.collection).drop(session: session)
        return .none
    }
}

struct UnifiedRunCommand: UnifiedOperationProtocol {
    /// The name of the command to run.
    let commandName: String

    /// The command to run.
    let command: BSONDocument

    static var knownArguments: Set<String> {
        ["commandName", "command"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        var orderedCommand = self.command
        // reorder if needed to put command name first.
        if self.command.keys.first != self.commandName {
            orderedCommand = [:]
            orderedCommand[self.commandName] = self.command[self.commandName]
            for (k, v) in self.command where k != self.commandName {
                orderedCommand[k] = v
            }
        }
        let db = try context.entities.getEntity(from: object).asDatabase()
        try db.runCommand(orderedCommand)
        return .none
    }
}

struct UnifiedListCollections: UnifiedOperationProtocol {
    /// Filter to use for the command.
    let filter: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    let options: ListCollectionsOptions

    enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, session
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(ListCollectionsOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                ListCollectionsOptions().propertyNames
        )
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let db = try context.entities.getEntity(from: object).asDatabase()
        let session = try context.entities.resolveSession(id: self.session)
        let results = try db.listCollections(self.filter, options: self.options, session: session)
        return .rootDocumentArray(try results.map { try $0.get() }.map { try BSONEncoder().encode($0) })
    }
}
