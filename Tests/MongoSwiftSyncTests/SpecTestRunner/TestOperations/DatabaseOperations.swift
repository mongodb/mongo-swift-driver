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
    let command: Document
    let readPreference: ReadPreference?

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
