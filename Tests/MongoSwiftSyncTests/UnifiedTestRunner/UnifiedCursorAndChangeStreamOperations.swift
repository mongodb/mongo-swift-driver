import Foundation
import MongoSwiftSync
import TestsCommon

struct CreateChangeStream: UnifiedOperationProtocol {
    /// Enables users to specify an arbitrary BSON type to help trace the operation through
    /// the database profiler, currentOp and logs. The default is to not send a value.
    let comment: BSON?

    /// Pipeline for the change stream.
    let pipeline: [BSONDocument]

    /// Options to use when creating the change stream.
    let options: ChangeStreamOptions

    /// Optional name of a session entity to use.
    let session: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case comment, pipeline, session
    }

    static var knownArguments: Set<String> {
        Set(CodingKeys.allCases.map { $0.rawValue }).union(
            Set(ChangeStreamOptions().propertyNames))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.comment = try container.decodeIfPresent(BSON.self, forKey: .comment)
        self.pipeline = try container.decode([BSONDocument].self, forKey: .pipeline)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(ChangeStreamOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let entity = try context.entities.getEntity(from: object)
        let session = try context.entities.resolveSession(id: self.session)
        let changeStream: ChangeStream<BSONDocument>
        switch entity {
        case let .client(testClient):
            changeStream = try testClient.client.watch(
                self.pipeline,
                options: self.options,
                session: session,
                withEventType: BSONDocument.self
            )
        case let .database(db):
            changeStream = try db.watch(
                self.pipeline,
                options: self.options,
                session: session,
                withEventType: BSONDocument.self
            )
        case let .collection(coll):
            changeStream = try coll.watch(
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

struct IterateUntilDocumentOrError: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let entity = try context.entities.getEntity(from: object)
        switch entity {
        case let .changeStream(cs):
            guard let next = cs.next() else {
                throw TestError(message: "Change stream unexpectedly exhausted")
            }
            return .rootDocument(try next.get())
        case let .findCursor(c):
            guard let next = c.next() else {
                throw TestError(message: "Cursor unexpectedly exhausted")
            }
            return .rootDocument(try next.get())
        default:
            throw TestError(message: "Unsupported entity type \(entity) for IterateUntilDocumentOrError operation")
        }
    }
}

struct UnifiedCloseCursor: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let entity = try context.entities.getEntity(from: object)
        switch entity {
        case let .changeStream(cs):
            cs.kill()
        case let .findCursor(c):
            c.kill()
        default:
            throw TestError(message: "Unsupported entity type \(entity) for close operation")
        }

        return .none
    }
}
