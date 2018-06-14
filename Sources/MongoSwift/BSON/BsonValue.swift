import Foundation
import libbson

/// The possible types of BSON values and their corresponding integer values.
public enum BsonType: Int {
    /// An invalid type
    case invalid = 0,
    /// 64-bit binary floating point
    double,
    /// UTF-8 string
    string,
    /// BSON document
    document,
    /// Array
    array,
    /// Binary data
    binary,
    /// Undefined value - deprecated
    undefined,
    /// A MongoDB ObjectId. 
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/method/ObjectId/
    objectId,
    /// A boolean
    boolean,
    /// UTC datetime, stored as UTC milliseconds since the Unix epoch
    dateTime,
    /// Null value
    null,
    /// A regular expression
    regularExpression,
    /// A database pointer - deprecated
    dbPointer,
    /// Javascript code
    javascript,
    /// A symbol - deprecated
    symbol,
    /// JavaScript code w/ scope
    javascriptWithScope,
    /// 32-bit integer
    int32,
    /// Special internal type used by MongoDB replication and sharding
    timestamp,
    /// 64-bit integer
    int64,
    /// 128-bit decimal floating point
    decimal128,
    /// Special type which compares lower than all other possible BSON element values
    minKey,
    /// Special type which compares higher than all other possible BSON element values
    maxKey
}

internal let BsonTypeMap: [UInt32: BsonValue.Type] = [
    0x01: Double.self,
    0x02: String.self,
    0x03: Document.self,
    0x04: [BsonValue].self,
    0x05: Binary.self,
    0x07: ObjectId.self,
    0x08: Bool.self,
    0x09: Date.self,
    0x0b: RegularExpression.self,
    0x0c: DBPointer.self,
    0x0d: CodeWithScope.self,
    0x0e: Symbol.self,
    0x0f: CodeWithScope.self,
    0x10: Int.self,
    0x11: Timestamp.self,
    0x12: Int64.self,
    0x13: Decimal128.self,
    0xff: MinKey.self,
    0x7f: MaxKey.self
]

internal func nextBsonValue(iter: inout bson_iter_t) -> BsonValue? {
    let type = bson_iter_type(&iter)
    guard let typeToReturn = BsonTypeMap[type.rawValue] else { return nil }
    return typeToReturn.from(iter: &iter)
}

/// A protocol all types representing BsonTypes must implement.
public protocol BsonValue: Codable {
    /// The `BsonType` of this value.
    var bsonType: BsonType { get }

    /**
    * Given the `bson_t` backing a `Document`, appends this `BsonValue` to the end.
    *
    * - Parameters:
    *   - to: An `<UnsafeMutablePointer<bson_t>`, indicating the `bson_t` to append to.
    *   - forKey: A `String`, the key with which to store the value.
    *
    * - Returns: A `Bool` indicating whether the value was successfully appended.
    */
    func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws

    /**
    * Given a `bson_iter_t` known to have a next value, returns the next value in the iterator.
    *
    * - Parameters:
    *   - iter: A `bson_iter_t` to read the next value from
    *
    * - Returns: A `BsonValue`
    */
    static func from(iter: inout bson_iter_t) -> BsonValue
}

/// An extension of `Array` to represent the BSON array type.
extension Array: BsonValue {
    public var bsonType: BsonType { return .array }

    /**
    * Given a BSON iterator where the next stored value is known to be
    * an array, converts the data into an array. Assumes that the caller
    * has verified the next value is an array.
    *
    * - Parameters:
    *   - bson: A `bson_iter_t`
    *
    * - Side effects:
    *   - bson is moved forward to the next value in the document
    *
    * - Returns: A `[BsonValue]` corresponding to the array
    */
    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var length: UInt32 = 0
        let array = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        defer {
            array.deinitialize(count: 1)
            array.deallocate(capacity: 1)
        }
        bson_iter_array(&iter, &length, array)

        // since an array is a nested object with keys '0', '1', etc.,
        // create a new Document using the array data so we can recursively parse
        guard let arrayData = bson_new_from_data(array.pointee, Int(length)) else {
            preconditionFailure("Failed to create a bson_t from array data")
        }

