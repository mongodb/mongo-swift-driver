import CLibMongoC
import Foundation
import NIO

/// This shared allocator instance should be used for all underlying `ByteBuffer` creation.
private let BSON_ALLOCATOR = ByteBufferAllocator()

/// The possible types of BSON values and their corresponding integer values.
public enum BSONType: UInt8 {
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
    /// A MongoDB  ObjectID.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/method/ObjectId/
    case objectID = 0x07
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
     * Given the `DocumentStorage` backing a `BSONDocument`, appends this `BSONValue` to the end.
     *
     * - Parameters:
     *   - storage: A `DocumentStorage` to write to.
     *   - key: A `String`, the key under which to store the value.
     *
     * - Throws:
     *   - `BSONError.InternalError` if the `DocumentStorage` would exceed the maximum size by encoding this
     *     key-value pair.
     *   - `BSONError.LogicError` if the value is an `Array` and it contains a non-`BSONValue` element.
     */
    func encode(to document: inout BSONDocument, forKey key: String) throws

    /**
     * Given a `BSONDocumentIterator` known to have a next value of this type,
     * initializes the value.
     *
     * - Throws: `BSONError.LogicError` if the current type of the `BSONDocumentIterator` does not correspond to the
     *           associated type of this `BSONValue`.
     */
    static func from(iterator iter: BSONDocumentIterator) throws -> BSON
}

extension BSONValue {
    internal var bsonType: BSONType {
        Self.bsonType
    }
}

/// An extension of `Array` to represent the BSON array type.
extension Array: BSONValue where Element == BSON {
    internal static var bsonType: BSONType { .array }

    internal var bson: BSON {
        .array(self)
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
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
                throw BSONError.InternalError(message: "Failed to create an Array from iterator")
            }

