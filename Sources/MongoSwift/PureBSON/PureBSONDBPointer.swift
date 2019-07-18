import Foundation

/// A struct to represent the deprecated DBPointer type.
/// DBPointers cannot be instantiated, but they can be read from existing documents that contain them.
public struct PureBSONDBPointer: Codable {
    /// Destination namespace of the pointer.
    public let ref: String

    /// Destination _id (assumed to be an `ObjectId`) of the pointed-to document.
    public let id: PureBSONObjectId

    internal init(ref: String, id: PureBSONObjectId) {
        self.ref = ref
        self.id = id
    }
}

extension PureBSONDBPointer: Equatable {}

extension PureBSONDBPointer: Hashable {}

extension PureBSONDBPointer: PureBSONValue {
    internal static var bsonType: BSONType { return .dbPointer }

    internal var bson: BSON { return .dbPointer(self) }

    internal init(from data: inout Data) throws {
        guard data.count >= 5 + 12 else {
            throw RuntimeError.internalError(message: "expected to get at least 17 bytes, got \(data.count)")
        }
        let ref = try readString(from: &data)
        let id = try PureBSONObjectId(from: &data)
        self.init(ref: ref, id: id)
    }

    internal func toBSON() -> Data {
        var data = self.ref.toBSON()
        data.append(self.id.toBSON())
        return data
    }
}