        let arrayDoc = Document(fromPointer: arrayData)

        var i = 0
        var result = [BsonValue]()
        while let v = arrayDoc[String(i)] {
            result.append(v)
            i += 1
        }
        return result
    }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        // An array is just a document with keys '0', '1', etc. corresponding to indexes
        var arr = Document()
        for (i, v) in self.enumerated() { arr[String(i)] = v as? BsonValue }
        if !bson_append_array(data, key, Int32(key.count), arr.data) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// Subtypes for BSON Binary values.
public enum BsonSubtype: Int, Codable {
    /// Generic binary subtype
    case binary = 0,
    /// A function
    function,
    /// Binary (old)
    binaryDeprecated,
    /// UUID (old)
    uuidDeprecated,
    /// UUID
    uuid,
    /// MD5
    md5,
    /// User defined
    user
}

/// A struct to represent the BSON Binary type.
public struct Binary: BsonValue, Equatable, Codable {

    public var bsonType: BsonType { return .binary }

    /// The binary data.
    public let data: Data

    /// The binary subtype for this data.
    public let subtype: BsonSubtype

    /// Initializes a Binary instance of the specified subtype using provided `Data`.
    public init(data: Data, subtype: BsonSubtype) {
        self.data = data
        self.subtype = subtype
    }

    /// Initializes a Binary instance of the specified subtype from a base64 `String`. 
    public init(base64: String, subtype: BsonSubtype) {
        guard let dataObj = Data(base64Encoded: base64) else {
            preconditionFailure("failed to create Data object from base64 string \(base64)")
        }
        self.data = dataObj
        self.subtype = subtype
    }

    /// Initializes a `Binary` instance from a `Data` object and a `UInt32` subtype.
    internal init(data: Data, subtype: UInt32) {
        self.data = data
        self.subtype = BsonSubtype(rawValue: Int(subtype))!
    }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        let subtype = bson_subtype_t(UInt32(self.subtype.rawValue))
        let length = self.data.count
        let byteArray = [UInt8](self.data)
        if !bson_append_binary(data, key, Int32(key.count), subtype, byteArray, UInt32(length)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var subtype: bson_subtype_t = bson_subtype_t(rawValue: 0)
        var length: UInt32 = 0
        let dataPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        defer {
            dataPointer.deinitialize(count: 1)
            dataPointer.deallocate(capacity: 1)
        }
        bson_iter_binary(&iter, &subtype, &length, dataPointer)

        guard let data = dataPointer.pointee else {
            preconditionFailure("failed to retrieve data stored for binary BSON value")
        }

        let dataObj = Data(bytes: data, count: Int(length))
        return Binary(data: dataObj, subtype: subtype.rawValue)
    }

    public static func == (lhs: Binary, rhs: Binary) -> Bool {
        return lhs.data == rhs.data && lhs.subtype == rhs.subtype
    }
}

/// An extension of `Bool` to represent the BSON Boolean type.
extension Bool: BsonValue {
    public var bsonType: BsonType { return .boolean }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_bool(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        return bson_iter_bool(&iter)
    }
}

/// An extension of `Date` to represent the BSON Datetime type.
extension Date: BsonValue {
    public var bsonType: BsonType { return .dateTime }

    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    public init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: Double(msSinceEpoch / 1000))
    }

    /// The number of milliseconds after the Unix epoch that this `Date` occurs.
    public var msSinceEpoch: Int64 { return Int64(self.timeIntervalSince1970 * 1000) }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        let seconds = self.timeIntervalSince1970 * 1000
        if !bson_append_date_time(data, key, Int32(key.count), Int64(seconds)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        return Date(msSinceEpoch: bson_iter_date_time(&iter))
    }
}

/// An internal struct to represent the deprecated DBPointer type. While DBPointers cannot
/// be created, we may need to parse them into `Document`s, and this provides a place for that logic.
internal struct DBPointer: BsonValue {

