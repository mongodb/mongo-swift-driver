import Foundation
import MongoSwiftSync

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
            CodingKeys.allCases.map(\.rawValue) +
                Mirror(reflecting: ChangeStreamOptions()).children.map { $0.label! }
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pipeline = try container.decode([BSONDocument].self, forKey: .pipeline)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(ChangeStreamOptions.self)
    }
}

struct IterateUntilDocumentOrError: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }
}
