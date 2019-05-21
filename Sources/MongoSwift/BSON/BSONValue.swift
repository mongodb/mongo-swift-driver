import bson
import Foundation

/// The possible types of BSON values and their corresponding integer values.
public enum BSONType: UInt32 {
    /// An invalid type
    case invalid = 0x00,
    /// 64-bit binary floating point
    double = 0x01,
    /// UTF-8 string
    string = 0x02,
    /// BSON document
    document = 0x03,
    /// Array
    array = 0x04,
    /// Binary data
    binary = 0x05,
    /// Undefined value - deprecated
    undefined = 0x06,
    /// A MongoDB ObjectId.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/method/ObjectId/
    objectId = 0x07,
    /// A boolean
    boolean = 0x08,
    /// UTC datetime, stored as UTC milliseconds since the Unix epoch
    dateTime = 0x09,
    /// Null value
    null = 0x0a,
    /// A regular expression
    regularExpression = 0x0b,
    /// A database pointer - deprecated
    dbPointer = 0x0c,
    /// Javascript code
    javascript = 0x0d,
    /// A symbol - deprecated
    symbol = 0x0e,
    /// JavaScript code w/ scope
    javascriptWithScope = 0x0f,
    /// 32-bit integer
    int32 = 0x10,
    /// Special internal type used by MongoDB replication and sharding
    timestamp = 0x11,
    /// 64-bit integer
    int64 = 0x12,
    /// 128-bit decimal floating point
    decimal128 = 0x13,
    /// Special type which compares lower than all other possible BSON element values
    minKey = 0xff,
    /// Special type which compares higher than all other possible BSON element values
    maxKey = 0x7f
}

/// A protocol all types representing `BSONType`s must implement.
public protocol BSONValue {
    /// The `BSONType` of this value.
    var bsonType: BSONType { get }

    /**
     * Given the `DocumentStorage` backing a `Document`, appends this `BSONValue` to the end.
     *
     * - Parameters:
     *   - storage: A `DocumentStorage` to write to.
     *   - key: A `String`, the key under which to store the value.
     *
     * - Throws:
     *   - `RuntimeError.internalError` if the `DocumentStorage` would exceed the maximum size by encoding this
     *     key-value pair.
     *   - `UserError.logicError` if the value is an `Array` and it contains a non-`BSONValue` element.
     */
    func encode(to storage: DocumentStorage, forKey key: String) throws

    /**
     *  Function to test equality with another `BSONValue`. This function tests for exact BSON equality.
     *  This means that differing types with equivalent value are not equivalent.
     *
     *  e.g.
     *      4.0 (Double) != 4 (Int)
     *
     * - Parameters:
     *   - other: The right-hand-side `BSONValue` to compare.
     *
     * - Returns: `true` if `self` is equal to `rhs`, `false` otherwise.
     */
    func bsonEquals(_ other: BSONValue?) -> Bool

    /**
     * Given a `DocumentIterator` known to have a next value of this type,
     * initializes the value.
     *
     * - Throws: `UserError.logicError` if the current type of the `DocumentIterator` does not correspond to the
     *           associated type of this `BSONValue`.
     */
    static func from(iterator iter: DocumentIterator) throws -> Self
}

extension BSONValue where Self: Equatable {
    /// Default implementation of `bsonEquals` for `BSONValue`s that conform to `Equatable`.
    public func bsonEquals(_ other: BSONValue?) -> Bool {
        guard let otherAsSelf = other as? Self else {
            return false
        }
        return self == otherAsSelf
    }
}

/// A protocol that numeric `BSONValue`s should conform to. It provides functionality for converting to BSON's native
/// number types.
public protocol BSONNumber: BSONValue {
    /// Create an `Int` from this `BSONNumber`.
    /// This will return nil if the conversion cannot result in an exact representation.
    var intValue: Int? { get }

    /// Create an `Int32` from this `BSONNumber`.
    /// This will return nil if the conversion cannot result in an exact representation.
    var int32Value: Int32? { get }

    /// Create an `Int64` from this `BSONNumber`.
    /// This will return nil if the conversion cannot result in an exact representation.
    var int64Value: Int64? { get }

    /// Create a `Double` from this `BSONNumber`.
    /// This will return nil if the conversion cannot result in an exact representation.
    var doubleValue: Double? { get }

    /// Create a `Decimal128` from this `BSONNumber`.
    /// This will return nil if the conversion cannot result in an exact representation.
    var decimal128Value: Decimal128? { get }
}

/// Default conformance to `BSONNumber` for `BinaryInteger`s.
extension BSONNumber where Self: BinaryInteger {
    /// Create an `Int` from this `BinaryInteger`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var intValue: Int? { return Int(exactly: self) }