            let arrDoc = BSONDocument(stealing: arrayData)
            return arrDoc.values
        })
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        var arr = BSONDocument()
        for (i, v) in self.enumerated() {
            try arr.setValue(for: String(i), to: v)
        }

        try document.withMutableBSONPointer { docPtr in
            try arr.withBSONPointer { arrPtr in
                guard bson_append_array(docPtr, key, Int32(key.utf8.count), arrPtr) else {
                    throw bsonTooLargeError(value: self, forKey: key)
                }
            }
        }
    }

    /// Attempts to map this `[BSON]` to a `[T]`, where `T` is a `BSONValue`.
    internal func toArrayOf<T: BSONValue>(_: T.Type) -> [T]? {
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
    internal static var bsonType: BSONType { .null }

    internal var bson: BSON { .null }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        guard iter.currentType == .null else {
            throw wrongIterTypeError(iter, expected: BSONNull.self)
        }
        return .null
    }

    /// Initializes a new `BSONNull` instance.
    internal init() {}

    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONNull.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_null(docPtr, key, Int32(key.utf8.count)) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
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
public struct BSONBinary: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { .binary }

    internal var bson: BSON { .binary(self) }

    /// The binary data.
    public let data: ByteBuffer

    /// The binary subtype for this data.
    public let subtype: Subtype

    /// Subtypes for BSON Binary values.
    public struct Subtype: Equatable, Codable, Hashable, RawRepresentable {
        // swiftlint:disable force_unwrapping
        /// Generic binary subtype
        public static let generic = Subtype(rawValue: 0x00)!
        /// A function
        public static let function = Subtype(rawValue: 0x01)!
        /// Binary (old)
        public static let binaryDeprecated = Subtype(rawValue: 0x02)!
        /// UUID (old)
        public static let uuidDeprecated = Subtype(rawValue: 0x03)!
        /// UUID (RFC 4122)
        public static let uuid = Subtype(rawValue: 0x04)!
        /// MD5
        public static let md5 = Subtype(rawValue: 0x05)!
        /// Encrypted BSON value
        public static let encryptedValue = Subtype(rawValue: 0x06)!
        // swiftlint:enable force_unwrapping

        /// Subtype indicator value
        public let rawValue: UInt8

        /// Initializes a `Subtype` with a custom value.
        /// Returns nil if rawValue within reserved range [0x07, 0x80).
        public init?(rawValue: UInt8) {
            guard !(rawValue > 0x06 && rawValue < 0x80) else {
                return nil
            }
            self.rawValue = rawValue
        }

        internal init(_ value: bson_subtype_t) { self.rawValue = UInt8(value.rawValue) }

        /// Initializes a `Subtype` with a custom value. This value must be in the range 0x80-0xFF.
        /// - Throws:
        ///   - `BSONError.InvalidArgumentError` if value passed is outside of the range 0x80-0xFF
        public static func userDefined(_ value: Int) throws -> Subtype {
            guard let byteValue = UInt8(exactly: value) else {
                throw BSONError.InvalidArgumentError(message: "Cannot represent \(value) as UInt8")
            }
            guard byteValue >= 0x80 else {
                throw BSONError.InvalidArgumentError(
                    message: "userDefined value must be greater than or equal to 0x80 got \(byteValue)"
                )
            }
            guard let subtype = Subtype(rawValue: byteValue) else {
                throw BSONError.InvalidArgumentError(message: "Cannot represent \(byteValue) as Subtype")
            }
            return subtype
        }
    }

    /// Initializes a `BSONBinary` instance from a `UUID`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if a `BSONBinary` cannot be constructed from this UUID.
    public init(from uuid: UUID) throws {
        let uuidt = uuid.uuid

        let uuidData = Data([
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])

        try self.init(data: uuidData, subtype: BSONBinary.Subtype.uuid)
    }

    /// Initializes a `BSONBinary` instance from a `Data` object and a `UInt8` subtype.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if the provided data is incompatible with the specified subtype.
    public init(data: Data, subtype: Subtype) throws {
        if [Subtype.uuid, Subtype.uuidDeprecated].contains(subtype) && data.count != 16 {
            throw BSONError.InvalidArgumentError(
                message:
                "Binary data with UUID subtype must be 16 bytes, but data has \(data.count) bytes"
            )
        }
        self.subtype = subtype
        var buffer = BSON_ALLOCATOR.buffer(capacity: data.count)
        buffer.writeBytes(data)
        self.data = buffer
    }

    /// Initializes a `BSONBinary` instance from a base64 `String` and a `Subtype`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if the base64 `String` is invalid or if the provided data is
    ///     incompatible with the specified subtype.
    public init(base64: String, subtype: Subtype) throws {
        guard let dataObj = Data(base64Encoded: base64) else {
            throw BSONError.InvalidArgumentError(
                message:
                "failed to create Data object from invalid base64 string \(base64)"
            )
        }
        try self.init(data: dataObj, subtype: subtype)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONBinary.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        let subtype = bson_subtype_t(UInt32(self.subtype.rawValue))
        let length = self.data.writerIndex
        guard let byteArray = self.data.getBytes(at: 0, length: length) else {
            throw BSONError.InternalError(message: "Cannot read \(length) bytes from Binary.data")
        }
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_binary(docPtr, key, Int32(key.utf8.count), subtype, byteArray, UInt32(length)) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        guard iter.currentType == .binary else {
            throw wrongIterTypeError(iter, expected: BSONBinary.self)
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
                throw BSONError.InternalError(message: "failed to retrieve data stored for binary BSON value")
            }

            let dataObj = Data(bytes: data, count: Int(length))
            return try self.init(data: dataObj, subtype: Subtype(subtype))
        })
    }

    /// Converts this `BSONBinary` instance to a `UUID`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if a non-UUID subtype is set on this `BSONBinary`.
    public func toUUID() throws -> UUID {
        guard [Subtype.uuid, Subtype.uuidDeprecated].contains(self.subtype) else {
            throw BSONError.InvalidArgumentError(
                message: "Expected a UUID binary subtype, got subtype \(self.subtype) instead."
            )
        }

        guard let data = self.data.getBytes(at: 0, length: 16) else {
            throw BSONError.InternalError(message: "Unable to read 16 bytes from Binary.data")
        }

        let uuid: uuid_t = (
            data[0], data[1], data[2], data[3],
            data[4], data[5], data[6], data[7],
            data[8], data[9], data[10], data[11],
            data[12], data[13], data[14], data[15]
        )

        return UUID(uuid: uuid)
    }
}