    public var bsonType: BsonType { return .dbPointer }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        throw MongoError.bsonEncodeError(message: "DBPointers are deprecated; use a DBRef instead")
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var length: UInt32 = 0
        let collectionPP = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
        defer {
            collectionPP.deinitialize(count: 1)
            collectionPP.deallocate(capacity: 1)
        }
        let oidPP = UnsafeMutablePointer<UnsafePointer<bson_oid_t>?>.allocate(capacity: 1)
        defer {
            oidPP.deinitialize(count: 1)
            oidPP.deallocate(capacity: 1)
        }
        bson_iter_dbpointer(&iter, &length, collectionPP, oidPP)

        guard let key = bson_iter_key(&iter) else {
            preconditionFailure("Failed to retrieve key for DBPointer value")
        }
        guard let oidP = oidPP.pointee else {
            preconditionFailure(retrieveErrorMsg(type: "DBPointer ObjectId", key: String(cString: key)))
        }
        guard let collectionP = collectionPP.pointee else {
            preconditionFailure(retrieveErrorMsg(type: "DBPointer collection name", key: String(cString: key)))
        }

        let dbRef: Document = [
            "$ref": String(cString: collectionP),
            "$id": ObjectId(fromPointer: oidP)
        ]

        return dbRef
    }
}

/// A struct to represent the BSON Decimal128 type.
public struct Decimal128: BsonValue, Equatable, Codable {
    /// This number, represented as a `String`.
    public let data: String

    /// Initializes a `Decimal128` value from the provided `String`.
    public init(_ data: String) {
        self.data = data
    }

    public var bsonType: BsonType { return .decimal128 }

    public static func == (lhs: Decimal128, rhs: Decimal128) -> Bool {
        return lhs.data == rhs.data
    }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        var value: bson_decimal128_t = bson_decimal128_t()
        precondition(bson_decimal128_from_string(self.data, &value),
            "Failed to parse Decimal128 string \(self.data)")
        if !bson_append_decimal128(data, key, Int32(key.count), &value) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var value: bson_decimal128_t = bson_decimal128_t()
        precondition(bson_iter_decimal128(&iter, &value), "Failed to retrieve Decimal128 value")

        var str = Data(count: Int(BSON_DECIMAL128_STRING))
        return Decimal128(str.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) in
            bson_decimal128_to_string(&value, bytes)
            return String(cString: bytes)
        })
     }

}

/// An extension of `Double` to represent the BSON Double type.
extension Double: BsonValue {
    public var bsonType: BsonType { return .double }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_double(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        return bson_iter_double(&iter)
    }
}

/// An extension of `Int` to represent the BSON Int32 type.
/// While the bitwidth of Int is machine-dependent, we assume for simplicity
/// that it is always 32 bits. Use `Int64` if 64 bits are needed.
extension Int: BsonValue {
    public var bsonType: BsonType { return .int32 }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        guard let int32 = Int32(exactly: self) else {
            throw MongoError.bsonEncodeError(message:
                "`Int` value \(self) does not fit in an `Int32`. Use an `Int64` instead")
        }
        if !bson_append_int32(data, key, Int32(key.count), int32) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        return Int(bson_iter_int32(&iter))
    }
}

/// An extension of `Int32` to represent the BSON Int32 type.
extension Int32: BsonValue {
    public var bsonType: BsonType { return .int32 }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_int32(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        return bson_iter_int32(&iter)
    }
}

/// An extension of `Int64` to represent the BSON Int64 type.
extension Int64: BsonValue {
    public var bsonType: BsonType { return .int64 }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_int64(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        return bson_iter_int64(&iter)
    }
}

/// A struct to represent the BSON Code and CodeWithScope types.
public struct CodeWithScope: BsonValue, Equatable, Codable {
    /// A string containing Javascript code.
    public let code: String
    /// An optional scope `Document` containing a mapping of identifiers to values,
    /// representing the context in which `code` should be evaluated.
    public let scope: Document?

    public var bsonType: BsonType {
        if self.scope != nil { return .javascriptWithScope }
        return .javascript
    }

