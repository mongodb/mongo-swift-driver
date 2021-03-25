import SwiftBSON
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
