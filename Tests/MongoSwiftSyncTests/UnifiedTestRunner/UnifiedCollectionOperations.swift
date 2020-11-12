import Foundation
@testable import struct MongoSwift.FindOptions
import MongoSwiftSync

struct UnifiedFind: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Options to use for the operation.
    let options: FindOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case session, filter
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOptions.CodingKeys.allCases.map { $0.rawValue }
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decodeIfPresent(BSONDocument.self, forKey: .filter) ?? BSONDocument()
    }
}

struct UnifiedInsertOne: UnifiedOperationProtocol {
    /// Document to insert.
    let document: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    /// Options to use while executing the operation.
    let options: InsertOneOptions

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case document, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                Mirror(reflecting: InsertOneOptions()).children.map { $0.label! }
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.document = try container.decode(BSONDocument.self, forKey: .document)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(InsertOneOptions.self)
    }
}
