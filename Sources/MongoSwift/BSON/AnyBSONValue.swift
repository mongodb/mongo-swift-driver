import Foundation

/// A struct wrapping a `BSONValue` type that allows for encoding/
/// decoding `BSONValue`s of unknown type.
public struct AnyBSONValue: Codable, Equatable, Hashable {
    // TODO: conform all `BSONValue` types to `Hashable` (SWIFT-320).
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.value.bsonType)
        // A few types need to be handled specifically because their string representations aren't sufficient or
        // performant.
        if let date = self.value as? Date {
            // `Date`'s string conversion omits milliseconds and smaller time units, and using a string formatter is
            // expensive. Instead, we just include the time interval itself.
            hasher.combine(date.timeIntervalSince1970)
        } else if let binary = self.value as? Binary {
            // `Binary`'s string representation omits the data itself, so we include its hashValue.
            hasher.combine(binary.data)
            hasher.combine(binary.subtype)
        } else if let arr = self.value as? [BSONValue] {
            // To factor in every item in the array, we include the arrays extended JSON representation.
            hasher.combine((["value": arr] as Document).extendedJSON)
        }
        hasher.combine("\(self.value)")
    }

    /// The `BSONValue` wrapped by this struct.
    public let value: BSONValue

    /// Initializes a new `AnyBSONValue` wrapping the provided `BSONValue`.
    public init(_ value: BSONValue) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        // short-circuit in the `BSONEncoder` case
        if let bsonEncoder = encoder as? _BSONEncoder {
            // Need to handle `Date`s and `UUID`s separately to respect the encoding strategy choices.
            if let date = self.value as? Date {
                try bsonEncoder.encode(date)
            } else if let uuid = self.value as? UUID {
                try bsonEncoder.encode(uuid)
            } else {
                bsonEncoder.storage.containers.append(self.value)
            }
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
        return lhs.value.bsonEquals(rhs.value)
    }

    /**
     * Initializes a new `AnyBSONValue` from a `Decoder`.
     *
     * Caveats for usage with `Decoder`s other than MongoSwift's `BSONDecoder` -
     * 1) This method does *not* support initializing an `AnyBSONValue` wrapping
     * a `Date`. This is because, in non-BSON formats, `Date`s are encoded
     * as other types such as `Double` or `String`. We have no way of knowing
     * which type is the intended one when decoding to a `Document`, as `Document`s
     * can contain any `BSONValue` type, so for simplicity we always go with a
     * `Double` or a `String` over a `Date`.
     * 2) Numeric values will be attempted to be decoded in the following
     * order of types: `Int`, `Int32`, `Int64`, `Double`. The first one
     * that can successfully represent the value with no loss of precision will
     * be used.
     *
     * - Throws:
     *   - `DecodingError` if a `BSONValue` could not be decoded from the given decoder (which is not a `BSONDecoder`).
     *   - `DecodingError` if a BSON datetime is encountered but a non-default date decoding strategy was set on the
     *     decoder (which is a `BSONDecoder`).
     */
    // swiftlint:disable:next cyclomatic_complexity
    public init(from decoder: Decoder) throws {
        // short-circuit in the `BSONDecoder` case
        if let bsonDecoder = decoder as? _BSONDecoder {
            if bsonDecoder.storage.topContainer is Date {
                guard case .bsonDateTime = bsonDecoder.options.dateDecodingStrategy else {
                    throw DecodingError.typeMismatch(
                            AnyBSONValue.self,
                            DecodingError.Context(
                                    codingPath: bsonDecoder.codingPath,
                                    debugDescription: "Got a BSON datetime but was expecting another format. To " +
                                            "decode from BSON datetimes, use the default .bsonDateTime " +
                                            "DateDecodingStrategy."
                            )
                    )
                }
            }
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
            throw DecodingError.typeMismatch(
                    AnyBSONValue.self,
                    DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Encountered a value that could not be decoded to any BSON type")
            )
        }
    }
}
