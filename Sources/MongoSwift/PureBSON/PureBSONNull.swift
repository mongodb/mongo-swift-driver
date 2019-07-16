import Foundation

internal struct PureBSONNull {}

extension PureBSONNull: PureBSONValue {
    internal static var bsonType: BSONType { return .null }

    internal var bson: BSON { return .null }

    internal func toBSON() -> Data {
        return Data()
    }

    internal init(from data: Data) throws {
        guard data.isEmpty else {
            throw RuntimeError.internalError(message: "null buffer must be empty")
        }
    }
}
