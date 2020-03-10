import CLibMongoC
import Foundation

/// The possible types of BSON values and their corresponding integer values.
public enum BSONType: UInt32 {
    /// An invalid type
    case invalid = 0x00
    /// 64-bit binary floating point
    case double = 0x01
    /// UTF-8 string
    case string = 0x02
    /// BSON document
    case document = 0x03
    /// Array
    case array = 0x04
    /// Binary data
    case binary = 0x05
    /// Undefined value - deprecated
    case undefined = 0x06
    /// A MongoDB ObjectId.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/method/ObjectId/
    case objectId = 0x07
    /// A boolean
    case bool = 0x08
    /// UTC datetime, stored as UTC milliseconds since the Unix epoch
    case datetime = 0x09
    /// Null value
    case null = 0x0A
    /// A regular expression
    case regex = 0x0B
    /// A database pointer - deprecated
    case dbPointer = 0x0C
    /// Javascript code
    case code = 0x0D
    /// A symbol - deprecated
    case symbol = 0x0E
    /// JavaScript code w/ scope
    case codeWithScope = 0x0F
    /// 32-bit integer
    case int32 = 0x10
    /// Special internal type used by MongoDB replication and sharding
    case timestamp = 0x11
    /// 64-bit integer
    case int64 = 0x12
    /// 128-bit decimal floating point
    case decimal128 = 0x13
    /// Special type which compares lower than all other possible BSON element values
    case minKey = 0xFF
    /// Special type which compares higher than all other possible BSON element values
    case maxKey = 0x7F
}

/// A protocol all types representing `BSONType`s must implement.
internal protocol BSONValue: Codable {
    /// The `BSONType` of this value.
    static var bsonType: BSONType { get }

    /// A corresponding `BSON` to this `BSONValue`.
    var bson: BSON { get }

    /**
     * Given the `DocumentStorage` backing a `Document`, appends this `BSONValue` to the end.
     *
     * - Parameters:
     *   - storage: A `DocumentStorage` to write to.
     *   - key: A `String`, the key under which to store the value.
     *
     * - Throws:
     *   - `InternalError` if the `DocumentStorage` would exceed the maximum size by encoding this
     *     key-value pair.
     *   - `LogicError` if the value is an `Array` and it contains a non-`BSONValue` element.
     */
    func encode(to storage: DocumentStorage, forKey key: String) throws

    /**
     * Given a `DocumentIterator` known to have a next value of this type,
     * initializes the value.
     *
     * - Throws: `LogicError` if the current type of the `DocumentIterator` does not correspond to the
     *           associated type of this `BSONValue`.
     */
    static func from(iterator iter: DocumentIterator) throws -> BSON
}

extension BSONValue {
    internal var bsonType: BSONType {
        return type(of: self).bsonType
    }
}

/// An extension of `Array` to represent the BSON array type.
extension Array: BSONValue where Element == BSON {
    internal static var bsonType: BSONType { return .array }

    internal var bson: BSON {
        return .array(self)
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .array else {
            throw wrongIterTypeError(iter, expected: Array.self)
        }

        return .array(try iter.withBSONIterPointer { iterPtr in
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
                throw InternalError(message: "Failed to create an Array from iterator")
            }

            let arrDoc = Document(stealing: arrayData)
            return arrDoc.values
        })
    }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        var arr = Document()
        for (i, v) in self.enumerated() {
            try arr.setValue(for: String(i), to: v)
        }

        guard bson_append_array(storage._bson, key, Int32(key.utf8.count), arr._bson) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Attempts to map this `[BSON]` to a `[T]`, where `T` is a `BSONValue`.
    internal func asArrayOf<T: BSONValue>(_: T.Type) -> [T]? {
        var result: [T] = []
        for element in self {
            guard let bsonValue = element.bsonValue as? T else {
                return nil
            }
            result.append(bsonValue)
        }
        return result
    }
}

