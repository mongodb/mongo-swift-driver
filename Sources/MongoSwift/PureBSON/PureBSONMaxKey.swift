import Foundation

internal struct PureBSONMaxKey {}

extension PureBSONMaxKey: PureBSONValue {
    internal static var bsonType: BSONType { return .maxKey }

    internal var bson: BSON { return .maxKey }

    internal func toBSON() -> Data {
        return Data()
    }

    internal init(from data: Data) throws {
        guard data.isEmpty else {
            throw RuntimeError.internalError(message: "minKey buffer must be empty")
        }
    }
}
