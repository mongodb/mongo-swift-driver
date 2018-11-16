import Foundation

/// A struct wrapping a `BSONValue` type that allows for encoding/
/// decoding `BSONValue`s of unknown type.  
public struct AnyBSONValue: Codable, Equatable {
    /// The `BSONValue` wrapped by this struct. 
    public let value: BSONValue

    /// Initializes a new `AnyBSONValue` wrapping the provided `BSONValue`.
    public init(_ value: BSONValue) {
        self.value = value
    }

    /// If the provided `BSONValue` is not `nil`, initializes a new `AnyBSONValue` 
    /// wrapping that value. Otherwise, returns `nil`. 
    public init?(ifPresent value: BSONValue?) {
        guard let v = value else { return nil }
        self.value = v
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
            let mapped = arr.map { AnyBSONValue(ifPresent: $0) }
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
            guard let value = bsonDecoder.storage.topContainer else {
                throw DecodingError.valueNotFound(
                    BSONValue.self,
                    DecodingError.Context(codingPath: bsonDecoder.codingPath,
                                          debugDescription: "Expected BSONValue but found null instead."))
            }
            self.value = value
            return
        }

        let container = try decoder.singleValueContainer()

        // since we aren't sure which BSON type this is, just try decoding
        // to each of them and go with the first one that succeeds
        if container.decodeNil() {
            self.value = NSNull()
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
        } else if let value = try? container.decode([AnyBSONValue?].self) {
            self.value = value.map { $0?.value }
        } else if let value = try? container.decode(Document.self) {
            self.value = value
        } else {
            throw MongoError.typeError(
                message: "Encountered a value that could not be decoded to any BSON type")
        }
    }
}