/// A struct to represent the BSON null type.
internal struct BSONNull: BSONValue, Codable, Equatable {
    internal static var bsonType: BSONType { return .null }

    internal var bson: BSON { return .null }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .null else {
            throw wrongIterTypeError(iter, expected: BSONNull.self)
        }
        return .null
    }

    /// Initializes a new `BSONNull` instance.
    public init() {}

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONNull.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_null(storage._bson, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }
}

// An extension of `BSONNull` to add capability to be hashed
extension BSONNull: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
}

/// A struct to represent the BSON Binary type.
public struct Binary: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { return .binary }

    internal var bson: BSON { return .binary(self) }

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
    ///   - `InvalidArgumentError` if a `Binary` cannot be constructed from this UUID.
    public init(from uuid: UUID) throws {
        let uuidt = uuid.uuid

        let uuidData = Data([
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])

        try self.init(data: uuidData, subtype: Binary.Subtype.uuid)
    }

    /// Initializes a `Binary` instance from a `Data` object and a `UInt8` subtype.
    /// - Throws:
    ///   - `InvalidArgumentError` if the provided data is incompatible with the specified subtype.
    public init(data: Data, subtype: UInt8) throws {
        if [Subtype.uuid.rawValue, Subtype.uuidDeprecated.rawValue].contains(subtype) && data.count != 16 {
            throw InvalidArgumentError(
                message:
                "Binary data with UUID subtype must be 16 bytes, but data has \(data.count) bytes"
            )
        }
        self.subtype = subtype
        self.data = data
    }

    /// Initializes a `Binary` instance from a `Data` object and a `Subtype`.
    /// - Throws:
    ///   - `InvalidArgumentError` if the provided data is incompatible with the specified subtype.
    public init(data: Data, subtype: Subtype) throws {
        try self.init(data: data, subtype: subtype.rawValue)
    }

    /// Initializes a `Binary` instance from a base64 `String` and a `UInt8` subtype.
    /// - Throws:
    ///   - `InvalidArgumentError` if the base64 `String` is invalid or if the provided data is
    ///     incompatible with the specified subtype.
    public init(base64: String, subtype: UInt8) throws {
        guard let dataObj = Data(base64Encoded: base64) else {
            throw InvalidArgumentError(
                message:
                "failed to create Data object from invalid base64 string \(base64)"
            )
        }
        try self.init(data: dataObj, subtype: subtype)
    }

    /// Initializes a `Binary` instance from a base64 `String` and a `Subtype`.
    /// - Throws:
    ///   - `InvalidArgumentError` if the base64 `String` is invalid or if the provided data is
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

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        let subtype = bson_subtype_t(UInt32(self.subtype))
        let length = self.data.count
        let byteArray = [UInt8](self.data)
        guard bson_append_binary(storage._bson, key, Int32(key.utf8.count), subtype, byteArray, UInt32(length)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .binary else {
            throw wrongIterTypeError(iter, expected: Binary.self)
        }

        return .binary(try iter.withBSONIterPointer { iterPtr in
            var subtype = bson_subtype_t(rawValue: 0)
            var length: UInt32 = 0
            let dataPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
            defer {
                dataPointer.deinitialize(count: 1)
                dataPointer.deallocate()
            }

            bson_iter_binary(iterPtr, &subtype, &length, dataPointer)

            guard let data = dataPointer.pointee else {
                throw InternalError(message: "failed to retrieve data stored for binary BSON value")
            }

            let dataObj = Data(bytes: data, count: Int(length))
            return try self.init(data: dataObj, subtype: UInt8(subtype.rawValue))
        })
    }
}

/// An extension of `Bool` to represent the BSON Boolean type.
extension Bool: BSONValue {
    internal static var bsonType: BSONType { return .bool }

    internal var bson: BSON { return .bool(self) }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_bool(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .bool else {
            throw wrongIterTypeError(iter, expected: Bool.self)
        }

        return .bool(iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_bool(iterPtr))
        })
    }
}

