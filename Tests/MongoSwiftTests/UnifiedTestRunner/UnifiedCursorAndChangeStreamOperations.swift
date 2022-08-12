#if compiler(>=5.5.2) && canImport(_Concurrency)
import Foundation
import MongoSwift
import TestsCommon

@available(macOS 10.15, *)
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
        Set(CodingKeys.allCases.map { $0.rawValue }).union(
            Set(ChangeStreamOptions().propertyNames))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pipeline = try container.decode([BSONDocument].self, forKey: .pipeline)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(ChangeStreamOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let entity = try context.entities.getEntity(from: object)
        let session = try context.entities.resolveSession(id: self.session)
        let changeStream: ChangeStream<BSONDocument>
        switch entity {
        case let .client(testClient):
            changeStream = try await testClient.client.watch(
                self.pipeline,
                options: self.options,
                session: session,
                withEventType: BSONDocument.self
            )
        case let .database(db):
            changeStream = try await db.watch(
                self.pipeline,
                options: self.options,
                session: session,
                withEventType: BSONDocument.self
            )
        case let .collection(coll):
            changeStream = try await coll.watch(
                self.pipeline,
                options: self.options,
                session: session,
                withEventType: BSONDocument.self
            )
        default:
            throw TestError(message: "Unsupported entity type \(entity) for createChangeStream operation")
        }

        return .changeStream(changeStream)
    }
}

@available(macOS 10.15, *)
struct IterateUntilDocumentOrError: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let entity = try context.entities.getEntity(from: object)
        switch entity {
        case let .changeStream(cs):
            guard let next = try await cs.next() else {
                throw TestError(message: "Change stream unexpectedly exhausted")
            }
            return .rootDocument(next)
        case let .findCursor(c):
            guard let next = try await c.next() else {
                throw TestError(message: "Cursor unexpectedly exhausted")
            }
            return .rootDocument(next)
        default:
            throw TestError(message: "Unsupported entity type \(entity) for IterateUntilDocumentOrError operation")
        }
    }
}

@available(macOS 10.15, *)
struct UnifiedCloseCursor: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let entity = try context.entities.getEntity(from: object)
        switch entity {
        case let .changeStream(cs):
            _ = try await cs.kill().get()
        case let .findCursor(c):
            _ = try await c.kill().get()
        default:
            throw TestError(message: "Unsupported entity type \(entity) for close operation")
        }

        return .none
    }
}
#endif
