import Foundation
import libbson

public enum BsonType: Int {
    case invalid = 0x00,
    double = 0x01,
    string = 0x02,
    document = 0x03,
    array = 0x04,
    binary = 0x05,
    undefined = 0x06,
    objectId = 0x07,
    boolean = 0x08,
    dateTime = 0x09,
    null = 0x0a,
    regularExpression = 0x0b,
    dbPointer = 0x0c,
    javascript = 0x0d,
    symbol = 0x0e,
    javascriptWithScope = 0x0f,
    int32 = 0x10,
    timestamp = 0x11,
    int64 = 0x12,
    decimal128 = 0x13,
    minKey = 0xff,
    maxKey = 0x7f
}

/// A protocol all types representing BsonTypes must implement
public protocol BsonValue {

    var bsonType: BsonType { get }

    /**
    * Given the bson_t backing a document, appends this BsonValue to the end.
    *
    * - Parameters:
    *   - data: An `<UnsafeMutablePointer<bson_t>`, indicating the bson_t to append to.
    *   - key: A `String`, the key with which to store the value.
    *
    * - Returns: A `Bool` indicating whether the value was successfully appended.
    */
    func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws
}

/// An extension of Array type to represent the BSON array type
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
    static func from(bson: inout bson_iter_t) -> [BsonValue] {
        var length: UInt32 = 0
        let array = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        bson_iter_array(&bson, &length, array)

        // since an array is a nested object with keys '0', '1', etc.,
        // create a new Document using the array data so we can recursively parse
        guard let arrayData = bson_new_from_data(array.pointee, Int(length)) else {
            preconditionFailure("Failed to create a bson_t from array data")
        }

        let arrayDoc = Document(fromData: arrayData)

        var i = 0
        var result = [BsonValue]()
        while let v = arrayDoc[String(i)] {
            result.append(v)
            i += 1
        }
        return result
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        // An array is just a document with keys '0', '1', etc. corresponding to indexes
        let arr = Document()
        for (i, v) in self.enumerated() { arr[String(i)] = v as? BsonValue }
        if !bson_append_array(data, key, Int32(key.count), arr.data) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// Subtypes for BSON Binary values
public enum BsonSubtype: Int {
    case binary = 0x00,
    function = 0x01,
    binaryDeprecated = 0x02,
    uuidDeprecated = 0x03,
    uuid = 0x04,
    md5 = 0x05,
    user = 0x06
}

/// A class to represent the BSON Binary type
class Binary: BsonValue, Equatable {
    public var bsonType: BsonType { return .binary }
    var data: Data
    var subtype: BsonSubtype

    init(data: Data, subtype: BsonSubtype) {
        self.data = data
        self.subtype = subtype
    }

    // Initialize a Binary instance from a base64 string
    init(base64: String, subtype: BsonSubtype) {
        guard let dataObj = Data(base64Encoded: base64) else {
            preconditionFailure("failed to create Data object from base64 string \(base64)")
        }
        self.data = dataObj
        self.subtype = subtype
    }

    // Initialize a Binary instance from a Data object
    init(data: Data, subtype: UInt32) {
        self.data = data
        self.subtype = BsonSubtype(rawValue: Int(subtype))!
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        let subtype = bson_subtype_t(UInt32(self.subtype.rawValue))
        let length = self.data.count
        let byteArray = [UInt8](self.data)
        if !bson_append_binary(data, key, Int32(key.count), subtype, byteArray, UInt32(length)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    static func from(bson: inout bson_iter_t) -> Binary {
        var subtype: bson_subtype_t = bson_subtype_t(rawValue: 0)
        var length: UInt32 = 0
        let dataPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        bson_iter_binary(&bson, &subtype, &length, dataPointer)

        guard let data = dataPointer.pointee else {
            preconditionFailure("failed to retrieve data stored for binary BSON value")
        }

        let dataObj = Data(bytes: data, count: Int(length))
        return Binary(data: dataObj, subtype: subtype.rawValue)
    }

    static func == (lhs: Binary, rhs: Binary) -> Bool {
        return lhs.data == rhs.data && lhs.subtype == rhs.subtype
    }
}

/// An extension of Bool to represent the BSON Boolean type
extension Bool: BsonValue {
    public var bsonType: BsonType { return .boolean }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_bool(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// An extension of Date to represent the BSON Datetime type
extension Date: BsonValue {
    public var bsonType: BsonType { return .dateTime }

    init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: Double(msSinceEpoch / 1000))
    }

    public var msSinceEpoch: Int64 { return Int64(self.timeIntervalSince1970 * 1000) }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        let seconds = self.timeIntervalSince1970 * 1000
        if !bson_append_date_time(data, key, Int32(key.count), Int64(seconds)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// A class to represent the BSON Decimal128 type
class Decimal128: BsonValue, Equatable {
    var data: String
    init(_ data: String) {
        self.data = data
    }
    public var bsonType: BsonType { return .decimal128 }

    static func == (lhs: Decimal128, rhs: Decimal128) -> Bool {
        return lhs.data == rhs.data
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        var value: bson_decimal128_t = bson_decimal128_t()
        precondition(bson_decimal128_from_string(self.data, &value),
            "Failed to parse Decimal128 string \(self.data)")
        if !bson_append_decimal128(data, key, Int32(key.count), &value) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

     static func from(bson: inout bson_iter_t) -> Decimal128 {
        var value: bson_decimal128_t = bson_decimal128_t()
        precondition(bson_iter_decimal128(&bson, &value), "Failed to retrieve Decimal128 value")
        var stringValue: Int8 = 0
        bson_decimal128_to_string(&value, &stringValue)
        return Decimal128(String(cString: &stringValue))
     }

}

/// An extension of Double to represent the BSON Double type
extension Double: BsonValue {
    public var bsonType: BsonType { return .double }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_double(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// An extension of Int to represent the BSON Int32 type.
/// While the bitwidth of Int is machine-dependent, we assume for simplicity
/// that it is always 32 bits. Use Int64 if 64 bits are needed.
extension Int: BsonValue {
    public var bsonType: BsonType { return .int32 }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_int32(data, key, Int32(key.count), Int32(self)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// An extension of Int32 to represent the BSON Int32 type
extension Int32: BsonValue {
    public var bsonType: BsonType { return .int32 }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_int32(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// An extension of Int64 to represent the BSON Int64 type
extension Int64: BsonValue {
    public var bsonType: BsonType { return .int64 }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_int64(data, key, Int32(key.count), self) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// A class to represent the BSON Code and CodeWithScope types
class CodeWithScope: BsonValue {
    var code = ""
    var scope: Document?

    public var bsonType: BsonType {
        if self.scope != nil { return .javascriptWithScope }
        return .javascript
    }

    // Initialize a CodeWithScope with an optional scope value
    init(code: String, scope: Document? = nil) {
        self.code = code
        self.scope = scope
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if let s = self.scope {
            if !bson_append_code_with_scope(data, key, Int32(key.count), self.code, s.data) {
                throw bsonEncodeError(value: self, forKey: key)
            }
        } else if !bson_append_code(data, key, Int32(key.count), self.code) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    static func from(bson: inout bson_iter_t) -> CodeWithScope {

        var length: UInt32 = 0

        if bson_iter_type(&bson) == BSON_TYPE_CODE {
            let code = String(cString: bson_iter_code(&bson, &length))
            return CodeWithScope(code: code)
        }

        var scopeLength: UInt32 = 0
        let scopePointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        let code = String(cString: bson_iter_codewscope(&bson, &length, &scopeLength, scopePointer))
        guard let scopeData = bson_new_from_data(scopePointer.pointee, Int(scopeLength)) else {
            preconditionFailure("Failed to create a bson_t from scope data")
        }
        let scopeDoc = Document(fromData: scopeData)
        return CodeWithScope(code: code, scope: scopeDoc)
    }
}

/// A class to represent the BSON MaxKey type
class MaxKey: BsonValue, Equatable {
    public var bsonType: BsonType { return .maxKey }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_maxkey(data, key, Int32(key.count)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    static func == (lhs: MaxKey, rhs: MaxKey) -> Bool { return true }
}

/// A class to represent the BSON MinKey type
class MinKey: BsonValue, Equatable {
    public var bsonType: BsonType { return .minKey }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_minkey(data, key, Int32(key.count)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
    static func == (lhs: MinKey, rhs: MinKey) -> Bool { return true }
}

/// A class to represent the BSON ObjectId type
class ObjectId: BsonValue, Equatable {
    public var bsonType: BsonType { return .objectId }
    var oid: bson_oid_t

    init() {
        var oid: bson_oid_t = bson_oid_t()
        // the second parameter should be a bson_context_t, but for now use nil
        bson_oid_init(&oid, nil)
        self.oid = oid
    }

    init(from: bson_oid_t) {
        self.oid = from
    }

    init(from: String) {
        var oid: bson_oid_t = bson_oid_t()
        bson_oid_init_from_string(&oid, from)
        self.oid = oid
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_oid(data, key, Int32(key.count), &self.oid) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    static func from(bson: inout bson_iter_t) -> ObjectId {
        guard let oid = bson_iter_oid(&bson) else {
            preconditionFailure("Failed to retrieve ObjectID value")
        }
        return ObjectId(from: oid.pointee)
    }

    public var asString: String {
        var data: Int8 = 0
        bson_oid_to_string(&self.oid, &data)
        return String(cString: &data)
    }

    static func == (lhs: ObjectId, rhs: ObjectId) -> Bool { return lhs.asString == rhs.asString }

}

// A mapping of regex option characters to their equivalent NSRegularExpression option.
// note that there is a BSON regexp option 'l' that NSRegularExpression
// doesn't support. The flag will be dropped if BSON containing it is parsed,
// and it will be ignored if passed into optionsFromString.
let regexOptsMap: [Character: NSRegularExpression.Options] = [
    "i": .caseInsensitive,
    "m": .anchorsMatchLines,
    "s": .dotMatchesLineSeparators,
    "u": .useUnicodeWordBoundaries,
    "x": .allowCommentsAndWhitespace
]

/// An extension of NSRegularExpression to represent the BSON RegularExpression type
extension NSRegularExpression: BsonValue {
    public var bsonType: BsonType { return .regularExpression }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_regex(data, key, Int32(key.count), self.pattern, self.stringOptions) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    static func from(bson: inout bson_iter_t) throws -> NSRegularExpression {
        let options = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
        guard let pattern = bson_iter_regex(&bson, options) else {
            preconditionFailure("Failed to retrieve regular expression pattern")
        }
        guard let stringOptions = options.pointee else {
            preconditionFailure("Failed to retrieve regular expression options")
        }

        let opts = NSRegularExpression.optionsFromString(String(cString: stringOptions))
        return try self.init(pattern: String(cString: pattern), options: opts)
    }

    // Convert a string of options flags into an equivalent NSRegularExpression.Options
    static func optionsFromString(_ stringOptions: String) -> NSRegularExpression.Options {
        var optsObj: NSRegularExpression.Options = []
        for o in stringOptions {
            if let value = regexOptsMap[o] {
                 optsObj.update(with: value)
            }
        }
        return optsObj
    }

    // Convert this instance's Options object into an alphabetically-sorted string of characters
    public var stringOptions: String {
        var optsString = ""
        for (char, o) in regexOptsMap { if options.contains(o) { optsString += String(char) } }
        return String(optsString.sorted())
    }
}

/// An extension of String to represent the BSON string type
extension String: BsonValue {
    public var bsonType: BsonType { return .string }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_utf8(data, key, Int32(key.count), self, Int32(self.count)) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }
}

/// A class to represent the BSON Timestamp type
class Timestamp: BsonValue, Equatable {
    public var bsonType: BsonType { return .timestamp }
    var timestamp: UInt32 = 0
    var increment: UInt32 = 0

    init(timestamp: UInt32, inc: UInt32) {
        self.timestamp = timestamp
        self.increment = inc
    }

    // assumes that values can successfully be converted to UInt32
    // w/o loss of precision
    init(timestamp: Int, inc: Int) {
        self.timestamp = UInt32(timestamp)
        self.increment = UInt32(inc)
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_timestamp(data, key, Int32(key.count), self.timestamp, self.increment) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    static func from(bson: inout bson_iter_t) -> Timestamp {
        var t: UInt32 = 0
        var i: UInt32 = 0
        bson_iter_timestamp(&bson, &t, &i)
        return Timestamp(timestamp: t, inc: i)
    }

    static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.increment == rhs.increment
    }

}
