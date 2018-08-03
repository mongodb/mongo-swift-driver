import Foundation

/// A struct wrapping a `BsonValue` type that allows for encoding/
/// decoding `BsonValue`s of unknown type.  
public struct AnyBsonValue: Codable {
    /// The `BsonValue` wrapped by this struct. 
    public let value: BsonValue

    /// Initializes a new `AnyBsonValue` wrapping the provided `BsonValue`.
    public init(_ value: BsonValue) {
        self.value = value
    }

    /// If the provided `BsonValue` is not `nil`, initializes a new `AnyBsonValue` 
    /// wrapping that value. Otherwise, returns `nil`. 
    public init?(ifPresent value: BsonValue?) {
        guard let v = value else { return nil }
        self.value = v
    }

    public func encode(to encoder: Encoder) throws {
        // short-circuit in the `BsonEncoder` case
        if let bsonEncoder = encoder as? _BsonEncoder {
            bsonEncoder.storage.containers.append(self.value)
            return
        }

        // in this case, we need to wrap each value in an
        // `AnyBsonValue`, before we encode, because `[BsonValue]` 
        // is not considered `Encodable`
        if let arr = self.value as? [BsonValue?] {
            let mapped = arr.map { AnyBsonValue(ifPresent: $0) }
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

    /// Initializes a new `AnyBsonValue` from a `Decoder`. 
    ///
    /// Caveats for usage with `Decoder`s other than MongoSwift's `BsonDecoder` -
    /// 1) This method does *not* support initializing an `AnyBsonValue` wrapping
    /// a `Date`. This is because, in non-BSON formats, `Date`s are encoded
    /// as other types such as `Double` or `String`. We have no way of knowing 
    /// which type is the intended one when decoding to a `Document`, as `Document`s 
    /// can contain any `BsonValue` type, so for simplicity we always go with a 
    /// `Double` or a `String` over a `Date`.
    /// 2) Numeric values will be attempted to be decoded in the following
    /// order of types: `Int`, `Int32`, `Int64`, `Double`. The first one
    /// that can successfully represent the value with no loss of precision will 
    /// be used.
    // swiftlint:disable:next cyclomatic_complexity
    public init(from decoder: Decoder) throws {
        // short-circuit in the `BsonDecoder` case
        if let bsonDecoder = decoder as? _BsonDecoder {
            guard let value = bsonDecoder.storage.topContainer else {
                throw DecodingError.valueNotFound(
                    BsonValue.self,
                    DecodingError.Context(codingPath: bsonDecoder.codingPath,
                                          debugDescription: "Expected BsonValue but found null instead."))
            }
            self.value = value
            return
        }

        let container = try decoder.singleValueContainer()
        // since we aren't sure which BSON type this is, just try decoding
        // to each of them and go with the first one that succeeds
        if let value = try? container.decode(String.self) {
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
        } else if let value = try? container.decode([AnyBsonValue?].self) {
            self.value = value.map { $0?.value }
        } else if let value = try? container.decode(Document.self) {
            self.value = value
        } else {
            throw MongoError.typeError(
                message: "Encountered a value that could not be decoded to any BSON type")
        }
    }
}
