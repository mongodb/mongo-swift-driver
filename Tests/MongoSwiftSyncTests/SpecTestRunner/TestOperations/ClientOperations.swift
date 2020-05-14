import MongoSwiftSync

struct ListDatabaseNames: TestOperation {
    func execute(on client: MongoClient, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        try .array(client.listDatabaseNames().map(BSON.string))
    }
}

struct ListDatabases: TestOperation {
    func execute(on client: MongoClient, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        try TestOperationResult(from: client.listDatabases())
    }
}

struct ListMongoDatabases: TestOperation {
    func execute(on client: MongoClient, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        _ = try client.listMongoDatabases()
        return nil
    }
}
