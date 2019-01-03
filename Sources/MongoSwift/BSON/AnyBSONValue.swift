import Foundation

/// A struct wrapping a `BSONValue` type that allows for encoding/
/// decoding and hashing `BSONValue`s of unknown type.
public struct AnyBSONValue: Codable, Hashable, Equatable {
    /// The `BSONValue` wrapped by this struct. 
    public let value: BSONValue

    /// Initializes a new `AnyBSONValue` wrapping the provided `BSONValue`.
    public init(_ value: BSONValue) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        // short-circuit in the `BSONEncoder` case
        if let bsonEncoder = encoder as? _BSONEncoder {
            bsonEncoder.storage.containers.append(self.value)
            return
        }

        // in this case, we need to wrap each value in an
        // `AnyBSONValue`, before we encode, because `[BSONValue]` 
        // is not considered `Encodable`
        if let arr = self.value as? [BSONValue] {
            let mapped = arr.map { AnyBSONValue($0) }
            try mapped.encode(to: encoder)
        } else {
            if let c = self.value as? Codable {
                try c.encode(to: encoder)
            } else {
                throw EncodingError.invalidValue(
                    self.value,
                    EncodingError.Context(codingPath: [],
                                          debugDescription: "Encountered a non-Codable value while encoding \(self)"))

            }
        }
    }

    public static func == (lhs: AnyBSONValue, rhs: AnyBSONValue) -> Bool {
        return bsonEquals(lhs.value, rhs.value)
    }

    /// Initializes a new `AnyBSONValue` from a `Decoder`. 
    ///
    /// Caveats for usage with `Decoder`s other than MongoSwift's `BSONDecoder` -
    /// 1) This method does *not* support initializing an `AnyBSONValue` wrapping
    /// a `Date`. This is because, in non-BSON formats, `Date`s are encoded
    /// as other types such as `Double` or `String`. We have no way of knowing 
    /// which type is the intended one when decoding to a `Document`, as `Document`s 
    /// can contain any `BSONValue` type, so for simplicity we always go with a 
    /// `Double` or a `String` over a `Date`.
    /// 2) Numeric values will be attempted to be decoded in the following
    /// order of types: `Int`, `Int32`, `Int64`, `Double`. The first one
    /// that can successfully represent the value with no loss of precision will 
    /// be used.
    // swiftlint:disable:next cyclomatic_complexity
    public init(from decoder: Decoder) throws {
        // short-circuit in the `BSONDecoder` case
        if let bsonDecoder = decoder as? _BSONDecoder {
            self.value = bsonDecoder.storage.topContainer
            return
        }

        let container = try decoder.singleValueContainer()

        // since we aren't sure which BSON type this is, just try decoding
        // to each of them and go with the first one that succeeds
        if container.decodeNil() {
            self.value = BSONNull()
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Binary.self) {
            self.value = value
        } else if let value = try? container.decode(ObjectId.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode(RegularExpression.self) {
            self.value = value
        } else if let value = try? container.decode(CodeWithScope.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Int32.self) {
            self.value = value
        } else if let value = try? container.decode(Int64.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Decimal128.self) {
            self.value = value
        } else if let value = try? container.decode(MinKey.self) {
            self.value = value
        } else if let value = try? container.decode(MaxKey.self) {
            self.value = value
        } else if let value = try? container.decode([AnyBSONValue].self) {
            self.value = value.map { $0.value }
        } else if let value = try? container.decode(Document.self) {
            self.value = value
        } else {
            throw MongoError.typeError(
                message: "Encountered a value that could not be decoded to any BSON type")
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func hash(into hasher: inout Hasher) {
        switch self.value {
        case let value as Int:
            value.hash(into: &hasher)
        case let value as Int32:
            value.hash(into: &hasher)
        case let value as Int64:
            value.hash(into: &hasher)
        case let value as Double:
            value.hash(into: &hasher)
        case let value as Decimal128:
            value.hash(into: &hasher)
        case let value as Bool:
            value.hash(into: &hasher)
        case let value as String:
            value.hash(into: &hasher)
        case let value as RegularExpression:
            value.hash(into: &hasher)
        case let value as Timestamp:
            value.hash(into: &hasher)
        case let value as Date:
            value.hash(into: &hasher)
        case let value as MinKey:
            value.hash(into: &hasher)
        case let value as MaxKey:
            value.hash(into: &hasher)
        case let value as ObjectId:
            value.hash(into: &hasher)
        case let value as CodeWithScope:
            value.hash(into: &hasher)
        case let value as Document:
            value.hash(into: &hasher)
        case let value as Binary:
            value.hash(into: &hasher)
        case let value as [BSONValue?]:
            value.forEach({$0.map({AnyBSONValue($0).hash(into: &hasher)})})
        default:
            preconditionFailure("invalid bson type")
        }
    }

    // Default implementation from protocol extension. Needed for Swift < 4.2
    public var hashValue: Int {
        var hasher = Hasher()
        self.hash(into: &hasher)
        return hasher.finalize()
    }

    /// This value as a BsonDocument if it is one, otherwise nil
    public lazy var asDocument = value as? Document

    /// This value as a BsonArray if it is one, otherwise nil
    public lazy var asArray = value as? [BSONValue?]

    /// This value as a BsonString if it is one, otherwise nil
    public lazy var asString = value as? String

    //// This value as a BsonNumber if it is one, otherwise nil
    public lazy var asNumber = value as? Int

    /// This value as a BsonInt32 if it is one, otherwise nil
    public lazy var asInt = value as? Int

    /// This value as a BsonInt64 if it is one, otherwise nil
    public lazy var asInt64 = value as? Int64

    /// This value as a BsonDecimal128 if it is one, otherwise nil
    public lazy var asDecimal128 = value as? Decimal128

    /// This value as a BsonDouble if it is one, otherwise nil
    public lazy var asDouble = value as? Double

    /// This value as a BsonBoolean if it is one, otherwise nil
    public lazy var asBoolean = value as? Bool

    /// This value as an BsonObjectId if it is one, otherwise nil
    public lazy var asObjectId = value as? ObjectId

    /// This value as a BsonDbPointer if it is one, otherwise nil
    internal lazy var asDBPointer = value as? DBPointer

    /// This value as a BsonTimestamp if it is one, otherwise nil
    public lazy var asTimestamp = value as? Timestamp

    /// This value as a BsonBinary if it is one, otherwise nil
    public lazy var asBinary = value as? Binary

    /// This value as a BsonDateTime if it is one, otherwise nil
    public lazy var asDateTime = value as? Date

    /// This value as a MaxKey if it is one, otherwise nil
    public lazy var asMaxKey = value as? MaxKey

    /// This value as a MinKey if it is one, otherwise nil
    public lazy var asMinKey = value as? MinKey

    /// This value as a BsonSymbol if it is one, otherwise nil
    internal lazy var asSymbol = value as? Symbol

    /// This value as a BsonRegularExpression if it is one, otherwise nil
    public lazy var asRegularExpression = value as? RegularExpression

    /// This value as a CodeWithScope if it is one, otherwise nil
    public lazy var asCodeWithScope = value as? CodeWithScope

    /// True if this is a BsonNull, false otherwise.
    public lazy var isBSONNull = value is BSONNull

    /// True if this is a BsonDocument, false otherwise.
    public lazy var isDocument = value is Document

    /// True if this is a BsonArray, false otherwise.
    public lazy var isArray = value is [BSONValue?]

    /// True if this is a BsonString, false otherwise.
    public lazy var isString = value is String

    /// True if this is a BsonNumber, false otherwise.
    public lazy var isNumber = value is Int || value is Int32 || value is Int64

    /// True if this is a BsonInt32, false otherwise.
    public lazy var isInt = value is Int

    /// True if this is a BsonInt64, false otherwise.
    public lazy var isInt64 = value is Int64

    /// True if this is a BsonDecimal128, false otherwise.
    public lazy var isDecimal128 = value is Decimal128

    /// True if this is a BsonDouble, false otherwise.
    public lazy var isDouble = value is Double

    /// True if this is a BsonBoolean, false otherwise.
    public lazy var isBoolean = value is Bool

    /// True if this is an BsonObjectId, false otherwise.
    public lazy var isObjectId = value is ObjectId

     /// True if this is a BsonDbPointer, false otherwise.
    public lazy var isDBPointer = value is DBPointer

    /// True if this is a BsonTimestamp, false otherwise.
    public lazy var isTimestamp = value is Timestamp

    /// True if this is a BsonBinary, false otherwise.
    public lazy var isBinary = value is Binary

    /// True if this is a BsonDateTime, false otherwise.
    public lazy var isDate = value is Date

    /// True if this is a BsonSymbol, false otherwise.
    public lazy var isSymbol = value is Symbol

    /// True if this is a BsonRegularExpression, false otherwise.
    public lazy var isRegularExpression = value is RegularExpression

    /// True if this is a BsonJavaScriptWithScope, false otherwise.
    public lazy var isCodeWithScope: Bool = value is CodeWithScope

    /// True if this is a MaxKey, false otherwise.
    public lazy var isMaxKey: Bool = value is MaxKey

    /// True if this is a MinKey, false otherwise.
    public lazy var isMinKey: Bool = value is MinKey
}
