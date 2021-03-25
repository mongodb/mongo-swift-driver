import MongoSwiftSync

struct CreateCollection: TestOperation {
    let session: String?
    let collection: String

    func execute(on database: MongoDatabase, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        _ = try database.createCollection(self.collection, session: sessions[self.session ?? ""])
        return nil
    }
}

struct DropCollection: TestOperation {
    let session: String?
    let collection: String

    func execute(on database: MongoDatabase, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        _ = try database.collection(self.collection).drop(session: sessions[self.session ?? ""])
        return nil
    }
}

struct ListCollections: TestOperation {
    func execute(on database: MongoDatabase, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        try TestOperationResult(from: database.listCollections())
    }
}

struct ListMongoCollections: TestOperation {
    func execute(on database: MongoDatabase, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        _ = try database.listMongoCollections()
        return nil
    }
}

struct ListCollectionNames: TestOperation {
    func execute(on database: MongoDatabase, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        try .array(database.listCollectionNames().map { .string($0) })
    }
}

struct RunCommand: TestOperation {
    let session: String?
    let command: BSONDocument
    let readPreference: ReadPreference?

    /// Return a new `RunCommand` with the command document ordered such that the provided command name
    /// is the first key.
    func withCommandName(_ name: String) -> RunCommand {
        guard let command = self.command[name] else {
            fatalError("missing \"\(name)\" in \(self.command)")
        }
        var ordered: BSONDocument = [name: command]
        for (k, v) in self.command {
            guard k != name else {
                continue
            }
            ordered[k] = v
        }
        return RunCommand(session: self.session, command: ordered, readPreference: self.readPreference)
    }

    func execute(on database: MongoDatabase, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        let runCommandOptions = RunCommandOptions(readPreference: self.readPreference)
        let result = try database.runCommand(
            self.command,
            options: runCommandOptions,
            session: sessions[self.session ?? ""]
        )
        return TestOperationResult(from: result)
    }
}