    /// Create an `Int32` from this `BinaryInteger`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var int32Value: Int32? { return Int32(exactly: self) }

    /// Create an `Int64` from this `BinaryInteger`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var int64Value: Int64? { return Int64(exactly: self) }

    /// Create a `Double` from this `BinaryInteger`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var doubleValue: Double? { return Double(exactly: self) }
}

/// Default conformance to `BSONNumber` for `BinaryFloatingPoint`s.
extension BSONNumber where Self: BinaryFloatingPoint {
    /// Create an `Int` from this `BinaryFloatingPoint`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var intValue: Int? { return Int(exactly: self) }

    /// Create an `Int32` from this `BinaryFloatingPoint`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var int32Value: Int32? { return Int32(exactly: self) }

    /// Create an `Int64` from this `BinaryFloatingPoint`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var int64Value: Int64? { return Int64(exactly: self) }

    /// Create a `Double` from this `BinaryFloatingPoint`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var doubleValue: Double? { return Double(self) }
}

/// Default implementation of `Decimal128` conversions for all `Numeric`s.
extension BSONNumber where Self: Numeric {
    /// Create a `Decimal128` from this `Numeric`.
    /// This will return nil if the conversion cannot result in an exact representation.
    public var decimal128Value: Decimal128? { return Decimal128(String(describing: self)) }
}

/// An extension of `Array` to represent the BSON array type.
extension Array: BSONValue {
    public var bsonType: BSONType { return .array }

    public static func from(iterator iter: DocumentIterator) throws -> Array {
        guard iter.currentType == .array else {
            throw wrongIterTypeError(iter, expected: Array.self)
        }

        return try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            let array = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
            defer {
                array.deinitialize(count: 1)
                array.deallocate()
            }
            bson_iter_array(iterPtr, &length, array)

            // since an array is a nested object with keys '0', '1', etc.,
            // create a new Document using the array data so we can recursively parse
            guard let arrayData = bson_new_from_data(array.pointee, Int(length)) else {
                throw RuntimeError.internalError(message: "Failed to create an Array from iterator")
            }

            let arrDoc = Document(stealing: arrayData)

            guard let arr = arrDoc.values as? Array else {
                fatalError("Failed to cast values for document \(arrDoc) to array")
            }

            return arr
        }
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        var arr = Document()
        for (i, v) in self.enumerated() {
            guard let val = v as? BSONValue else {
                throw UserError.logicError(
                    message: "Cannot encode a non-BSONValue array element: \(String(describing: v)) "
                        + "with type: \(type(of: v)) "
                        + "at index: \(i)"
                )
            }
            try arr.setValue(for: String(i), to: val)
        }

        guard bson_append_array(storage._bson, key, Int32(key.utf8.count), arr._bson) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public func bsonEquals(_ other: BSONValue?) -> Bool {
        guard let otherArr = other as? [BSONValue], let selfArr = self as? [BSONValue] else {
            return false
        }
        return self.count == otherArr.count && zip(selfArr, otherArr).allSatisfy { lhs, rhs in lhs.bsonEquals(rhs) }
    }
}

/// A struct to represent the BSON null type.
public struct BSONNull: BSONValue, Codable, Equatable {
    public var bsonType: BSONType { return .null }

    public static func from(iterator iter: DocumentIterator) throws -> BSONNull {
        guard iter.currentType == .null else {
            throw wrongIterTypeError(iter, expected: BSONNull.self)
        }
        return BSONNull()
    }

    /// Initializes a new `BSONNull` instance.
    public init() { }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONNull.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_null(storage._bson, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }
}

/// A struct to represent the BSON Binary type.
public struct Binary: BSONValue, Equatable, Codable {
    public var bsonType: BSONType { return .binary }

    /// The binary data.
    public let data: Data

    /// The binary subtype for this data.
    public let subtype: UInt8

    /// Subtypes for BSON Binary values.
    public enum Subtype: UInt8 {
        /// Generic binary subtype
        case generic,
        /// A function
        function,
        /// Binary (old)
        binaryDeprecated,
        /// UUID (old)
        uuidDeprecated,
        /// UUID (RFC 4122)
        uuid,
        /// MD5
        md5,
        /// User defined
        userDefined = 0x80
    }

    /// Initializes a `Binary` instance from a `UUID`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if a `Binary` cannot be constructed from this UUID.
    public init(from uuid: UUID) throws {
        let uuidt = uuid.uuid

        let uuidData = Data(bytes: [
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])

        try self.init(data: uuidData, subtype: Binary.Subtype.uuid)
    }

