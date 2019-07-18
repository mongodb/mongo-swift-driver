import Foundation

/// A struct to represent the BSON Timestamp type.
public struct PureBSONTimestamp: Equatable, Hashable, Codable {
    /// A timestamp representing seconds since the Unix epoch.
    public let timestamp: UInt32
    /// An incrementing ordinal for operations within a given second.
    public let increment: UInt32

    /// Initializes a new  `Timestamp` with the provided `timestamp` and `increment` values.
    public init(timestamp: UInt32, inc: UInt32) {
        self.timestamp = timestamp
        self.increment = inc
    }

    /// Initializes a new  `Timestamp` with the provided `timestamp` and `increment` values. Assumes
    /// the values can successfully be converted to `UInt32`s without loss of precision.
    public init(timestamp: Int, inc: Int) {
        self.timestamp = UInt32(timestamp)
        self.increment = UInt32(inc)
    }
}

extension PureBSONTimestamp: PureBSONValue {
    internal static var bsonType: BSONType { return .timestamp }

    internal var bson: BSON { return .timestamp(self) }

    internal init(from data: inout Data) throws {
        guard data.count >= 8 else {
            throw RuntimeError.internalError(message: "expected to get at least 8 bytes, got \(data.count)")
        }

        self.timestamp = try readInteger(from: &data)
        self.increment = try readInteger(from: &data)
    }

    internal func toBSON() -> Data {
        var data = withUnsafeBytes(of: self.increment) { Data($0) }

        withUnsafePointer(to: self.increment) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 4) { (ptr: UnsafePointer<UInt8>) in
                data.append(ptr, count: 4)
            }
        }

        return data
    }
}
