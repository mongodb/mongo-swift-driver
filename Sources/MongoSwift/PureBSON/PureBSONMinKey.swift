import Foundation

internal struct PureBSONMinKey {}

extension PureBSONMinKey: PureBSONValue {
    internal static var bsonType: BSONType { return .minKey }

    internal var bson: BSON { return .minKey }

    internal func toBSON() -> Data {
        return Data()
    }

    internal init(from data: Data) throws {
        guard data.isEmpty else {
            throw RuntimeError.internalError(message: "minKey buffer must be empty")
        }
    }
}