/// An extension of `Date` to represent the BSON Datetime type. Supports millisecond level precision.
extension Date: BSONValue {
    internal static var bsonType: BSONType { return .datetime }

    internal var bson: BSON { return .datetime(self) }

    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    public init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(msSinceEpoch) / 1000.0)
    }

    /// The number of milliseconds after the Unix epoch that this `Date` occurs.
    public var msSinceEpoch: Int64 { return Int64((self.timeIntervalSince1970 * 1000.0).rounded()) }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_date_time(storage._bson, key, Int32(key.utf8.count), self.msSinceEpoch) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .datetime else {
            throw wrongIterTypeError(iter, expected: Date.self)
        }

        return .datetime(iter.withBSONIterPointer { iterPtr in
            self.init(msSinceEpoch: bson_iter_date_time(iterPtr))
        })
    }
}

/// A struct to represent the deprecated DBPointer type.
/// DBPointers cannot be instantiated, but they can be read from existing documents that contain them.
public struct DBPointer: BSONValue, Codable, Equatable, Hashable {
    internal static var bsonType: BSONType { return .dbPointer }

    internal var bson: BSON { return .dbPointer(self) }

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

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        try withUnsafePointer(to: self.id.oid) { oidPtr in
            guard bson_append_dbpointer(storage._bson, key, Int32(key.utf8.count), self.ref, oidPtr) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
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

            return .dbPointer(DBPointer(ref: String(cString: collectionP), id: ObjectId(bsonOid: oidP.pointee)))
        }
    }
}

/// A struct to represent the BSON Decimal128 type.
public struct Decimal128: BSONValue, Equatable, Codable, CustomStringConvertible {
    internal static var bsonType: BSONType { return .decimal128 }

    internal var bson: BSON { return .decimal128(self) }

    public var description: String {
        var str = Data(count: Int(BSON_DECIMAL128_STRING))
        return str.withUnsafeMutableCStringPointer { strPtr in
            withUnsafePointer(to: self.decimal128) { decPtr in
                bson_decimal128_to_string(decPtr, strPtr)
            }
            return String(cString: strPtr)
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

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        try withUnsafePointer(to: self.decimal128) { ptr in
            guard bson_append_decimal128(storage._bson, key, Int32(key.utf8.count), ptr) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    /// Returns the provided string as a `bson_decimal128_t`, or throws an error if initialization fails due an
    /// invalid string.
    /// - Throws:
    ///   - `InvalidArgumentError` if the parameter string does not correspond to a valid `Decimal128`.
    internal static func toLibBSONType(_ str: String) throws -> bson_decimal128_t {
        var value = bson_decimal128_t()
        guard bson_decimal128_from_string(str, &value) else {
            throw InvalidArgumentError(message: "Invalid Decimal128 string \(str)")
        }
        return value
    }

    public static func == (lhs: Decimal128, rhs: Decimal128) -> Bool {
        return lhs.decimal128.low == rhs.decimal128.low && lhs.decimal128.high == rhs.decimal128.high
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        return .decimal128(try iter.withBSONIterPointer { iterPtr in
            var value = bson_decimal128_t()
            guard bson_iter_decimal128(iterPtr, &value) else {
                throw wrongIterTypeError(iter, expected: Decimal128.self)
            }

            return Decimal128(bsonDecimal: value)
        })
    }
}

// An extension of `Decimal128` to add capability to be hashed
extension Decimal128: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.description)
    }
}

/// An extension of `Double` to represent the BSON Double type.
extension Double: BSONValue {
    internal static var bsonType: BSONType { return .double }

    internal var bson: BSON { return .double(self) }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_double(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .double else {
            throw wrongIterTypeError(iter, expected: Double.self)
        }

        return .double(iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_double(iterPtr))
        })
    }
}

/// An extension of `Int32` to represent the BSON Int32 type.
extension Int32: BSONValue {
    internal static var bsonType: BSONType { return .int32 }