/// An extension of `Bool` to represent the BSON Boolean type.
extension Bool: BSONValue {
    internal static var bsonType: BSONType { .bool }

    internal var bson: BSON { .bool(self) }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_bool(docPtr, key, Int32(key.utf8.count), self) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
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
    internal static var bsonType: BSONType { .datetime }

    internal var bson: BSON { .datetime(self) }

    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    internal init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(msSinceEpoch) / 1000.0)
    }

    /// The number of milliseconds after the Unix epoch that this `Date` occurs.
    internal var msSinceEpoch: Int64 { Int64((self.timeIntervalSince1970 * 1000.0).rounded()) }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_date_time(docPtr, key, Int32(key.utf8.count), self.msSinceEpoch) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
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
public struct BSONDBPointer: BSONValue, Codable, Equatable, Hashable {
    internal static var bsonType: BSONType { .dbPointer }

    internal var bson: BSON { .dbPointer(self) }

    /// Destination namespace of the pointer.
    public let ref: String

    /// Destination _id (assumed to be an `BSONObjectID`) of the pointed-to document.
    public let id: BSONObjectID

    internal init(ref: String, id: BSONObjectID) {
        self.ref = ref
        self.id = id
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONDBPointer.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            try withUnsafePointer(to: self.id.oid) { oidPtr in
                guard bson_append_dbpointer(docPtr, key, Int32(key.utf8.count), self.ref, oidPtr) else {
                    throw bsonTooLargeError(value: self, forKey: key)
                }
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        try iter.withBSONIterPointer { iterPtr in
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
                throw wrongIterTypeError(iter, expected: BSONDBPointer.self)
            }

            return .dbPointer(BSONDBPointer(ref: String(cString: collectionP), id: BSONObjectID(bsonOid: oidP.pointee)))
        }
    }
}

/// A struct to represent the BSON Decimal128 type.
public struct BSONDecimal128: BSONValue, Equatable, Codable, CustomStringConvertible {
    internal static var bsonType: BSONType { .decimal128 }

    internal var bson: BSON { .decimal128(self) }

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

    /**
     * Initializes a `BSONDecimal128` value from the provided `String`.
     *
     * - Parameters:
     *   - a BSONDecimal128 number as a string.
     *
     * - Throws:
     *   - A `BSONError.InvalidArgumentError` if the string does not represent a BSONDecimal128 encodable value.
     *
     * - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.rst
     */
    public init(_ data: String) throws {
        let bsonType = try BSONDecimal128.toLibBSONType(data)
        self.init(bsonDecimal: bsonType)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONDecimal128.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            try withUnsafePointer(to: self.decimal128) { ptr in
                guard bson_append_decimal128(docPtr, key, Int32(key.utf8.count), ptr) else {
                    throw bsonTooLargeError(value: self, forKey: key)
                }
            }
        }
    }

    /// Returns the provided string as a `bson_decimal128_t`, or throws an error if initialization fails due an
    /// invalid string.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if the parameter string does not correspond to a valid `BSONDecimal128`.
    internal static func toLibBSONType(_ str: String) throws -> bson_decimal128_t {
        var value = bson_decimal128_t()
        guard bson_decimal128_from_string(str, &value) else {
            throw BSONError.InvalidArgumentError(message: "Invalid Decimal128 string \(str)")
        }
        return value
    }

    public static func == (lhs: BSONDecimal128, rhs: BSONDecimal128) -> Bool {
        lhs.decimal128.low == rhs.decimal128.low && lhs.decimal128.high == rhs.decimal128.high
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        .decimal128(try iter.withBSONIterPointer { iterPtr in
            var value = bson_decimal128_t()
            guard bson_iter_decimal128(iterPtr, &value) else {
                throw wrongIterTypeError(iter, expected: BSONDecimal128.self)
            }

            return BSONDecimal128(bsonDecimal: value)
        })
    }
}

