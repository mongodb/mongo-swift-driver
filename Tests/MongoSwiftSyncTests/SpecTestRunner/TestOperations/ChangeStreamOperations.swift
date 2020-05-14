import MongoSwiftSync

struct Watch: TestOperation {
    func execute(on client: MongoClient, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        _ = try client.watch()
        return nil
    }

    func execute(on database: MongoDatabase, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        _ = try database.watch()
        return nil
    }

    func execute(
        on collection: MongoCollection<Document>,
        sessions _: [String: ClientSession]
    ) throws -> TestOperationResult? {
        _ = try collection.watch()
        return nil
    }
}
