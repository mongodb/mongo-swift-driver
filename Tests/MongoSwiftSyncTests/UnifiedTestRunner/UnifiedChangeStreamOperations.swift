import Foundation
import MongoSwiftSync
import TestsCommon

struct CreateChangeStream: UnifiedOperationProtocol {
    /// Pipeline for the change stream.
    let pipeline: [BSONDocument]

    /// Options to use when creating the change stream.
    let options: ChangeStreamOptions

    /// Optional name of a session entity to use.
    let session: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case pipeline, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                ChangeStreamOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pipeline = try container.decode([BSONDocument].self, forKey: .pipeline)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(ChangeStreamOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, entities: EntityMap) throws -> UnifiedOperationResult {
        let entity = try entities.getEntity(from: object)
        let session = try entities.resolveSession(id: self.session)
        switch entity {
        case let .client(testClient):
            let changeStream = try testClient.client.watch(
                self.pipeline,
                options: self.options,
                session: session,
                withEventType: BSONDocument.self
            )
            return .changeStream(changeStream)
        default:
            throw TestError(message: "Unsupported entity type \(entity) for createChangeStream operation")
        }
    }
}

struct IterateUntilDocumentOrError: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, entities: EntityMap) throws -> UnifiedOperationResult {
        let cs = try entities.getEntity(from: object).asChangeStream()
        guard let next = cs.next() else {
            throw TestError(message: "Change stream unexpectedly exhausted")
        }
        return .rootDocument(try next.get())
    }
}