// An extension of `BSONDecimal128` to add capability to be hashed
extension BSONDecimal128: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.description)
    }
}

/// An extension of `Double` to represent the BSON Double type.
extension Double: BSONValue {
    internal static var bsonType: BSONType { .double }

    internal var bson: BSON { .double(self) }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_double(docPtr, key, Int32(key.utf8.count), self) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
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
    internal static var bsonType: BSONType { .int32 }

    internal var bson: BSON { .int32(self) }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_int32(docPtr, key, Int32(key.utf8.count), self) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
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
    internal static var bsonType: BSONType { .int64 }

    internal var bson: BSON { .int64(self) }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_int64(docPtr, key, Int32(key.utf8.count), self) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        guard iter.currentType == .int64 else {
            throw wrongIterTypeError(iter, expected: Int64.self)
        }

        return .int64(iter.withBSONIterPointer { iterPtr in
            self.init(bson_iter_int64(iterPtr))
        })
    }
}

/// A struct to represent BSON CodeWithScope.
public struct BSONCodeWithScope: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { .codeWithScope }

    internal var bson: BSON { .codeWithScope(self) }

    /// A string containing Javascript code.
    public let code: String

    /// An optional scope `BSONDocument` containing a mapping of identifiers to values,
    /// representing the context in which `code` should be evaluated.
    public let scope: BSONDocument

    /// Initializes a `BSONCodeWithScope` with an optional scope value.
    public init(code: String, scope: BSONDocument) {
        self.code = code
        self.scope = scope
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONCodeWithScope.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            try self.scope.withBSONPointer { scopePtr in
                guard bson_append_code_with_scope(docPtr, key, Int32(key.utf8.count), self.code, scopePtr) else {
                    throw bsonTooLargeError(value: self, forKey: key)
                }
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        .codeWithScope(try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .codeWithScope else {
                throw wrongIterTypeError(iter, expected: BSONCodeWithScope.self)
            }

            var scopeLength: UInt32 = 0
            let scopePointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
            defer {
                scopePointer.deinitialize(count: 1)
                scopePointer.deallocate()
            }

            let code = String(cString: bson_iter_codewscope(iterPtr, &length, &scopeLength, scopePointer))
            guard let scopeData = bson_new_from_data(scopePointer.pointee, Int(scopeLength)) else {
                throw BSONError.InternalError(message: "Failed to create a bson_t from scope data")
            }
            let scopeDoc = BSONDocument(stealing: scopeData)

            return self.init(code: code, scope: scopeDoc)
        })
    }
}

/// A struct to represent the BSON Code type.
public struct BSONCode: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { .code }

    internal var bson: BSON { .code(self) }

    /// A string containing Javascript code.
    public let code: String

    /// Initializes a `BSONCode` with an optional scope value.
    public init(code: String) {
        self.code = code
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONCode.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_code(docPtr, key, Int32(key.utf8.count), self.code) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        .code(try iter.withBSONIterPointer { iterPtr in
            guard iter.currentType == .code else {
                throw wrongIterTypeError(iter, expected: BSONCode.self)
            }
            let code = String(cString: bson_iter_code(iterPtr, nil))
            return self.init(code: code)
        })
    }
}

/// A struct to represent the BSON MaxKey type.
internal struct BSONMaxKey: BSONValue, Equatable, Codable, Hashable {
    internal var bson: BSON { .maxKey }