    /// Initializes a `Binary` instance from a `Data` object and a `UInt8` subtype.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if the provided data is incompatible with the specified subtype.
    public init(data: Data, subtype: UInt8) throws {
        if [Subtype.uuid.rawValue, Subtype.uuidDeprecated.rawValue].contains(subtype) && data.count != 16 {
            throw UserError.invalidArgumentError(message:
                "Binary data with UUID subtype must be 16 bytes, but data has \(data.count) bytes")
        }
        self.subtype = subtype
        self.data = data
    }

    /// Initializes a `Binary` instance from a `Data` object and a `Subtype`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if the provided data is incompatible with the specified subtype.
    public init(data: Data, subtype: Subtype) throws {
        try self.init(data: data, subtype: subtype.rawValue)
    }

    /// Initializes a `Binary` instance from a base64 `String` and a `UInt8` subtype.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if the base64 `String` is invalid or if the provided data is
    ///     incompatible with the specified subtype.
    public init(base64: String, subtype: UInt8) throws {
        guard let dataObj = Data(base64Encoded: base64) else {
            throw UserError.invalidArgumentError(message:
                "failed to create Data object from invalid base64 string \(base64)")
        }
        try self.init(data: dataObj, subtype: subtype)
    }

    /// Initializes a `Binary` instance from a base64 `String` and a `Subtype`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if the base64 `String` is invalid or if the provided data is
    ///     incompatible with the specified subtype.
    public init(base64: String, subtype: Subtype) throws {
        try self.init(base64: base64, subtype: subtype.rawValue)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Binary.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        let subtype = bson_subtype_t(UInt32(self.subtype))
        let length = self.data.count
        let byteArray = [UInt8](self.data)
        guard bson_append_binary(storage._bson, key, Int32(key.utf8.count), subtype, byteArray, UInt32(length)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Binary {
        guard iter.currentType == .binary else {
            throw wrongIterTypeError(iter, expected: Binary.self)
        }

        return try iter.withBSONIterPointer { iterPtr in
            var subtype = bson_subtype_t(rawValue: 0)
            var length: UInt32 = 0
            let dataPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
            defer {
                dataPointer.deinitialize(count: 1)
                dataPointer.deallocate()
            }

            bson_iter_binary(iterPtr, &subtype, &length, dataPointer)

            guard let data = dataPointer.pointee else {
                throw RuntimeError.internalError(message: "failed to retrieve data stored for binary BSON value")
            }

            let dataObj = Data(bytes: data, count: Int(length))
            return try self.init(data: dataObj, subtype: UInt8(subtype.rawValue))
        }
    }
}

/// An extension of `Bool` to represent the BSON Boolean type.
extension Bool: BSONValue {
    public var bsonType: BSONType { return .boolean }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_bool(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Bool {
        guard iter.currentType == .boolean else {
            throw wrongIterTypeError(iter, expected: Bool.self)
        }

        return iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_bool(iterPtr))
        }
    }
}

/// An extension of `Date` to represent the BSON Datetime type. Supports millisecond level precision.
extension Date: BSONValue {
    public var bsonType: BSONType { return .dateTime }

    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    public init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(msSinceEpoch) / 1000.0)
    }

    /// The number of milliseconds after the Unix epoch that this `Date` occurs.
    public var msSinceEpoch: Int64 { return Int64((self.timeIntervalSince1970 * 1000.0).rounded()) }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_date_time(storage._bson, key, Int32(key.utf8.count), self.msSinceEpoch) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Date {
        guard iter.currentType == .dateTime else {
            throw wrongIterTypeError(iter, expected: Date.self)
        }

        return iter.withBSONIterPointer { iterPtr in
            self.init(msSinceEpoch: bson_iter_date_time(iterPtr))
        }
    }
}

/// A struct to represent the deprecated DBPointer type.
/// DBPointers cannot be instantiated, but they can be read from existing documents that contain them.
public struct DBPointer: BSONValue, Codable, Equatable {
    public var bsonType: BSONType { return .dbPointer }

    /// Destination namespace of the pointer.
    public let ref: String

    /// Destination _id (assumed to be an `ObjectId`) of the pointed-to document.
    public let id: ObjectId

    internal init(ref: String, id: ObjectId) {
        self.ref = ref
        self.id = id
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: DBPointer.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        try withUnsafePointer(to: id.oid) { oidPtr in
            guard bson_append_dbpointer(storage._bson, key, Int32(key.utf8.count), self.ref, oidPtr) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> DBPointer {
        return try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            let collectionPP = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
            defer {
                collectionPP.deinitialize(count: 1)
                collectionPP.deallocate()
            }

            let oidPP = UnsafeMutablePointer<UnsafePointer<bson_oid_t>?>.allocate(capacity: 1)
            defer {
                oidPP.deinitialize(count: 1)
                oidPP.deallocate()
            }

            bson_iter_dbpointer(iterPtr, &length, collectionPP, oidPP)

            guard let oidP = oidPP.pointee, let collectionP = collectionPP.pointee else {
                throw wrongIterTypeError(iter, expected: DBPointer.self)
            }

            return DBPointer(ref: String(cString: collectionP), id: ObjectId(bsonOid: oidP.pointee))
        }
    }
}

/// A struct to represent the BSON Decimal128 type.
public struct Decimal128: BSONNumber, Equatable, Codable, CustomStringConvertible {
    public var bsonType: BSONType { return .decimal128 }