    internal var bson: BSON { return .int32(self) }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_int32(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .int32 else {
            throw wrongIterTypeError(iter, expected: Int32.self)
        }

        return .int32(iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_int32(iterPtr))
        })
    }
}

/// An extension of `Int64` to represent the BSON Int64 type.
extension Int64: BSONValue {
    internal static var bsonType: BSONType { return .int64 }

    internal var bson: BSON { return .int64(self) }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_int64(storage._bson, key, Int32(key.utf8.count), self) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .int64 else {
            throw wrongIterTypeError(iter, expected: Int64.self)
        }

        return .int64(iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_int64(iterPtr))
        })
    }
}

/// A struct to represent BSON CodeWithScope.
public struct CodeWithScope: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { return .codeWithScope }

    internal var bson: BSON { return .codeWithScope(self) }

    /// A string containing Javascript code.
    public let code: String

    /// An optional scope `Document` containing a mapping of identifiers to values,
    /// representing the context in which `code` should be evaluated.
    public let scope: Document

    /// Initializes a `CodeWithScope` with an optional scope value.
    public init(code: String, scope: Document) {
        self.code = code
        self.scope = scope
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: CodeWithScope.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_code_with_scope(storage._bson, key, Int32(key.utf8.count), self.code, self.scope._bson) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        return .codeWithScope(try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .codeWithScope else {
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
                throw InternalError(message: "Failed to create a bson_t from scope data")
            }
            let scopeDoc = Document(stealing: scopeData)

            return self.init(code: code, scope: scopeDoc)
        })
    }
}

/// A struct to represent the BSON Code type.
public struct Code: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { return .code }

    internal var bson: BSON { return .code(self) }

    /// A string containing Javascript code.
    public let code: String

    /// Initializes a `CodeWithScope` with an optional scope value.
    public init(code: String) {
        self.code = code
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: CodeWithScope.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_code(storage._bson, key, Int32(key.utf8.count), self.code) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        return .code(try iter.withBSONIterPointer { iterPtr in
            guard iter.currentType == .code else {
                throw wrongIterTypeError(iter, expected: Code.self)
            }
            let code = String(cString: bson_iter_code(iterPtr, nil))
            return self.init(code: code)
        })
    }
}

/// A struct to represent the BSON MaxKey type.
internal struct MaxKey: BSONValue, Equatable, Codable, Hashable {
    internal var bson: BSON { return .maxKey }

    internal static var bsonType: BSONType { return .maxKey }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
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

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .maxKey else {
            throw wrongIterTypeError(iter, expected: MaxKey.self)
        }
        return .maxKey
    }
}

/// A struct to represent the BSON MinKey type.
internal struct MinKey: BSONValue, Equatable, Codable, Hashable {
    internal var bson: BSON { return .minKey }

    internal static var bsonType: BSONType { return .minKey }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
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

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .minKey else {
            throw wrongIterTypeError(iter, expected: MinKey.self)
        }
        return .minKey
    }
}

/// A struct to represent the BSON ObjectId type.
public struct ObjectId: BSONValue, Equatable, CustomStringConvertible, Codable {
    internal var bson: BSON { return .objectId(self) }

    internal static var bsonType: BSONType { return .objectId }

    /// This `ObjectId`'s data represented as a `String`.
    public var hex: String {
        var str = Data(count: 25)
        return str.withUnsafeMutableCStringPointer { strPtr in
            withUnsafePointer(to: self.oid) { oidPtr in
                bson_oid_to_string(oidPtr, strPtr)
            }
            return String(cString: strPtr)
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
        // assumes that the ObjectId is stored as a valid hex string.
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        guard let oid = ObjectId(hex) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ObjectId hex string. Got: \(hex)"
                )
            )
        }
        self = oid
    }

    public func encode(to encoder: Encoder) throws {
        // encodes the hex string for the `ObjectId`. this method is only ever reached by non-BSON encoders.
        // BSONEncoder bypasses the method and inserts the ObjectId into a document, which converts it to BSON.
        var container = encoder.singleValueContainer()
        try container.encode(self.hex)
    }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        // encode the bson_oid_t to the bson_t
        try withUnsafePointer(to: self.oid) { oidPtr in
            guard bson_append_oid(storage._bson, key, Int32(key.utf8.count), oidPtr) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        return .objectId(try iter.withBSONIterPointer { iterPtr in
            guard let oid = bson_iter_oid(iterPtr) else {
                throw wrongIterTypeError(iter, expected: ObjectId.self)
            }
            return self.init(bsonOid: oid.pointee)
        })
    }

    public static func == (lhs: ObjectId, rhs: ObjectId) -> Bool {
        return withUnsafePointer(to: lhs.oid) { lhsOidPtr in
            withUnsafePointer(to: rhs.oid) { rhsOidPtr in
                bson_oid_equal(lhsOidPtr, rhsOidPtr)
            }
        }
    }
}