    internal static var bsonType: BSONType { .maxKey }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_maxkey(docPtr, key, Int32(key.utf8.count)) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    /// Initializes a new `BSONMaxKey` instance.
    internal init() {}

    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONMaxKey.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        guard iter.currentType == .maxKey else {
            throw wrongIterTypeError(iter, expected: BSONMaxKey.self)
        }
        return .maxKey
    }
}

/// A struct to represent the BSON MinKey type.
internal struct BSONMinKey: BSONValue, Equatable, Codable, Hashable {
    internal var bson: BSON { .minKey }

    internal static var bsonType: BSONType { .minKey }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_minkey(docPtr, key, Int32(key.utf8.count)) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    /// Initializes a new `BSONMinKey` instance.
    internal init() {}

    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONMinKey.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        guard iter.currentType == .minKey else {
            throw wrongIterTypeError(iter, expected: BSONMinKey.self)
        }
        return .minKey
    }
}

/// A struct to represent the BSON ObjectID type.
public struct BSONObjectID: BSONValue, Equatable, CustomStringConvertible, Codable {
    internal var bson: BSON { .objectID(self) }

    internal static var bsonType: BSONType { .objectID }

    /// This `BSONObjectID`'s data represented as a `String`.
    public var hex: String {
        var str = Data(count: 25)
        return str.withUnsafeMutableCStringPointer { strPtr in
            withUnsafePointer(to: self.oid) { oidPtr in
                bson_oid_to_string(oidPtr, strPtr)
            }
            return String(cString: strPtr)
        }
    }

    public var description: String {
        self.hex
    }

    internal let oid: bson_oid_t

    /// Initializes a new `BSONObjectID`.
    public init() {
        var oid = bson_oid_t()
        bson_oid_init(&oid, nil)
        self.oid = oid
    }

    /// Initializes an `BSONObjectID` from the provided hex `String`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if string passed is not a valid BSONObjectID
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/objectid.rst
    public init(_ hex: String) throws {
        guard bson_oid_is_valid(hex, hex.utf8.count) else {
            throw BSONError.InvalidArgumentError(message: "Cannot create ObjectId from \(hex)")
        }
        var oid_t = bson_oid_t()
        bson_oid_init_from_string(&oid_t, hex)
        self.oid = oid_t
    }

    internal init(bsonOid oid_t: bson_oid_t) {
        self.oid = oid_t
    }

    public init(from decoder: Decoder) throws {
        // assumes that the BSONObjectID is stored as a valid hex string.
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        guard let oid = try? BSONObjectID(hex) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ObjectID hex string. Got: \(hex)"
                )
            )
        }
        self = oid
    }

    public func encode(to encoder: Encoder) throws {
        // encodes the hex string for the `BSONObjectID`. this method is only ever reached by non-BSON encoders.
        // BSONEncoder bypasses the method and inserts the BSONObjectID into a document, which converts it to BSON.
        var container = encoder.singleValueContainer()
        try container.encode(self.hex)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            try withUnsafePointer(to: self.oid) { oidPtr in
                guard bson_append_oid(docPtr, key, Int32(key.utf8.count), oidPtr) else {
                    throw bsonTooLargeError(value: self, forKey: key)
                }
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        .objectID(try iter.withBSONIterPointer { iterPtr in
            guard let oid = bson_iter_oid(iterPtr) else {
                throw wrongIterTypeError(iter, expected: BSONObjectID.self)
            }
            return self.init(bsonOid: oid.pointee)
        })
    }

    public static func == (lhs: BSONObjectID, rhs: BSONObjectID) -> Bool {
        withUnsafePointer(to: lhs.oid) { lhsOidPtr in
            withUnsafePointer(to: rhs.oid) { rhsOidPtr in
                bson_oid_equal(lhsOidPtr, rhsOidPtr)
            }
        }
    }
}