    public var description: String {
        var str = Data(count: Int(BSON_DECIMAL128_STRING))
        return str.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) in
            withUnsafePointer(to: self.decimal128) { ptr in
                bson_decimal128_to_string(ptr, bytes)
            }
            return String(cString: bytes)
        }
    }

    internal var decimal128: bson_decimal128_t

    internal init(bsonDecimal: bson_decimal128_t) {
        self.decimal128 = bsonDecimal
    }

    /// Initializes a `Decimal128` value from the provided `String`. Returns `nil` if the input is not a valid
    /// Decimal128 string.
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.rst
    public init?(_ data: String) {
        do {
            let bsonType = try Decimal128.toLibBSONType(data)
            self.init(bsonDecimal: bsonType)
        } catch {
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Decimal128.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        try withUnsafePointer(to: self.decimal128) { ptr in
            guard bson_append_decimal128(storage._bson, key, Int32(key.utf8.count), ptr) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    /// Returns the provided string as a `bson_decimal128_t`, or throws an error if initialization fails due an
    /// invalid string.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if the parameter string does not correspond to a valid `Decimal128`.
    internal static func toLibBSONType(_ str: String) throws -> bson_decimal128_t {
        var value = bson_decimal128_t()
        guard bson_decimal128_from_string(str, &value) else {
            throw UserError.invalidArgumentError(message: "Invalid Decimal128 string \(str)")
        }
        return value
    }

    public static func == (lhs: Decimal128, rhs: Decimal128) -> Bool {
        return lhs.decimal128.low == rhs.decimal128.low && lhs.decimal128.high == rhs.decimal128.high
    }

    public static func from(iterator iter: DocumentIterator) throws -> Decimal128 {
        return try iter.withBSONIterPointer { iterPtr in
            var value = bson_decimal128_t()
            guard bson_iter_decimal128(iterPtr, &value) else {
                throw wrongIterTypeError(iter, expected: Decimal128.self)
            }

            return Decimal128(bsonDecimal: value)
        }
     }
}

/// Extension of `Decimal128` to add `BSONNumber` conformance.
/// TODO: implement the missing converters (SWIFT-367)
extension Decimal128 {
    /// Create an `Int` from this `Decimal128`.
    /// Note: this function is not implemented yet and will always return nil.
    public var intValue: Int? { return nil }

    /// Create an `Int32` from this `Decimal128`.
    /// Note: this function is not implemented yet and will always return nil.
    public var int32Value: Int32? { return nil }

    /// Create an `Int64` from this `Decimal128`.
    /// Note: this function is not implemented yet and will always return nil.
    public var int64Value: Int64? { return nil }

    /// Create a `Double` from this `Decimal128`.
    /// Note: this function is not implemented yet and will always return nil.
    public var doubleValue: Double? { return nil }

    /// Returns this `Decimal128`.
    /// This is implemented as part of `BSONNumber` conformance.
    public var decimal128Value: Decimal128? { return self }
}

/// An extension of `Double` to represent the BSON Double type.
extension Double: BSONNumber {
    public var bsonType: BSONType { return .double }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_double(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Double {
        guard iter.currentType == .double else {
            throw wrongIterTypeError(iter, expected: Double.self)
        }

        return iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_double(iterPtr))
        }
    }
}

/// An extension of `Int` to represent the BSON Int32 or Int64 type.
/// On 64-bit systems, `Int` corresponds to a BSON Int64. On 32-bit systems, it corresponds to a BSON Int32.
extension Int: BSONNumber {
    /// `Int` corresponds to a BSON int32 or int64 depending upon whether the compilation system is 32 or 64 bit.
    /// Use MemoryLayout instead of Int.bitWidth to avoid a compiler warning.
    /// See: https://forums.swift.org/t/how-can-i-condition-on-the-size-of-int/9080/4
    internal static var bsonType: BSONType {
        return MemoryLayout<Int>.size == 4 ? .int32 : .int64
    }

    public var bsonType: BSONType { return Int.bsonType }

    // Return this `Int` as an `Int32` on 32-bit systems or an `Int64` on 64-bit systems
    internal var typedValue: BSONNumber {
        if self.bsonType == .int64 {
            return Int64(self)
        }
        return Int32(self)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        try self.typedValue.encode(to: storage, forKey: key)
    }

    public func bsonEquals(_ other: BSONValue?) -> Bool {
        guard let other = other, other.bsonType == self.bsonType else {
            return false
        }

        if let otherInt = other as? Int {
            return self == otherInt
        }

        switch (self.typedValue, other) {
        case let (self32 as Int32, other32 as Int32):
            return self32 == other32
        case let (self64 as Int64, other64 as Int64):
            return self64 == other64
        default:
            return false
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Int {
        var val: Int?
        if Int.bsonType == .int64 {
            val = Int(exactly: try Int64.from(iterator: iter))
        } else {
            val = Int(exactly: try Int32.from(iterator: iter))
        }

        guard let out = val else {
            // This should not occur
            throw RuntimeError.internalError(message: "Couldn't read `Int` from Document")
        }
        return out
    }
}

/// An extension of `Int32` to represent the BSON Int32 type.
extension Int32: BSONNumber {
    public var bsonType: BSONType { return .int32 }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_int32(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Int32 {
        guard iter.currentType == .int32 else {
            throw wrongIterTypeError(iter, expected: Int32.self)
        }

        return iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_int32(iterPtr))
        }
    }

    public func bsonEquals(_ other: BSONValue?) -> Bool {
        if let other32 = other as? Int32 {
            return self == other32
        } else if let otherInt = other as? Int {
            return self == otherInt.typedValue as? Int32
        }
        return false
    }
}

/// An extension of `Int64` to represent the BSON Int64 type.
extension Int64: BSONNumber {
    public var bsonType: BSONType { return .int64 }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_int64(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Int64 {
        guard iter.currentType == .int64 else {
            throw wrongIterTypeError(iter, expected: Int64.self)
        }

        return iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_int64(iterPtr))
        }
    }

    public func bsonEquals(_ other: BSONValue?) -> Bool {
        if let other64 = other as? Int64 {
            return self == other64
        } else if let otherInt = other as? Int {
            return self == otherInt.typedValue as? Int64
        }
        return false
    }
}

/// A struct to represent the BSON Code and CodeWithScope types.
public struct CodeWithScope: BSONValue, Equatable, Codable {
    /// A string containing Javascript code.
    public let code: String
    /// An optional scope `Document` containing a mapping of identifiers to values,
    /// representing the context in which `code` should be evaluated.
    public let scope: Document?

    public var bsonType: BSONType {
        return self.scope == nil ? .javascript : .javascriptWithScope
    }

    /// Initializes a `CodeWithScope` with an optional scope value.
    public init(code: String, scope: Document? = nil) {
        self.code = code
        self.scope = scope
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: CodeWithScope.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        if let s = self.scope {
            guard bson_append_code_with_scope(storage._bson, key, Int32(key.utf8.count), self.code, s._bson) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        } else {
            guard bson_append_code(storage._bson, key, Int32(key.utf8.count), self.code) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> CodeWithScope {
        return try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            if iter.currentType.rawValue == BSONType.javascript.rawValue {
                let code = String(cString: bson_iter_code(iterPtr, &length))
                return self.init(code: code)
            }

            guard iter.currentType == .javascriptWithScope else {
                throw wrongIterTypeError(iter, expected: CodeWithScope.self)
            }

            var scopeLength: UInt32 = 0
            let scopePointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
            defer {
                scopePointer.deinitialize(count: 1)
                scopePointer.deallocate()
            }

            let code = String(cString: bson_iter_codewscope(iterPtr, &length, &scopeLength, scopePointer))
            guard let scopeData = bson_new_from_data(scopePointer.pointee, Int(scopeLength)) else {
                throw RuntimeError.internalError(message: "Failed to create a bson_t from scope data")
            }
            let scopeDoc = Document(stealing: scopeData)

            return self.init(code: code, scope: scopeDoc)
        }
    }
}

/// A struct to represent the BSON MaxKey type.
public struct MaxKey: BSONValue, Equatable, Codable {
    private var maxKey = 1

    public var bsonType: BSONType { return .maxKey }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_maxkey(storage._bson, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Initializes a new `MaxKey` instance.
    public init() {}

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: MaxKey.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public static func from(iterator iter: DocumentIterator) throws -> MaxKey {
        guard iter.currentType == .maxKey else {
            throw wrongIterTypeError(iter, expected: MaxKey.self)
        }
        return MaxKey()
    }
}

/// A struct to represent the BSON MinKey type.
public struct MinKey: BSONValue, Equatable, Codable {
    private var minKey = 1

    public var bsonType: BSONType { return .minKey }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_minkey(storage._bson, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Initializes a new `MinKey` instance.
    public init() {}

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: MinKey.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public static func from(iterator iter: DocumentIterator) throws -> MinKey {
        guard iter.currentType == .minKey else {
            throw wrongIterTypeError(iter, expected: MinKey.self)
        }
        return MinKey()
    }
}

/// A struct to represent the BSON ObjectId type.
public struct ObjectId: BSONValue, Equatable, CustomStringConvertible, Codable {
    public var bsonType: BSONType { return .objectId }

    /// This `ObjectId`'s data represented as a `String`.
    public var hex: String {
        var str = Data(count: 25)
        return str.withUnsafeMutableBytes { (rawBuffer: UnsafeMutablePointer<Int8>) in
            withUnsafePointer(to: self.oid) { oidPtr in
                bson_oid_to_string(oidPtr, rawBuffer)
            }
            return String(cString: rawBuffer)
        }
    }

    /// The timestamp used to create this `ObjectId`
    public var timestamp: UInt32 {
        return withUnsafePointer(to: self.oid) { oidPtr in UInt32(bson_oid_get_time_t(oidPtr)) }
    }

    public var description: String {
        return self.hex
    }

    internal let oid: bson_oid_t

    /// Initializes a new `ObjectId`.
    public init() {
        var oid = bson_oid_t()
        bson_oid_init(&oid, nil)
        self.oid = oid
    }

    /// Initializes an `ObjectId` from the provided hex `String`. Returns `nil` if the string is not a valid ObjectId.
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/objectid.rst
    public init?(_ hex: String) {
        guard bson_oid_is_valid(hex, hex.utf8.count) else {
            return nil
        }
        var oid_t = bson_oid_t()
        bson_oid_init_from_string(&oid_t, hex)
        self.oid = oid_t
    }

    internal init(bsonOid oid_t: bson_oid_t) {
        self.oid = oid_t
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: ObjectId.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        // encode the bson_oid_t to the bson_t
        try withUnsafePointer(to: self.oid) { oidPtr in
            guard bson_append_oid(storage._bson, key, Int32(key.utf8.count), oidPtr) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> ObjectId {
        return try iter.withBSONIterPointer { iterPtr in
            guard let oid = bson_iter_oid(iterPtr) else {
                throw wrongIterTypeError(iter, expected: ObjectId.self)
            }
            return self.init(bsonOid: oid.pointee)
        }
    }

    public static func == (lhs: ObjectId, rhs: ObjectId) -> Bool {
        return withUnsafePointer(to: lhs.oid) { lhsOidPtr in
            withUnsafePointer(to: rhs.oid) { rhsOidPtr in
                bson_oid_equal(lhsOidPtr, rhsOidPtr)
            }
        }
    }
}

/// Extension to allow a `UUID` to be initialized from a `Binary` `BSONValue`.
extension UUID {
    /// Initializes a `UUID` instance from a `Binary` `BSONValue`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if a non-UUID subtype is set on the `Binary`.
    public init(from binary: Binary) throws {
        guard [Binary.Subtype.uuid.rawValue, Binary.Subtype.uuidDeprecated.rawValue].contains(binary.subtype) else {
            throw UserError.invalidArgumentError(message: "Expected a UUID binary type " +
                    "(\(Binary.Subtype.uuid)), got \(binary.subtype) instead.")
        }

        let data = binary.data
        let uuid: uuid_t = (
                data[0], data[1], data[2], data[3],
                data[4], data[5], data[6], data[7],
                data[8], data[9], data[10], data[11],
                data[12], data[13], data[14], data[15]
        )

        self.init(uuid: uuid)
    }
}

// A mapping of regex option characters to their equivalent `NSRegularExpression` option.
// note that there is a BSON regexp option 'l' that `NSRegularExpression`
// doesn't support. The flag will be dropped if BSON containing it is parsed,
// and it will be ignored if passed into `optionsFromString`.
private let regexOptsMap: [Character: NSRegularExpression.Options] = [
    "i": .caseInsensitive,
    "m": .anchorsMatchLines,
    "s": .dotMatchesLineSeparators,
    "u": .useUnicodeWordBoundaries,
    "x": .allowCommentsAndWhitespace
]

/// An extension of `NSRegularExpression` to allow it to be initialized from a `RegularExpression` `BSONValue`.
extension NSRegularExpression {
    /// Convert a string of options flags into an equivalent `NSRegularExpression.Options`
    internal static func optionsFromString(_ stringOptions: String) -> NSRegularExpression.Options {
        var optsObj: NSRegularExpression.Options = []
        for o in stringOptions {
            if let value = regexOptsMap[o] {
                 optsObj.update(with: value)
            }
        }
        return optsObj
    }

    /// Convert this instance's options object into an alphabetically-sorted string of characters
    internal var stringOptions: String {
        var optsString = ""
        for (char, o) in regexOptsMap { if options.contains(o) { optsString += String(char) } }
        return String(optsString.sorted())
    }

    /// Initializes a new `NSRegularExpression` with the pattern and options of the provided `RegularExpression`.
    /// Note: `NSRegularExpression` does not support the `l` locale dependence option, so it will
    /// be omitted if set on the provided `RegularExpression`.
    public convenience init(from regex: RegularExpression) throws {
        let opts = NSRegularExpression.optionsFromString(regex.options)
        try self.init(pattern: regex.pattern, options: opts)
    }
}

/// A struct to represent a BSON regular expression.
public struct RegularExpression: BSONValue, Equatable, Codable {
    public var bsonType: BSONType { return .regularExpression }

    /// The pattern for this regular expression.
    public let pattern: String
    /// A string containing options for this regular expression.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/query/regex/#op
    public let options: String

    /// Initializes a new `RegularExpression` with the provided pattern and options.
    public init(pattern: String, options: String) {
        self.pattern = pattern
        self.options = String(options.sorted())
    }

    /// Initializes a new `RegularExpression` with the pattern and options of the provided `NSRegularExpression`.
    public init(from regex: NSRegularExpression) {
        self.pattern = regex.pattern
        self.options = regex.stringOptions
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: RegularExpression.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_regex(storage._bson, key, Int32(key.utf8.count), self.pattern, self.options) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> RegularExpression {
        return try iter.withBSONIterPointer { iterPtr in
            let options = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
            defer {
                options.deinitialize(count: 1)
                options.deallocate()
            }

            guard let pattern = bson_iter_regex(iterPtr, options) else {
                throw wrongIterTypeError(iter, expected: RegularExpression.self)
            }
            let patternString = String(cString: pattern)

            guard let stringOptions = options.pointee else {
                throw RuntimeError.internalError(message: "Failed to retrieve regular expression options")
            }
            let optionsString = String(cString: stringOptions)

            return self.init(pattern: patternString, options: optionsString)
        }
    }
}

/// An extension of String to represent the BSON string type.
extension String: BSONValue {
    public var bsonType: BSONType { return .string }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_utf8(storage._bson, key, Int32(key.utf8.count), self, Int32(self.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Initializer that preserves null bytes embedded in C character buffers
    internal init?(rawStringData: UnsafePointer<CChar>, length: Int) {
        let buffer = Data(bytes: rawStringData, count: length)
        self.init(data: buffer, encoding: .utf8)
    }

    public static func from(iterator iter: DocumentIterator) throws -> String {
        return try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .string, let strValue = bson_iter_utf8(iterPtr, &length) else {
                throw wrongIterTypeError(iter, expected: String.self)
            }

            guard bson_utf8_validate(strValue, Int(length), true) else {
                throw RuntimeError.internalError(message: "String \(strValue) not valid UTF-8")
            }

            guard let out = self.init(rawStringData: strValue, length: Int(length)) else {
                throw RuntimeError.internalError(
                    message: "Underlying string data could not be parsed to a Swift String")
            }

            return out
        }
    }
}

/// A struct to represent the deprecated Symbol type.
/// Symbols cannot be instantiated, but they can be read from existing documents that contain them.
public struct Symbol: BSONValue, CustomStringConvertible, Codable, Equatable {
    public var bsonType: BSONType { return .symbol }

    public var description: String {
        return stringValue
    }

    /// String representation of this `Symbol`.
    public let stringValue: String

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Symbol.self, decoder: decoder)
    }

    internal init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_symbol(
                storage._bson,
                key,
                Int32(key.utf8.count),
                self.stringValue,
                Int32(self.stringValue.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Symbol {
        return try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .symbol, let cStr = bson_iter_symbol(iterPtr, &length) else {
                throw wrongIterTypeError(iter, expected: Symbol.self)
            }

            guard let strValue = String(rawStringData: cStr, length: Int(length)) else {
                throw RuntimeError.internalError(message: "Cannot parse String from underlying data")
            }

            return Symbol(strValue)
        }
    }
}

/// A struct to represent the BSON Timestamp type.
public struct Timestamp: BSONValue, Equatable, Codable {
    public var bsonType: BSONType { return .timestamp }

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

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Timestamp.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_timestamp(storage._bson, key, Int32(key.utf8.count), self.timestamp, self.increment) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Timestamp {
        guard iter.currentType == .timestamp else {
            throw wrongIterTypeError(iter, expected: Timestamp.self)
        }

        return iter.withBSONIterPointer { iterPtr in
            var t: UInt32 = 0
            var i: UInt32 = 0

            bson_iter_timestamp(iterPtr, &t, &i)
            return self.init(timestamp: t, inc: i)
        }
    }
}

/// A struct to represent the deprecated Undefined type.
/// Undefined instances cannot be created, but they can be read from existing documents that contain them.
public struct BSONUndefined: BSONValue, Equatable, Codable {
    public var bsonType: BSONType { return .undefined }

    internal init() {}

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONUndefined.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_undefined(storage._bson, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> BSONUndefined {
        guard iter.currentType == .undefined else {
            throw wrongIterTypeError(iter, expected: BSONUndefined.self)
        }
        return BSONUndefined()
    }
}

/**
 *  A helper function to test equality between two `BSONValue`s. This function tests for exact BSON equality.
 *  This means that differing types with equivalent value are not equivalent.
 *
 *  e.g.
 *      4.0 (Double) != 4 (Int)
 *
 *  NOTE: This function will always return `false` if it is used with two arrays that are not of the type `[BSONValue]`,
 *  because only arrays composed of solely `BSONValue`s are valid BSON arrays.
 *
 *  * - Parameters:
 *   - lhs: The left-hand-side `BSONValue` to compare.
 *   - rhs: The right-hand-side `BSONValue` to compare.
 *
 * - Returns: `true` if `lhs` is equal to `rhs`, `false` otherwise.
 */
@available(*, deprecated, message: "Use lhs.bsonEquals(rhs) instead")
public func bsonEquals(_ lhs: BSONValue, _ rhs: BSONValue) -> Bool {
    return lhs.bsonEquals(rhs)
}

/**
 *  A helper function to test equality between two BSONValue?s. See bsonEquals for BSONValues (non-optional) for more
 *  information.
 *
 *  * - Parameters:
 *   - lhs: The left-hand-side BSONValue? to compare.
 *   - rhs: The right-hand-side BSONValue? to compare.
 *
 * - Returns: True if lhs is equal to rhs, false otherwise.
 */
@available(*, deprecated, message: "use lhs?.bsonEquals(rhs) instead")
public func bsonEquals(_ lhs: BSONValue?, _ rhs: BSONValue?) -> Bool {
    guard let left = lhs, let right = rhs else {
        return lhs == nil && rhs == nil
    }

    return bsonEquals(left, right)
}

/// Error thrown when a BSONValue type introduced by the driver (e.g. ObjectId) is encoded not using BSONEncoder
private func bsonEncodingUnsupportedError<T: BSONValue>(value: T, at codingPath: [CodingKey]) -> EncodingError {
    let description = "Encoding \(T.self) BSONValue type with a non-BSONEncoder is currently unsupported"

    return EncodingError.invalidValue(
            value,
            EncodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/// Error thrown when a BSONValue type introduced by the driver (e.g. ObjectId) is decoded not using BSONDecoder
private func bsonDecodingUnsupportedError<T: BSONValue>(type: T.Type, at codingPath: [CodingKey]) -> DecodingError {
    let description = "Initializing a \(T.self) BSONValue type with a non-BSONDecoder is currently unsupported"

    return DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/**
 * Error thrown when a `BSONValue` type introduced by the driver (e.g. ObjectId) is decoded directly via the top-level
 * `BSONDecoder`.
 */
private func bsonDecodingDirectlyError<T: BSONValue>(type: T.Type, at codingPath: [CodingKey]) -> DecodingError {
    let description = "Cannot initialize BSONValue type \(T.self) directly from BSONDecoder. It must be decoded as " +
            "a member of a struct or a class."

    return DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/**
 * This function determines which error to throw when a driver-introduced BSON type is decoded via its init(decoder).
 * The types that use this function are all BSON primitives, so they should be decoded directly in `_BSONDecoder`. If
 * execution reaches their decoding initializer, it means something went wrong. This function determines an appropriate
 * error to throw for each possible case.
 *
 * Some example cases:
 *   - Decoding directly from the BSONDecoder top-level (e.g. BSONDecoder().decode(ObjectId.self, from: ...))
 *   - Encountering the wrong type of BSONValue (e.g. expected "_id" to be an `ObjectId`, got a `Document` instead)
 *   - Attempting to decode a driver-introduced BSONValue with a non-BSONDecoder
 */
internal func getDecodingError<T: BSONValue>(type: T.Type, decoder: Decoder) -> DecodingError {
    if let bsonDecoder = decoder as? _BSONDecoder {
        // Cannot decode driver-introduced BSONValues directly
        if decoder.codingPath.isEmpty {
            return bsonDecodingDirectlyError(type: T.self, at: decoder.codingPath)
        }

        // Got the wrong BSONValue type
        return DecodingError._typeMismatch(
                at: decoder.codingPath,
                expectation: T.self,
                reality: bsonDecoder.storage.topContainer
        )
    }

    // Non-BSONDecoders are currently unsupported
    return bsonDecodingUnsupportedError(type: T.self, at: decoder.codingPath)
}
