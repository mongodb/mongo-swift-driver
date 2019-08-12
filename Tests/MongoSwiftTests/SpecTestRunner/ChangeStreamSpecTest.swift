import mongoc
@testable import MongoSwift
import Nimble
import XCTest

internal enum ChangeStreamTarget: String, Decodable {
    case client
    case database
    case collection

    internal func watch(_ client: MongoClient,
                        _ database: String?,
                        _ collection: String?,
                        _ pipeline: [Document],
                        _ options: ChangeStreamOptions) throws -> ChangeStream<ChangeStreamTestEvent> {
        switch self {
        case .client:
            return try client.watch(pipeline, options: options, withEventType: ChangeStreamTestEvent.self)
        case .database:
            guard let database = database else {
                throw RuntimeError.internalError(message: "missing db in watch")
            }
            return try client.db(database).watch(pipeline, options: options, withEventType: ChangeStreamTestEvent.self)
        case .collection:
            guard let collection = collection, let database = database else {
                throw RuntimeError.internalError(message: "missing collection in watch")
            }
            return try client.db(database)
                    .collection(collection)
                    .watch(pipeline, options: options, withEventType: ChangeStreamTestEvent.self)
        }
    }
}

internal struct ChangeStreamTestOperation: Decodable {
    private let anyTestOperation: AnyTestOperation

    private let database: String

    private let collection: String

    private enum CodingKeys: String, CodingKey {
        case database, collection
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.database = try container.decode(String.self, forKey: .database)
        self.collection = try container.decode(String.self, forKey: .collection)
        self.anyTestOperation = try AnyTestOperation(from: decoder)
    }

    internal func execute(using client: MongoClient) throws -> TestOperationResult? {
        let db = client.db(self.database)
        let coll = db.collection(self.collection)
        return try self.anyTestOperation.op.execute(client: client, database: db, collection: coll, session: nil)
    }
}

internal enum ChangeStreamTestResult: Decodable {
    /// Describes an error received during the test
    case error(code: Int, labels: [String]?)

    /// An Extended JSON array of documents expected to be received from the changeStream
    case success([ChangeStreamTestEvent])

    internal enum CodingKeys: CodingKey {
        case error, success
    }

    internal enum ErrorCodingKeys: CodingKey {
        case code, errorLabels
    }

    internal func matchesError(error: Error, description: String) {
        guard case let .error(code, labels) = self else {
            fail("\(description) failed: got error but result success")
            return
        }
        guard case let ServerError.commandError(seenCode, _, _, seenLabels) = error else {
            fail("\(description) failed: didn't get command error")
            return
        }

        expect(code).to(equal(seenCode), description: description)
        if let labels = labels {
            expect(seenLabels).toNot(beNil(), description: description)
            expect(seenLabels).to(equal(labels), description: description)
        } else {
            expect(seenLabels).to(beNil(), description: description)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.success) {
            self = .success(try container.decode([ChangeStreamTestEvent].self, forKey: .success))
        } else {
            let nested = try container.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .error)
            let code = try nested.decode(Int.self, forKey: .code)
            let labels = try nested.decodeIfPresent([String].self, forKey: .errorLabels)
            self = .error(code: code, labels: labels)
        }
    }
}

internal struct ChangeStreamTestEvent: Codable, Equatable {
    let operationType: String

    let ns: MongoNamespace?

    let fullDocument: Document?

    public static func == (lhs: ChangeStreamTestEvent, rhs: ChangeStreamTestEvent) -> Bool {
        let lhsFullDoc = lhs.fullDocument?.filter { $0.key != "_id" }
        let rhsFullDoc = rhs.fullDocument?.filter { $0.key != "_id" }
        return lhsFullDoc == rhsFullDoc && lhs.ns == rhs.ns && lhs.operationType == rhs.operationType
    }
}
