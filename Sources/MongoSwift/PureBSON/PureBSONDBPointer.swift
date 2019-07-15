import Foundation

/// A struct to represent the deprecated DBPointer type.
/// DBPointers cannot be instantiated, but they can be read from existing documents that contain them.
public struct PureBSONDBPointer: PureBSONValue {
    /// Destination namespace of the pointer.
    public let ref: String

    /// Destination _id (assumed to be an `ObjectId`) of the pointed-to document.
    public let id: ObjectId

    internal init(ref: String, id: ObjectId) {
        self.ref = ref
        self.id = id
    }

    internal init(from data: Data) throws {
        let ref = try readString(from: data)
        // TODO: ObjectId reading here
        self.init(ref: ref, id: ObjectId())
    }
}
