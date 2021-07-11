import MongoSwiftSync
struct UnifiedCreateCollection: UnifiedOperationProtocol {
    /// The collection to create.
    let collection: String

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        ["collection", "session"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let db = try context.entities.getEntity(from: object).asDatabase()
        let session = try context.entities.resolveSession(id: self.session)
        _ = try db.createCollection(self.collection, session: session)
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
    /// The command to run.
    let command: BSONDocument

    /// The name of the command to run. Used for reordering the document to put the command name first.
    let commandName: String

    static var knownArguments: Set<String> {
        ["command", "commandName"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let db = try context.entities.getEntity(from: object).asDatabase()
        var ordered: BSONDocument = [:]
        ordered[commandName] = self.command[self.commandName]!
        for (k, v) in self.command where k != self.commandName {
            ordered[k] = v
        }
        let result = try db.runCommand(ordered)
        return .rootDocument(result)
    }
}
