import Foundation

internal struct PureBSONNull {}

extension PureBSONNull: PureBSONValue {
    internal static var bsonType: BSONType { return .null }

    internal var bson: BSON { return .null }

    internal func toBSON() -> Data {
        return Data()
    }

    internal init(from data: inout Data) throws {}
}