    /// Initializes a `CodeWithScope` with an optional scope value.
    public init(code: String, scope: Document? = nil) {
        self.code = code
        self.scope = scope
    }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if let s = self.scope {
            if !bson_append_code_with_scope(data, key, Int32(key.count), self.code, s.data) {
                throw bsonEncodeError(value: self, forKey: key)
            }
        } else if !bson_append_code(data, key, Int32(key.count), self.code) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {

        var length: UInt32 = 0

        if bson_iter_type(&iter) == BSON_TYPE_CODE {
            let code = String(cString: bson_iter_code(&iter, &length))
            return CodeWithScope(code: code)
        }

        var scopeLength: UInt32 = 0
        let scopePointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        defer {
            scopePointer.deinitialize(count: 1)
            scopePointer.deallocate(capacity: 1)
        }
        let code = String(cString: bson_iter_codewscope(&iter, &length, &scopeLength, scopePointer))
        guard let scopeData = bson_new_from_data(scopePointer.pointee, Int(scopeLength)) else {
            preconditionFailure("Failed to create a bson_t from scope data")
        }
        let scopeDoc = Document(fromPointer: scopeData)
        return CodeWithScope(code: code, scope: scopeDoc)
    }

    public static func == (lhs: CodeWithScope, rhs: CodeWithScope) -> Bool {
        return lhs.code == rhs.code && lhs.scope == rhs.scope
    }
}

/// A struct to represent the BSON MaxKey type.
public struct MaxKey: BsonValue, Equatable, Codable {
    private var maxKey = 1

    public var bsonType: BsonType { return .maxKey }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_maxkey(data, key, Int32(key.count)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue { return MaxKey() }

    public static func == (lhs: MaxKey, rhs: MaxKey) -> Bool { return true }
}

/// A struct to represent the BSON MinKey type.
public struct MinKey: BsonValue, Equatable, Codable {
    private var minKey = 1

    public var bsonType: BsonType { return .minKey }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_minkey(data, key, Int32(key.count)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue { return MinKey() }

    public static func == (lhs: MinKey, rhs: MinKey) -> Bool { return true }
}

/// A struct to represent the BSON ObjectId type.
public struct ObjectId: BsonValue, Equatable, CustomStringConvertible, Codable {

    public var bsonType: BsonType { return .objectId }

    /// This `ObjectId`'s data represented as a `String`.
    public let oid: String

    /// Initializes a new `ObjectId`.
    public init() {
        var oid_t = bson_oid_t()
        bson_oid_init(&oid_t, nil)
        self.init(fromPointer: &oid_t)
    }

    /// Initializes an `ObjectId` from the provided `String`.
    public init(fromString oid: String) {
        self.oid = oid
    }

    /// Initializes an `ObjectId` from an `UnsafePointer<bson_oid_t>` by copying the data
    /// from it to a `String`
    internal init(fromPointer oid_t: UnsafePointer<bson_oid_t>) {
        var str = Data(count: 25)
        self.oid = str.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) in
            bson_oid_to_string(oid_t, bytes)
            return String(cString: bytes)
        }
    }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        // create a new bson_oid_t with self.oid
        var oid = bson_oid_t()
        bson_oid_init_from_string(&oid, self.oid)
        // encode the bson_oid_t to the bson_t
        if !bson_append_oid(data, key, Int32(key.count), &oid) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        guard let oid = bson_iter_oid(&iter) else {
            preconditionFailure("Failed to retrieve ObjectID value")
        }
        return ObjectId(fromPointer: oid)
    }

    public var description: String {
        return self.oid
    }

    public static func == (lhs: ObjectId, rhs: ObjectId) -> Bool {
        return lhs.oid == rhs.oid
    }

}

// A mapping of regex option characters to their equivalent `NSRegularExpression` option.
// note that there is a BSON regexp option 'l' that `NSRegularExpression`
// doesn't support. The flag will be dropped if BSON containing it is parsed,
// and it will be ignored if passed into `optionsFromString`.
let regexOptsMap: [Character: NSRegularExpression.Options] = [
    "i": .caseInsensitive,
    "m": .anchorsMatchLines,
    "s": .dotMatchesLineSeparators,
    "u": .useUnicodeWordBoundaries,
    "x": .allowCommentsAndWhitespace
]

/// An extension of `NSRegularExpression` to support converting options to and from strings.
extension NSRegularExpression {