// An extension of `BSONObjectID` to add the capability to be hashed
extension BSONObjectID: Hashable {
    public func hash(into hasher: inout Hasher) {
        let hashedOid = withUnsafePointer(to: self.oid) { oid in
            bson_oid_hash(oid)
        }
        hasher.combine(hashedOid)
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

/// An extension of `NSRegularExpression` to support conversion to and from `BSONRegularExpression`.
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
}

/// A struct to represent a BSON regular expression.
public struct BSONRegularExpression: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { .regex }

    internal var bson: BSON { .regex(self) }

    /// The pattern for this regular expression.
    public let pattern: String
    /// A string containing options for this regular expression.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/query/regex/#op
    public let options: String

    /// Initializes a new `BSONRegularExpression` with the provided pattern and options.
    public init(pattern: String, options: String) {
        self.pattern = pattern
        self.options = String(options.sorted())
    }

    /// Initializes a new `BSONRegularExpression` with the pattern and options of the provided `NSRegularExpression`.
    public init(from regex: NSRegularExpression) {
        self.pattern = regex.pattern
        self.options = regex.stringOptions
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONRegularExpression.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_regex(docPtr, key, Int32(key.utf8.count), self.pattern, self.options) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        .regex(try iter.withBSONIterPointer { iterPtr in
            let options = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
            defer {
                options.deinitialize(count: 1)
                options.deallocate()
            }

            guard let pattern = bson_iter_regex(iterPtr, options) else {
                throw wrongIterTypeError(iter, expected: BSONRegularExpression.self)
            }
            let patternString = String(cString: pattern)

            guard let stringOptions = options.pointee else {
                throw BSONError.InternalError(message: "Failed to retrieve regular expression options")
            }
            let optionsString = String(cString: stringOptions)

            return self.init(pattern: patternString, options: optionsString)
        })
    }

    /// Converts this `BSONRegularExpression` to an `NSRegularExpression`.
    /// Note: `NSRegularExpression` does not support the `l` locale dependence option, so it will be omitted if it was
    /// set on this instance.
    public func toNSRegularExpression() throws -> NSRegularExpression {
        let opts = NSRegularExpression.optionsFromString(self.options)
        return try NSRegularExpression(pattern: self.pattern, options: opts)
    }
}

/// An extension of String to represent the BSON string type.
extension String: BSONValue {
    internal static var bsonType: BSONType { .string }

    internal var bson: BSON { .string(self) }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_utf8(docPtr, key, Int32(key.utf8.count), self, Int32(self.utf8.count)) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    /// Initializer that preserves null bytes embedded in C character buffers
    internal init?(rawStringData: UnsafePointer<CChar>, length: Int) {
        let buffer = Data(bytes: rawStringData, count: length)
        self.init(data: buffer, encoding: .utf8)
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        .string(try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .string, let strValue = bson_iter_utf8(iterPtr, &length) else {
                throw wrongIterTypeError(iter, expected: String.self)
            }

            guard bson_utf8_validate(strValue, Int(length), true) else {
                throw BSONError.InternalError(message: "String \(strValue) not valid UTF-8")
            }

            guard let out = self.init(rawStringData: strValue, length: Int(length)) else {
                throw BSONError.InternalError(
                    message: "Underlying string data could not be parsed to a Swift String"
                )
            }

            return out
        })
    }
}

/// A struct to represent the deprecated Symbol type.
/// Symbols cannot be instantiated, but they can be read from existing documents that contain them.
public struct BSONSymbol: BSONValue, CustomStringConvertible, Codable, Equatable, Hashable {
    internal static var bsonType: BSONType { .symbol }

    internal var bson: BSON { .symbol(self) }

    public var description: String {
        self.stringValue
    }

    /// String representation of this `BSONSymbol`.
    public let stringValue: String

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONSymbol.self, decoder: decoder)
    }

    internal init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_symbol(
                docPtr,
                key,
                Int32(key.utf8.count),
                self.stringValue,
                Int32(self.stringValue.utf8.count)
            ) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        .symbol(try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            guard iter.currentType == .symbol, let cStr = bson_iter_symbol(iterPtr, &length) else {
                throw wrongIterTypeError(iter, expected: BSONSymbol.self)
            }

            guard let strValue = String(rawStringData: cStr, length: Int(length)) else {
                throw BSONError.InternalError(message: "Cannot parse String from underlying data")
            }

            return BSONSymbol(strValue)
        })
    }
}

