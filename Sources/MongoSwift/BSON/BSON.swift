import Foundation

/// Enum representing a BSON value.
/// - SeeAlso: bsonspec.org
public enum BSON {
    /// A BSON double.
    case double(Double)

    /// A BSON string.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/bson-types/#string
    case string(String)

    /// A BSON document.
    case document(Document)

    /// A BSON array.
    indirect case array([BSON])

    /// A BSON binary.
    case binary(Binary)

    /// A BSON undefined.
    case undefined

    /// A BSON ObjectId.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/bson-types/#objectid
    case objectId(ObjectId)

    /// A BSON boolean.
    case bool(Bool)

    /// A BSON UTC datetime.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/bson-types/#date
    case datetime(Date)

    /// A BSON null.
    case null

    /// A BSON regular expression.
    case regex(RegularExpression)

    /// A BSON dbPointer.
    case dbPointer(DBPointer)

    /// A BSON symbol.
    case symbol(Symbol)

    /// A BSON JavaScript code.
    case code(Code)

    /// A BSON JavaScript code with scope.
    case codeWithScope(CodeWithScope)

    /// A BSON int32.
    case int32(Int32)

    /// A BSON timestamp.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/bson-types/#timestamps
    case timestamp(Timestamp)

    /// A BSON int64.
    case int64(Int64)

    /// A BSON Decimal128.
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.rst
    case decimal128(Decimal128)

    /// A BSON minKey.
    case minKey

    /// A BSON maxKey.
    case maxKey

    /// Initialize a `BSON` from an integer. On 64-bit systems, this will result in an `.int64`. On 32-bit systems,
    /// this will result in an `.int32`.
    public init(_ int: Int) {
        if MemoryLayout<Int>.size == 4 {
            self = .int32(Int32(int))
        } else {
            self = .int64(Int64(int))
        }
    }

    /// Get the `BSONType` of this `BSON`.
    public var type: BSONType {
        return self.bsonValue.bsonType
    }

    /// If this `BSON` is an `.int32`, return it as an `Int32`. Otherwise, return nil.
    public var int32Value: Int32? {
        guard case let .int32(i) = self else {
            return nil
        }
        return i
    }

    /// If this `BSON` is a `.regex`, return it as a `RegularExpression`. Otherwise, return nil.
    public var regexValue: RegularExpression? {
        guard case let .regex(r) = self else {
            return nil
        }
        return r
    }

    /// If this `BSON` is a `.codeWithScope`, return it as a `CodeWithScope`. Otherwise, return nil.
    public var codeWithScopeValue: CodeWithScope? {
        guard case let .codeWithScope(cws) = self else {
            return nil
        }
        return cws
    }

    /// If this `BSON` is a `.code`, return it as a `Code`. Otherwise, return nil.
    public var codeValue: Code? {
        guard case let .code(c) = self else {
            return nil
        }
        return c
    }

    /// If this `BSON` is an `.int64`, return it as an `Int64`. Otherwise, return nil.
    public var int64Value: Int64? {
        guard case let .int64(i) = self else {
            return nil
        }
        return i
    }

    /// If this `BSON` is an `.objectId`, return it as an `ObjectId`. Otherwise, return nil.
    public var objectIdValue: ObjectId? {
        guard case let .objectId(o) = self else {
            return nil
        }
        return o
    }