// An extension of `ObjectId` to add the capability to be hashed
extension ObjectId: Hashable {
    public func hash(into hasher: inout Hasher) {
        let hashedOid = withUnsafePointer(to: self.oid) { oid in
            bson_oid_hash(oid)
        }
        hasher.combine(hashedOid)
    }
}

/// Extension to allow a `UUID` to be initialized from a `Binary` `BSONValue`.
extension UUID {
    /// Initializes a `UUID` instance from a `Binary` `BSONValue`.
    /// - Throws:
    ///   - `InvalidArgumentError` if a non-UUID subtype is set on the `Binary`.
    public init(from binary: Binary) throws {
        guard [Binary.Subtype.uuid.rawValue, Binary.Subtype.uuidDeprecated.rawValue].contains(binary.subtype) else {
            throw InvalidArgumentError(
                message: "Expected a UUID binary type " +
                    "(\(Binary.Subtype.uuid)), got \(binary.subtype) instead."
            )
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
public struct RegularExpression: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { return .regex }

    internal var bson: BSON { return .regex(self) }

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

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_regex(storage._bson, key, Int32(key.utf8.count), self.pattern, self.options) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        return .regex(try iter.withBSONIterPointer { iterPtr in
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
                throw InternalError(message: "Failed to retrieve regular expression options")
            }
            let optionsString = String(cString: stringOptions)

            return self.init(pattern: patternString, options: optionsString)
        })
    }
}

/// An extension of String to represent the BSON string type.
extension String: BSONValue {
    internal static var bsonType: BSONType { return .string }

    internal var bson: BSON { return .string(self) }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_utf8(storage._bson, key, Int32(key.utf8.count), self, Int32(self.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    /// Initializer that preserves null bytes embedded in C character buffers
    internal init?(rawStringData: UnsafePointer<CChar>, length: Int) {
        let buffer = Data(bytes: rawStringData, count: length)
        self.init(data: buffer, encoding: .utf8)
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        return .string(try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .string, let strValue = bson_iter_utf8(iterPtr, &length) else {
                throw wrongIterTypeError(iter, expected: String.self)
            }

            guard bson_utf8_validate(strValue, Int(length), true) else {
                throw InternalError(message: "String \(strValue) not valid UTF-8")
            }

            guard let out = self.init(rawStringData: strValue, length: Int(length)) else {
                throw InternalError(
                    message: "Underlying string data could not be parsed to a Swift String"
                )
            }

            return out
        })
    }
}

/// A struct to represent the deprecated Symbol type.
/// Symbols cannot be instantiated, but they can be read from existing documents that contain them.
public struct Symbol: BSONValue, CustomStringConvertible, Codable, Equatable, Hashable {
    internal static var bsonType: BSONType { return .symbol }

    internal var bson: BSON { return .symbol(self) }

    public var description: String {
        return self.stringValue
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

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_symbol(
            storage._bson,
            key,
            Int32(key.utf8.count),
            self.stringValue,
            Int32(self.stringValue.utf8.count)
        ) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        return .symbol(try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .symbol, let cStr = bson_iter_symbol(iterPtr, &length) else {
                throw wrongIterTypeError(iter, expected: Symbol.self)
            }

            guard let strValue = String(rawStringData: cStr, length: Int(length)) else {
                throw InternalError(message: "Cannot parse String from underlying data")
            }

            return Symbol(strValue)
        })
    }
}