    /// Convert a string of options flags into an equivalent `NSRegularExpression.Options`
    static func optionsFromString(_ stringOptions: String) -> NSRegularExpression.Options {
        var optsObj: NSRegularExpression.Options = []
        for o in stringOptions {
            if let value = regexOptsMap[o] {
                 optsObj.update(with: value)
            }
        }
        return optsObj
    }

    /// Convert this instance's options object into an alphabetically-sorted string of characters
    public var stringOptions: String {
        var optsString = ""
        for (char, o) in regexOptsMap { if options.contains(o) { optsString += String(char) } }
        return String(optsString.sorted())
    }
}

/// A struct to represent a BSON regular expression.
struct RegularExpression: BsonValue, Equatable, Codable {

    public var bsonType: BsonType { return .regularExpression }

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

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_regex(data, key, Int32(key.count), self.pattern, self.options) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        let options = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
        defer {
            options.deinitialize(count: 1)
            options.deallocate(capacity: 1)
        }

        guard let pattern = bson_iter_regex(&iter, options) else {
            preconditionFailure("Failed to retrieve regular expression pattern")
        }
        let patternString = String(cString: pattern)

        guard let stringOptions = options.pointee else {
            preconditionFailure("Failed to retrieve regular expression options")
        }
        let optionsString = String(cString: stringOptions)

        return RegularExpression(pattern: patternString, options: optionsString)
    }

    /// Creates an `NSRegularExpression` with the pattern and options of this `RegularExpression`.
    /// Note: `NSRegularExpression` does not support the `l` locale dependence option, so it will
    // be omitted if set on this `RegularExpression`.
    public var nsRegularExpression: NSRegularExpression {
        let opts = NSRegularExpression.optionsFromString(self.options)
        do {
            return try NSRegularExpression(pattern: self.pattern, options: opts)
        } catch {
            preconditionFailure("Failed to initialize NSRegularExpression with " +
                "pattern '\(self.pattern)'' and options '\(self.options)'")
        }
    }

    /// Returns `true` if the two `RegularExpression`s have matching patterns and options, and `false` otherwise.
    public static func == (lhs: RegularExpression, rhs: RegularExpression) -> Bool {
        return lhs.pattern == rhs.pattern && lhs.options == rhs.options
    }
}

/// An extension of String to represent the BSON string type.
extension String: BsonValue {
    public var bsonType: BsonType { return .string }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_utf8(data, key, Int32(key.count), self, Int32(self.count)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var length: UInt32 = 0
        let value = bson_iter_utf8(&iter, &length)
        guard let strValue = value else {
            guard let key = bson_iter_key(&iter) else {
                preconditionFailure("Failed to retrieve key for UTF-8 value")
            }
            preconditionFailure(retrieveErrorMsg(type: "UTF-8", key: String(cString: key)))
        }

        return String(cString: strValue)
    }
}

/// An internal struct to represent the deprecated Symbol type. While Symbols cannot be
/// created, we may need to parse them into `String`s, and this provides a place for that logic.
internal struct Symbol: BsonValue {
    public var bsonType: BsonType { return .symbol }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        throw MongoError.bsonEncodeError(message: "Symbols are deprecated; use a string instead")
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var length: UInt32 = 0
        let value = bson_iter_symbol(&iter, &length)
        guard let strValue = value else {
            guard let key = bson_iter_key(&iter) else {
                preconditionFailure("Failed to retrieve key for Symbol value")
            }
            preconditionFailure(retrieveErrorMsg(type: "Symbol", key: String(cString: key)))
        }

        return String(cString: strValue)
    }
}

/// A struct to represent the BSON Timestamp type.
public struct Timestamp: BsonValue, Equatable, Codable {
    public var bsonType: BsonType { return .timestamp }

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

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_timestamp(data, key, Int32(key.count), self.timestamp, self.increment) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var t: UInt32 = 0
        var i: UInt32 = 0
        bson_iter_timestamp(&iter, &t, &i)
        return Timestamp(timestamp: t, inc: i)
    }

    public static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.increment == rhs.increment
    }

}

func retrieveErrorMsg(type: String, key: String) -> String {
    return "Failed to retrieve the \(type) value for key '\(key)'"
}
