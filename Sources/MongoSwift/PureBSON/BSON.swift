import Foundation

public enum BSON {
    case double(Double)
    case string(String)
    case document(PureBSONDocument)
    // array
    case binary(PureBSONBinary)
    case undefined
    case objectId(PureBSONObjectId)
    case bool(Bool)
    case date(Date)
    case null
    case regex(PureBSONRegularExpression)
    case dbPointer(PureBSONDBPointer)
    // code
    case symbol(PureBSONSymbol)
    case codeWithScope(PureBSONCodeWithScope)
    case int32(Int32)
    case timestamp(PureBSONTimestamp)
    case int64(Int64)
    // decimal128
    case minKey
    case maxKey

    internal var bsonValue: PureBSONValue {
        switch self {
        case .null:
            return PureBSONNull()
        case .undefined:
            return PureBSONUndefined()
        case .minKey:
            return PureBSONMinKey()
        case .maxKey:
            return PureBSONMaxKey()
        case let .double(v):
            return v
        case let .string(v):
            return v
        case let .document(v):
            return v
        case let .binary(v):
            return v
        case let .objectId(v):
            return v
        case let .bool(v):
            return v
        case let .date(v):
            return v
        case let .regex(v):
            return v
        case let .dbPointer(v):
            return v
        case let .codeWithScope(v):
            return v
        case let .symbol(v):
            return v
        case let .int32(v):
            return v
        case let .timestamp(v):
            return v
        case let .int64(v):
            return v
        }
    }

    internal func toBSON() -> Data {
        return self.bsonValue.toBSON()
    }

    internal var bsonType: UInt8 {
        return UInt8(type(of: self.bsonValue).bsonType.rawValue)
    }
}

extension BSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension BSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension BSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension BSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int64(Int64(value))
    }
}

extension BSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BSON)...) {
        self = .document(PureBSONDocument(elements: elements))
    }
}

extension BSON: Equatable {}
extension BSON: Hashable {}

extension BSON: Codable {
    public init(from decoder: Decoder) throws {
        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        print("encoding \(self.bsonValue)")
        try self.bsonValue.encode(to: encoder)
    }
}

internal protocol PureBSONValue: Codable {
    init(from data: Data) throws
    func toBSON() -> Data
    var bson: BSON { get }
    static var bsonType: BSONType { get }
}

extension PureBSONValue where Self: ExpressibleByIntegerLiteral {
    init(from data: Data) throws {
        guard data.count == MemoryLayout<Self>.size else {
            throw RuntimeError.internalError(message: "wrong buffer size")
        }
        self = try readInteger(from: data)
    }
}

extension PureBSONValue where Self: Numeric {
    func toBSON() -> Data {
        return withUnsafeBytes(of: self) { Data($0) }
    }
}

extension String: PureBSONValue {
    internal static var bsonType: BSONType { return .string }

    internal var bson: BSON { return .string(self) }

    internal init(from data: Data) throws {
        let s = try readString(from: data)

        guard data.count == s.utf8.count + 4 else {
            throw RuntimeError.internalError(message: "extra data in String buffer")
        }

        self = s
    }

    /// Given utf8-encoded `Data`, reads from the start up to the first null byte and constructs a String from it
    internal init?(cStringData: Data) {
        let bytes = cStringData.prefix { $0 != 0 }
        self.init(bytes: bytes, encoding: .utf8)
    }

    internal func toBSON() -> Data {
        var data = Data()
        let cStringData = self.toCStringData()
        data.append(Int32(cStringData.count).toBSON())
        data.append(cStringData)
        return data
    }

    internal func toCStringData() -> Data {
        var data = Data()
        data.append(contentsOf: self.utf8)
        data.append(0)
        return data
    }
}

extension Bool: PureBSONValue {
    internal static var bsonType: BSONType { return .boolean }

    internal var bson: BSON { return .bool(self) }

    internal init(from data: Data) throws {
        guard data.count == 1 else {
            throw RuntimeError.internalError(message: "Expected to get 1 byte, got \(data.count)")
        }
        switch data[0] {
        case 0:
            self = false
        case 1:
            self = true
        default:
            throw InvalidBSONError("Unable to initialize Bool from byte \(data[0])")
        }
    }

    internal func toBSON() -> Data {
        return self ? Data([1]) : Data([0])
    }
}

extension Double: PureBSONValue {
    internal static var bsonType: BSONType { return .double }

    internal var bson: BSON { return .double(self) }

    public init(from data: Data) throws {
        var value = 0.0
        _ = withUnsafeMutableBytes(of: &value) {
            data.copyBytes(to: $0)
        }
        self = value
    }
}

extension Int32: PureBSONValue {
    internal static var bsonType: BSONType { return .int32 }

    internal var bson: BSON { return .int32(self) }
}

extension Int64: PureBSONValue {
    internal static var bsonType: BSONType { return .int64 }

    internal var bson: BSON { return .int64(self) }
}

extension Date: PureBSONValue {
    internal static var bsonType: BSONType { return .dateTime }

    internal var bson: BSON { return .date(self) }

    internal init(from data: Data) throws {
        self.init(msSinceEpoch: try Int64(from: data))
    }

    internal func toBSON() -> Data {
        return self.msSinceEpoch.toBSON()
    }
}

/// Reads a `String` according to the "string" non-terminal of the BSON spec.
internal func readString(from data: Data) throws -> String {
    let length = try Int32(from: data[0..<4])

    guard data.count >= length + 4 && data[3 + Int(length)] == 0 else {
        throw RuntimeError.internalError(message: "invalid buffer")
    }

    return data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> String in
        String(cString: ptr)
    }
}

/// Reads an integer type from the data. Throws if buffer is too small.
internal func readInteger<T: ExpressibleByIntegerLiteral>(from data: Data) throws -> T {
    guard data.count >= MemoryLayout<T>.size else {
        throw RuntimeError.internalError(message: "Buffer not large enough to read \(T.self) from")
    }
    var value: T = 0
    _ = withUnsafeMutableBytes(of: &value) {
        data.copyBytes(to: $0)
    }
    return value
}

internal struct InvalidBSONError: LocalizedError {
    internal let message: String

    internal init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        return self.message
    }
}