/// A struct to represent the BSON Timestamp type.
public struct BSONTimestamp: BSONValue, Equatable, Codable, Hashable {
    internal static var bsonType: BSONType { .timestamp }

    internal var bson: BSON { .timestamp(self) }

    /// A timestamp representing seconds since the Unix epoch.
    public let timestamp: UInt32
    /// An incrementing ordinal for operations within a given second.
    public let increment: UInt32

    /// Initializes a new  `BSONTimestamp` with the provided `timestamp` and `increment` values.
    public init(timestamp: UInt32, inc: UInt32) {
        self.timestamp = timestamp
        self.increment = inc
    }

    /// Initializes a new  `BSONTimestamp` with the provided `timestamp` and `increment` values. Assumes
    /// the values can successfully be converted to `UInt32`s without loss of precision.
    public init(timestamp: Int, inc: Int) {
        self.timestamp = UInt32(timestamp)
        self.increment = UInt32(inc)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONTimestamp.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_timestamp(docPtr, key, Int32(key.utf8.count), self.timestamp, self.increment) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
        guard iter.currentType == .timestamp else {
            throw wrongIterTypeError(iter, expected: BSONTimestamp.self)
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
    internal static var bsonType: BSONType { .undefined }

    internal var bson: BSON { .undefined }

    internal init() {}

    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: BSONUndefined.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }

    internal func encode(to document: inout BSONDocument, forKey key: String) throws {
        try document.withMutableBSONPointer { docPtr in
            guard bson_append_undefined(docPtr, key, Int32(key.utf8.count)) else {
                throw bsonTooLargeError(value: self, forKey: key)
            }
        }
    }

    internal static func from(iterator iter: BSONDocumentIterator) throws -> BSON {
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

/// Error thrown when a BSONValue type introduced by the driver (e.g. BSONObjectID) is encoded not using BSONEncoder
internal func bsonEncodingUnsupportedError<T: BSONValue>(value: T, at codingPath: [CodingKey]) -> EncodingError {
    let description = "Encoding \(T.self) BSONValue type with a non-BSONEncoder is currently unsupported"

    return EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/// Error thrown when a BSONValue type introduced by the driver (e.g. BSONObjectID) is decoded not using BSONDecoder
private func bsonDecodingUnsupportedError<T: BSONValue>(type _: T.Type, at codingPath: [CodingKey]) -> DecodingError {
    let description = "Initializing a \(T.self) BSONValue type with a non-BSONDecoder is currently unsupported"

    return DecodingError.typeMismatch(
        T.self,
        DecodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/**
 * Error thrown when a `BSONValue` type introduced by the driver (e.g. BSONObjectID) is decoded directly via the
 * top-level `BSONDecoder`.
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
 *   - Decoding directly from the BSONDecoder top-level (e.g. BSONDecoder().decode(BSONObjectID.self, from: ...))
 *   - Encountering the wrong type of BSONValue (e.g. expected "_id" to be an `BSONObjectID`, got a `BSONDocument`
 *     instead)
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
    fileprivate mutating func withUnsafeMutableCStringPointer<T>(
        body: (UnsafeMutablePointer<CChar>) throws -> T
    ) rethrows -> T {
        try self.withUnsafeMutableBytes { (rawPtr: UnsafeMutableRawBufferPointer) in
            let bufferPtr = rawPtr.bindMemory(to: CChar.self)
            // baseAddress is non-nil as long as Data's count > 0.
            // swiftlint:disable:next force_unwrapping
            let bytesPtr = bufferPtr.baseAddress!
            return try body(bytesPtr)
        }
    }
}
