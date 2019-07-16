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

    internal var bsonType: UInt8 {
        switch self {
        case .double:
            return 0x01
        case .string:
            return 0x02
        case .document:
            return 0x03
        // array
        case .binary:
            return 0x05
        case .undefined:
            return 0x06
        case .objectId:
            return 0x07
        case .bool:
            return 0x08
        case .date:
            return 0x09
        case .null:
            return 0x0A
        case .regex:
            return 0x0B
        case .dbPointer:
            return 0x0C
        // case code
        case .symbol:
            return 0x0E
        // code with scope
        case .int32:
            return 0x10
        case .timestamp:
            return 0x11
        case .int64:
            return 0x12
        // decimal128
        case .minKey:
            return 0xFF
        case .maxKey:
            return 0x7F
        }
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

internal protocol PureBSONValue {
    init(from data: Data) throws
    func toBSON() -> Data
}

extension PureBSONValue where Self: ExpressibleByIntegerLiteral {
    init(from data: Data) throws {
        guard data.count == MemoryLayout<Self>.size else {
            throw RuntimeError.internalError(message: "wrong buffer size")
        }
        self = try readInteger(from: data)
    }
}

extension PureBSONValue {
    func toBSON() -> Data {
        return withUnsafeBytes(of: self) { Data($0) }
    }
}

extension String: PureBSONValue {
    internal init(from data: Data) throws {
        let s = try readString(from: data)

        guard data.count == s.utf8.count + 4 else {
            throw RuntimeError.internalError(message: "extra data in String buffer")
        }

        self = s
    }

    internal func toBSON() -> Data {
        // `String`s are Unicode under the hood so force unwrap always succeeds.
        // see https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
        return self.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
    }
}

extension Bool: PureBSONValue {
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

internal struct InvalidBSONError: LocalizedError {
    internal let message: String

    internal init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        return self.message
    }
}

extension Double: PureBSONValue {
    public init(from data: Data) throws {
        var value = 0.0
        _ = withUnsafeMutableBytes(of: &value) {
            data.copyBytes(to: $0)
        }
        self = value
    }
}

extension Int32: PureBSONValue {}

extension Int64: PureBSONValue {}

extension Date: PureBSONValue {
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