/// A struct to represent the BSON Timestamp type.
public struct Timestamp: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { return .timestamp }

    internal var bson: BSON { return .timestamp(self) }

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

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_timestamp(storage._bson, key, Int32(key.utf8.count), self.timestamp, self.increment) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .timestamp else {
            throw wrongIterTypeError(iter, expected: Timestamp.self)
        }

        return .timestamp(iter.withBSONIterPointer { iterPtr in
            var t: UInt32 = 0
            var i: UInt32 = 0

            bson_iter_timestamp(iterPtr, &t, &i)
            return self.init(timestamp: t, inc: i)
        })
    }
}

/// A struct to represent the deprecated Undefined type.
/// Undefined instances cannot be created, but they can be read from existing documents that contain them.
internal struct BSONUndefined: BSONValue, Equatable, Codable {
    internal static var bsonType: BSONType { return .undefined }

    internal var bson: BSON { return .undefined }

    internal init() {}

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONUndefined.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_undefined(storage._bson, key, Int32(key.utf8.count)) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .undefined else {
            throw wrongIterTypeError(iter, expected: BSONUndefined.self)
        }
        return .undefined
    }
}

// An extension of `BSONUndefined` to add capability to be hashed
extension BSONUndefined: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
}

/// Error thrown when a BSONValue type introduced by the driver (e.g. ObjectId) is encoded not using BSONEncoder
internal func bsonEncodingUnsupportedError<T: BSONValue>(value: T, at codingPath: [CodingKey]) -> EncodingError {
    let description = "Encoding \(T.self) BSONValue type with a non-BSONEncoder is currently unsupported"

    return EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/// Error thrown when a BSONValue type introduced by the driver (e.g. ObjectId) is decoded not using BSONDecoder
private func bsonDecodingUnsupportedError<T: BSONValue>(type _: T.Type, at codingPath: [CodingKey]) -> DecodingError {
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
private func bsonDecodingDirectlyError<T: BSONValue>(type _: T.Type, at codingPath: [CodingKey]) -> DecodingError {
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
internal func getDecodingError<T: BSONValue>(type _: T.Type, decoder: Decoder) -> DecodingError {
    if let bsonDecoder = decoder as? _BSONDecoder {
        // Cannot decode driver-introduced BSONValues directly
        if decoder.codingPath.isEmpty {
            return bsonDecodingDirectlyError(type: T.self, at: decoder.codingPath)
        }

        // Got the wrong BSONValue type
        return DecodingError._typeMismatch(
            at: decoder.codingPath,
            expectation: T.self,
            reality: bsonDecoder.storage.topContainer.bsonValue
        )
    }

    // Non-BSONDecoders are currently unsupported
    return bsonDecodingUnsupportedError(type: T.self, at: decoder.codingPath)
}

extension Data {
    /// Gets access to the start of the data buffer in the form of an UnsafeMutablePointer<CChar>. Useful for calling C
    /// API methods that expect a location for a string. **You must only call this method on Data instances with
    /// count > 0 so that the base address will exist.**
    /// Based on https://mjtsai.com/blog/2019/03/27/swift-5-released/
    fileprivate mutating func withUnsafeMutableCStringPointer<T>(body: (UnsafeMutablePointer<CChar>) throws -> T)
        rethrows -> T {
        return try self.withUnsafeMutableBytes { (rawPtr: UnsafeMutableRawBufferPointer) in
            let bufferPtr = rawPtr.bindMemory(to: CChar.self)
            // baseAddress is non-nil as long as Data's count > 0.
            // swiftlint:disable:next force_unwrapping
            let bytesPtr = bufferPtr.baseAddress!
            return try body(bytesPtr)
        }
    }
}
