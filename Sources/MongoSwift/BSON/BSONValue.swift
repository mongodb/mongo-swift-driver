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
    * Given a `DocumentIterator` known to have a next value of this type,
    * initializes the value.
    *
    * - Throws: `UserError.logicError` if the current type of the `DocumentIterator` does not correspond to the
    *           associated type of this `BSONValue`.
    */
    static func from(iterator iter: DocumentIterator) throws -> Self
}

/// An extension of `Array` to represent the BSON array type.
extension Array: BSONValue {
    public var bsonType: BSONType { return .array }

    public static func from(iterator iter: DocumentIterator) throws -> Array {
        guard iter.currentType == .array else {
            throw wrongIterTypeError(iter, expected: Array.self)
        }

        var length: UInt32 = 0
        let array = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        defer {
            array.deinitialize(count: 1)
            array.deallocate()
        }
        bson_iter_array(&iter.iter, &length, array)

        // since an array is a nested object with keys '0', '1', etc.,
        // create a new Document using the array data so we can recursively parse
        guard let arrayData = bson_new_from_data(array.pointee, Int(length)) else {
            throw RuntimeError.internalError(message: "Failed to create an Array from iterator")
        }

        let arrDoc = Document(fromPointer: arrayData)

        guard let arr = arrDoc.values as? Array else {
            fatalError("Failed to cast values for document \(arrDoc) to array")
        }

       return arr
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

        guard bson_append_array(storage.pointer, key, Int32(key.utf8.count), arr.data) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: BSONNull.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: BSONNull.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_null(storage.pointer, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func == (lhs: BSONNull, rhs: BSONNull) -> Bool {
        return true
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: Binary.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: Binary.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        let subtype = bson_subtype_t(UInt32(self.subtype))
        let length = self.data.count
        let byteArray = [UInt8](self.data)
        guard bson_append_binary(storage.pointer, key, Int32(key.utf8.count), subtype, byteArray, UInt32(length)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Binary {
        var subtype = bson_subtype_t(rawValue: 0)
        var length: UInt32 = 0
        let dataPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        defer {
            dataPointer.deinitialize(count: 1)
            dataPointer.deallocate()
        }

        guard iter.currentType == .binary else {
            throw wrongIterTypeError(iter, expected: Binary.self)
        }

        bson_iter_binary(&iter.iter, &subtype, &length, dataPointer)

        guard let data = dataPointer.pointee else {
            throw RuntimeError.internalError(message: "failed to retrieve data stored for binary BSON value")
        }

        let dataObj = Data(bytes: data, count: Int(length))
        return try self.init(data: dataObj, subtype: UInt8(subtype.rawValue))
    }

    public static func == (lhs: Binary, rhs: Binary) -> Bool {
        return lhs.data == rhs.data && lhs.subtype == rhs.subtype
    }
}

/// An extension of `Bool` to represent the BSON Boolean type.
extension Bool: BSONValue {
    public var bsonType: BSONType { return .boolean }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_bool(storage.pointer, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Bool {
        guard iter.currentType == .boolean else {
            throw wrongIterTypeError(iter, expected: Bool.self)
        }

        return self.init(bson_iter_bool(&iter.iter))
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
        guard bson_append_date_time(storage.pointer, key, Int32(key.utf8.count), self.msSinceEpoch) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Date {
        guard iter.currentType == .dateTime else {
            throw wrongIterTypeError(iter, expected: Date.self)
        }

        return self.init(msSinceEpoch: bson_iter_date_time(&iter.iter))
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: DBPointer.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: DBPointer.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        var oid = try ObjectId.toLibBSONType(self.id.oid) // TODO: use the stored bson_oid_t (SWIFT-268)
        guard bson_append_dbpointer(storage.pointer, key, Int32(key.utf8.count), self.ref, &oid) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> DBPointer {
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

        bson_iter_dbpointer(&iter.iter, &length, collectionPP, oidPP)

        guard let oidP = oidPP.pointee, let collectionP = collectionPP.pointee else {
            throw wrongIterTypeError(iter, expected: DBPointer.self)
        }

        return DBPointer(ref: String(cString: collectionP), id: ObjectId(fromPointer: oidP))
    }

    public static func == (lhs: DBPointer, rhs: DBPointer) -> Bool {
        return lhs.ref == rhs.ref && lhs.id == rhs.id
    }
}

/// A struct to represent the BSON Decimal128 type.
public struct Decimal128: BSONValue, Equatable, Codable, CustomStringConvertible {
    public var bsonType: BSONType { return .decimal128 }

    public var description: String {
        // TODO: avoid this copy via withUnsafePointer once swift 4.1 support is dropped (SWIFT-284)
        var copy = self.decimal128
        var str = Data(count: Int(BSON_DECIMAL128_STRING))
        return str.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) in
            bson_decimal128_to_string(&copy, bytes)
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: Decimal128.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: Decimal128.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        // TODO: avoid this copy via withUnsafePointer once swift 4.1 support is dropped (SWIFT-284)
        var copy = self.decimal128
        guard bson_append_decimal128(storage.pointer, key, Int32(key.utf8.count), &copy) else {
            throw bsonTooLargeError(value: self, forKey: key)
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
        var value = bson_decimal128_t()
        guard bson_iter_decimal128(&iter.iter, &value) else {
            throw wrongIterTypeError(iter, expected: Decimal128.self)
        }
        return Decimal128(bsonDecimal: value)
     }
}

/// An extension of `Double` to represent the BSON Double type.
extension Double: BSONValue {
    public var bsonType: BSONType { return .double }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_double(storage.pointer, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Double {
        guard iter.currentType == .double else {
            throw wrongIterTypeError(iter, expected: Double.self)
        }

        return self.init(bson_iter_double(&iter.iter))
    }
}

/// An extension of `Int` to represent the BSON Int32 or Int64 type.
/// The `Int` will be encoded as an Int32 if possible, or an Int64 if necessary.
extension Int: BSONValue {
    public var bsonType: BSONType { return self.int32Value != nil ? .int32 : .int64 }

    internal var int32Value: Int32? { return Int32(exactly: self) }
    internal var int64Value: Int64? { return Int64(exactly: self) }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        if let int32 = self.int32Value {
            return try int32.encode(to: storage, forKey: key)
        }
        if let int64 = self.int64Value {
            return try int64.encode(to: storage, forKey: key)
        }

        throw RuntimeError.internalError(message: "`Int` value \(self) could not be encoded as `Int32` or `Int64`")
    }

    public static func from(iterator iter: DocumentIterator) throws -> Int {
        // TODO: handle this more gracefully (SWIFT-221)
        switch iter.currentType {
        case .int32, .int64:
            return self.init(Int(bson_iter_int32(&iter.iter)))
        default:
            throw wrongIterTypeError(iter, expected: Int.self)
        }
    }
}

/// An extension of `Int32` to represent the BSON Int32 type.
extension Int32: BSONValue {
    public var bsonType: BSONType { return .int32 }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_int32(storage.pointer, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Int32 {
        guard iter.currentType == .int32 else {
            throw wrongIterTypeError(iter, expected: Int32.self)
        }
        return self.init(bson_iter_int32(&iter.iter))
    }
}

/// An extension of `Int64` to represent the BSON Int64 type.
extension Int64: BSONValue {
    public var bsonType: BSONType { return .int64 }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_int64(storage.pointer, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Int64 {
        guard iter.currentType == .int64 else {
            throw wrongIterTypeError(iter, expected: Int64.self)
        }
        return self.init(bson_iter_int64(&iter.iter))
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: CodeWithScope.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: CodeWithScope.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        if let s = self.scope {
            guard bson_append_code_with_scope(storage.pointer, key, Int32(key.utf8.count), self.code, s.data) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        } else {
            guard bson_append_code(storage.pointer, key, Int32(key.utf8.count), self.code) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> CodeWithScope {
        var length: UInt32 = 0

        if iter.currentType.rawValue == BSONType.javascript.rawValue {
            let code = String(cString: bson_iter_code(&iter.iter, &length))
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

        let code = String(cString: bson_iter_codewscope(&iter.iter, &length, &scopeLength, scopePointer))
        guard let scopeData = bson_new_from_data(scopePointer.pointee, Int(scopeLength)) else {
            throw RuntimeError.internalError(message: "Failed to create a bson_t from scope data")
        }
        let scopeDoc = Document(fromPointer: scopeData)

        return self.init(code: code, scope: scopeDoc)
    }

    public static func == (lhs: CodeWithScope, rhs: CodeWithScope) -> Bool {
        return lhs.code == rhs.code && lhs.scope == rhs.scope
    }
}

/// A struct to represent the BSON MaxKey type.
public struct MaxKey: BSONValue, Equatable, Codable {
    private var maxKey = 1

    public var bsonType: BSONType { return .maxKey }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_maxkey(storage.pointer, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Initializes a new `MaxKey` instance.
    public init() {}

    public init(from decoder: Decoder) throws {
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: MaxKey.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: MaxKey.self, at: decoder.codingPath)
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

    public static func == (lhs: MaxKey, rhs: MaxKey) -> Bool { return true }
}

/// A struct to represent the BSON MinKey type.
public struct MinKey: BSONValue, Equatable, Codable {
    private var minKey = 1

    public var bsonType: BSONType { return .minKey }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_minkey(storage.pointer, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Initializes a new `MinKey` instance.
    public init() {}

    public init(from decoder: Decoder) throws {
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: MinKey.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: MinKey.self, at: decoder.codingPath)
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

    public static func == (lhs: MinKey, rhs: MinKey) -> Bool { return true }
}

/// A struct to represent the BSON ObjectId type.
public struct ObjectId: BSONValue, Equatable, CustomStringConvertible, Codable {
    public var bsonType: BSONType { return .objectId }

    /// This `ObjectId`'s data represented as a `String`.
    public let oid: String

    /// The timestamp used to create this `ObjectId`
    public let timestamp: UInt32

    /// Initializes a new `ObjectId`.
    public init() {
        var oid_t = bson_oid_t()
        bson_oid_init(&oid_t, nil)
        self.init(fromPointer: &oid_t)
    }

    /// Initializes an `ObjectId` from the provided `String`. Assumes that the given string is a valid ObjectId.
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/objectid.rst
    public init(fromString oid: String) {
        self.oid = oid
        var oid_t = bson_oid_t()
        bson_oid_init_from_string(&oid_t, oid)
        self.timestamp = UInt32(bson_oid_get_time_t(&oid_t))
    }

    /// Initializes an `ObjectId` from the provided `String`. Returns `nil` if the string is not a valid
    /// ObjectId.
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/objectid.rst
    public init?(ifValid oid: String) {
        if !bson_oid_is_valid(oid, oid.utf8.count) {
            return nil
        } else {
            self.init(fromString: oid)
        }
    }

    public init(from decoder: Decoder) throws {
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: ObjectId.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: ObjectId.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    /// Initializes an `ObjectId` from an `UnsafePointer<bson_oid_t>` by copying the data
    /// from it to a `String`
    internal init(fromPointer oid_t: UnsafePointer<bson_oid_t>) {
        var str = Data(count: 25)
        self.oid = str.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) in
            bson_oid_to_string(oid_t, bytes)
            return String(cString: bytes)
        }
        self.timestamp = UInt32(bson_oid_get_time_t(oid_t))
    }

    /// Returns the provided string as a `bson_oid_t`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if the parameter string does not correspond to a valid `ObjectId`.
    internal static func toLibBSONType(_ str: String) throws -> bson_oid_t {
        var value = bson_oid_t()
        if !bson_oid_is_valid(str, str.utf8.count) {
            throw UserError.invalidArgumentError(message: "ObjectId string is invalid")
        }
        bson_oid_init_from_string(&value, str)
        return value
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        // create a new bson_oid_t with self.oid
        var oid = try ObjectId.toLibBSONType(self.oid)
        // encode the bson_oid_t to the bson_t
        guard bson_append_oid(storage.pointer, key, Int32(key.utf8.count), &oid) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> ObjectId {
        guard let oid = bson_iter_oid(&iter.iter) else {
            throw wrongIterTypeError(iter, expected: ObjectId.self)
        }
        return self.init(fromPointer: oid)
    }

    public var description: String {
        return self.oid
    }

    public static func == (lhs: ObjectId, rhs: ObjectId) -> Bool {
        return lhs.oid == rhs.oid
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: RegularExpression.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: RegularExpression.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_regex(storage.pointer, key, Int32(key.utf8.count), self.pattern, self.options) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> RegularExpression {
        let options = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
        defer {
            options.deinitialize(count: 1)
            options.deallocate()
        }

        guard let pattern = bson_iter_regex(&iter.iter, options) else {
            throw wrongIterTypeError(iter, expected: RegularExpression.self)
        }
        let patternString = String(cString: pattern)

        guard let stringOptions = options.pointee else {
            throw RuntimeError.internalError(message: "Failed to retrieve regular expression options")
        }
        let optionsString = String(cString: stringOptions)

        return self.init(pattern: patternString, options: optionsString)
    }

    /// Returns `true` if the two `RegularExpression`s have matching patterns and options, and `false` otherwise.
    public static func == (lhs: RegularExpression, rhs: RegularExpression) -> Bool {
        return lhs.pattern == rhs.pattern && lhs.options == rhs.options
    }
}

/// An extension of String to represent the BSON string type.
extension String: BSONValue {
    public var bsonType: BSONType { return .string }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_utf8(storage.pointer, key, Int32(key.utf8.count), self, Int32(self.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Initializer that preserves null bytes embedded in C strings
    internal init?(cStringWithEmbeddedNulls: UnsafePointer<CChar>, length: Int) {
        let buffer = Data(bytes: cStringWithEmbeddedNulls, count: length)
        self.init(data: buffer, encoding: .utf8)
    }

    public static func from(iterator iter: DocumentIterator) throws -> String {
        var length: UInt32 = 0
        guard iter.currentType == .string, let strValue = bson_iter_utf8(&iter.iter, &length) else {
           throw wrongIterTypeError(iter, expected: String.self)
        }

        guard bson_utf8_validate(strValue, Int(length), true) else {
            throw RuntimeError.internalError(message: "String \(strValue) not valid UTF-8")
        }

        guard let out = self.init(cStringWithEmbeddedNulls: strValue, length: Int(length)) else {
            throw RuntimeError.internalError(message: "Underlying string data could not be parsed to a Swift String")
        }
        return out
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: Symbol.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: Symbol.self, at: decoder.codingPath)
    }

    internal init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_symbol(
                storage.pointer,
                key,
                Int32(key.utf8.count),
                self.stringValue,
                Int32(self.stringValue.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Symbol {
        var length: UInt32 = 0
        guard iter.currentType == .symbol, let cStr = bson_iter_symbol(&iter.iter, &length) else {
            throw wrongIterTypeError(iter, expected: Symbol.self)
        }

        guard let strValue = String(cStringWithEmbeddedNulls: cStr, length: Int(length)) else {
            throw RuntimeError.internalError(message: "Cannot parse String from underlying data")
        }

        return Symbol(strValue)
    }

    public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
        return lhs.stringValue == rhs.stringValue
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
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: Timestamp.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: Timestamp.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_timestamp(storage.pointer, key, Int32(key.utf8.count), self.timestamp, self.increment) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> Timestamp {
        guard iter.currentType == .timestamp else {
            throw wrongIterTypeError(iter, expected: Timestamp.self)
        }
        var t: UInt32 = 0
        var i: UInt32 = 0

        bson_iter_timestamp(&iter.iter, &t, &i)

        return self.init(timestamp: t, inc: i)
    }

    public static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.increment == rhs.increment
    }
}

/// A struct to represent the deprecated Undefined type.
/// Undefined instances cannot be created, but they can be read from existing documents that contain them.
public struct BSONUndefined: BSONValue, Equatable, Codable {
    public var bsonType: BSONType { return .undefined }

    internal init() {}

    public init(from decoder: Decoder) throws {
        if decoder is _BSONDecoder {
            throw bsonDecodingDirectlyError(type: BSONUndefined.self, at: decoder.codingPath)
        }
        throw bsonDecodingUnsupportedError(type: BSONUndefined.self, at: decoder.codingPath)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_undefined(storage.pointer, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    public static func from(iterator iter: DocumentIterator) throws -> BSONUndefined {
        guard iter.currentType == .undefined else {
            throw wrongIterTypeError(iter, expected: BSONUndefined.self)
        }
        return BSONUndefined()
    }

    public static func == (lhs: BSONUndefined, rhs: BSONUndefined) -> Bool {
        return true
    }
}

// See https://github.com/realm/SwiftLint/issues/461
// swiftlint:disable cyclomatic_complexity
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
public func bsonEquals(_ lhs: BSONValue, _ rhs: BSONValue) -> Bool {
    switch (lhs, rhs) {
    case let (l as Int, r as Int): return l == r
    case let (l as Int32, r as Int32): return l == r
    case let (l as Int64, r as Int64): return l == r
    case let (l as Double, r as Double): return l == r
    case let (l as Decimal128, r as Decimal128): return l == r
    case let (l as Bool, r as Bool): return l == r
    case let (l as String, r as String): return l == r
    case let (l as RegularExpression, r as RegularExpression): return l == r
    case let (l as Timestamp, r as Timestamp): return l == r
    case let (l as Date, r as Date): return l == r
    case (_ as MinKey, _ as MinKey): return true
    case (_ as MaxKey, _ as MaxKey): return true
    case let (l as ObjectId, r as ObjectId): return l == r
    case let (l as CodeWithScope, r as CodeWithScope): return l == r
    case let (l as Binary, r as Binary): return l == r
    case (_ as BSONNull, _ as BSONNull): return true
    case let (l as Document, r as Document): return l == r
    case let (l as [BSONValue], r as [BSONValue]): // TODO: SWIFT-242
        return l.count == r.count && zip(l, r).reduce(true, { prev, next in prev && bsonEquals(next.0, next.1) })
    case (_ as [Any], _ as [Any]): return false
    case let (l as Symbol, r as Symbol): return l == r
    case let (l as DBPointer, r as DBPointer): return l == r
    case (_ as BSONUndefined, _ as BSONUndefined): return true
    default: return false
    }
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
 * Error thrown when a `BSONValue` type introduced by the driver (e.g. ObjectId) is decoded via the decoder
 * initializer when using `BSONDecoder`. These introduced types are BSON primitives that do not exist in Swift.
 * Since they're BSON primitives, they should be read straight from the document via the underlying `bson_t`,
 * and `BSONDecoder` should never be calling into init(from:Decoder) to initialize them.
 *
 * Example error causes:
 * - Decoding directly from Document: decoder.decode(ObjectId.self, from: doc)
 * - Attempting to decode by field names: decoder.decode(CodeWithScope.self, from: "{\"code": \"code\"}")
 */
private func bsonDecodingDirectlyError<T: BSONValue>(type: T.Type, at codingPath: [CodingKey]) -> DecodingError {
    let description = "Cannot initialize a BSONValue type \(T.self) directly from BSONDecoder. It must be a member of" +
            " a struct or a class."

    return DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}
