@testable import MongoSwift
@testable import MongoSwiftSync
import Nimble

struct AssertNumberConnectionsCheckedOut: UnifiedOperationProtocol {
    /// The name of the client entity to perform the assertion on.
    let client: String

    /// The number of connections expected to be checked out.
    let connections: Int

    static var knownArguments: Set<String> {
        ["client", "connections"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let testClient = try context.entities.getEntity(id: self.client).asTestClient()
        let actualCheckedOut = testClient.client.asyncClient.connectionPool.checkedOutConnections
        expect(actualCheckedOut).to(
            equal(self.connections),
            description: "Number of checked out connections did not match expected. Path: \(context.path)"
        )
        return .none
    }
}

struct UnifiedListDatabases: UnifiedOperationProtocol {
    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> { ["session"] }

    init() {
        self.session = nil
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let testClient = try context.entities.getEntity(from: object).asTestClient()
        let session = try context.entities.resolveSession(id: self.session)
        let dbSpecs = try testClient.client.listDatabases(session: session)
        let encoded = try BSONEncoder().encode(dbSpecs)
        return .bson(.array(encoded.map { .document($0) }))
    }
}