    /// If this `BSON` is a `.date`, return it as a `Date`. Otherwise, return nil.
    public var dateValue: Date? {
        guard case let .datetime(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is an `.array`, return it as an `[BSON]`. Otherwise, return nil.
    public var arrayValue: [BSON]? {
        guard case let .array(a) = self else {
            return nil
        }
        return a
    }

    /// If this `BSON` is a `.string`, return it as a `String`. Otherwise, return nil.
    public var stringValue: String? {
        guard case let .string(s) = self else {
            return nil
        }
        return s
    }

    /// If this `BSON` is a `.document`, return it as a `Document`. Otherwise, return nil.
    public var documentValue: Document? {
        guard case let .document(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.bool`, return it as an `Bool`. Otherwise, return nil.
    public var boolValue: Bool? {
        guard case let .bool(b) = self else {
            return nil
        }
        return b
    }

    /// If this `BSON` is a `.binary`, return it as a `Binary`. Otherwise, return nil.
    public var binaryValue: Binary? {
        guard case let .binary(b) = self else {
            return nil
        }
        return b
    }

    /// If this `BSON` is a `.double`, return it as a `Double`. Otherwise, return nil.
    public var doubleValue: Double? {
        guard case let .double(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.decimal128`, return it as a `Decimal128`. Otherwise, return nil.
    public var decimal128Value: Decimal128? {
        guard case let .decimal128(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.symbol`, return it as a `Symbol`. Otherwise, return nil.
    public var symbolValue: Symbol? {
        guard case let .symbol(s) = self else {
            return nil
        }
        return s
    }

    /// If this `BSON` is a `.dbPointer`, return it as a `DBPointer`. Otherwise, return nil.
    public var dbPointerValue: DBPointer? {
        guard case let .dbPointer(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.timestamp`, return it as a `Timestamp`. Otherwise, return nil.
    public var timestampValue: Timestamp? {
        guard case let .timestamp(t) = self else {
            return nil
        }
        return t
    }

    /// Return this BSON as an `Int` if possible.
    /// This will coerce non-integer numeric cases (e.g. `.double`) into an `Int` if such coercion would be lossless.
    public func asInt() -> Int? {
        switch self {
        case let .int32(value):
            return Int(value)
        case let .int64(value):
            return Int(exactly: value)
        case let .double(value):
            return Int(exactly: value)
        default:
            return nil
        }
    }

    /// Return this BSON as an `Int32` if possible.
    /// This will coerce numeric cases (e.g. `.double`) into an `Int32` if such coercion would be lossless.
    public func asInt32() -> Int32? {
        switch self {
        case let .int32(value):
            return value
        case let .int64(value):
            return Int32(exactly: value)
        case let .double(value):
            return Int32(exactly: value)
        default:
            return nil
        }
    }

    /// Return this BSON as an `Int64` if possible.
    /// This will coerce numeric cases (e.g. `.double`) into an `Int64` if such coercion would be lossless.
    public func asInt64() -> Int64? {
        switch self {
        case let .int32(value):
            return Int64(value)
        case let .int64(value):
            return value
        case let .double(value):
            return Int64(exactly: value)
        default:
            return nil
        }
    }

    /// Return this BSON as a `Double` if possible.
    /// This will coerce numeric cases (e.g. `.decimal128`) into a `Double` if such coercion would be lossless.
    public func asDouble() -> Double? {
        switch self {
        case let .double(d):
            return d
        default:
            guard let intValue = self.asInt() else {
                return nil
            }
            return Double(intValue)
        }
    }

    /// Return this BSON as a `Decimal128` if possible.
    /// This will coerce numeric cases (e.g. `.double`) into a `Decimal128` if such coercion would be lossless.
    public func asDecimal128() -> Decimal128? {
        switch self {
        case let .decimal128(d):
            return d
        case let .int64(i):
            return Decimal128(String(i))
        case let .int32(i):
            return Decimal128(String(i))
        case let .double(d):
            return Decimal128(String(d))
        default:
            return nil
        }
    }
}

/// Extension providing the internal API of `BSON`
extension BSON {
    /// List of all BSONValue types. Can be used to exhaustively check each one at runtime.
    internal static var allBSONTypes: [BSONValue.Type] = [
        BSONNull.self,
        BSONUndefined.self,
        MinKey.self,
        MaxKey.self,
        Symbol.self,
        Double.self,
        String.self,
        Document.self,
        Binary.self,
        ObjectId.self,
        Bool.self,
        Date.self,
        RegularExpression.self,
        DBPointer.self,
        Code.self,
        CodeWithScope.self,
        Int32.self,
        Timestamp.self,
        Int64.self,
        [BSON].self,
        Decimal128.self
    ]

    /// Get the associated `BSONValue` to this `BSON` case.
    internal var bsonValue: BSONValue {
        switch self {
        case .null:
            return BSONNull()
        case .undefined:
            return BSONUndefined()
        case .minKey:
            return MinKey()
        case .maxKey:
            return MaxKey()
        case let .symbol(v):
            return v
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
        case let .datetime(v):
            return v
        case let .regex(v):
            return v
        case let .dbPointer(v):
            return v
        case let .code(v):
            return v
        case let .codeWithScope(v):
            return v
        case let .int32(v):
            return v
        case let .timestamp(v):
            return v
        case let .int64(v):
            return v
        case let .array(v):
            return v
        case let .decimal128(v):
            return v
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
    /// Initialize a `BSON` from an integer. On 64-bit systems, this will result in an `.int64`. On 32-bit systems,
    /// this will result in an `.int32`.
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension BSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BSON)...) {
        self = .document(Document(keyValuePairs: elements))
    }
}

extension BSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: BSON...) {
        self = .array(elements)
    }
}

extension BSON: Equatable {}

extension BSON: Hashable {}

extension BSON: Codable {
    public init(from decoder: Decoder) throws {
        if let bsonDecoder = decoder as? _BSONDecoder {
            // This path only taken if a BSON is directly decoded at the top-level. Otherwise execution will never reach
            // this point.
            self = try bsonDecoder.decodeBSON()
        } else {
            // This path is taken no matter what when a non-BSONDecoder is used.
            for bsonType in BSON.allBSONTypes {
                if let value = try? bsonType.init(from: decoder) {
                    self = value.bson
                }
            }

            throw DecodingError.typeMismatch(
                BSON.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Encountered a value that could not be decoded to any BSON type"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        // This is only reached when a non-BSON encoder is used.
        try self.bsonValue.encode(to: encoder)
    }
}
