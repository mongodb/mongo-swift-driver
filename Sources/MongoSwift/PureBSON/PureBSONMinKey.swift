import Foundation

internal struct PureBSONMinKey {}

extension PureBSONMinKey: PureBSONValue {
    internal static var bsonType: BSONType { return .minKey }

    internal var bson: BSON { return .minKey }

    internal func toBSON() -> Data {
        return Data()
    }

    internal init(from data: inout Data) throws {}
}
