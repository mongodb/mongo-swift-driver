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

public protocol BsonValue {
    var bsonType: BsonType { get }
    func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool
}

extension Array: BsonValue {
    public var bsonType: BsonType { return .array }

    static func fromBSON(_ iter: inout bson_iter_t) -> [BsonValue] {
        let arrayLen = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let array = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        bson_iter_array(&iter, arrayLen, array)

        // since an array is a nested object with keys '0', '1', etc., 
        // create a new Document using the array data so we can recursively parse
        let arrayData = UnsafeMutablePointer<bson_t>.allocate(capacity: 1)
        precondition(bson_init_static(arrayData, array.pointee, Int(arrayLen.pointee)),
            "Failed to create a bson_t from array data")

        let arrayDoc = Document(fromData: arrayData)

        var i = 0
        var result = [BsonValue]()
        while let v = arrayDoc[String(i)] {
            result.append(v)
            i += 1
        }
        return result
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        // An array is just a document with keys '0', '1', etc. corresponding to indexes
        let arr = Document()
        for (i, v) in self.enumerated() { arr[String(i)] = v as? BsonValue }
        return bson_append_array(data, key, Int32(key.count), arr.data)
    }
}

public enum BsonSubtype: Int {
    case binary = 0x00,
    function = 0x01,
    binaryDeprecated = 0x02,
    uuidDeprecated = 0x03,
    uuid = 0x04,
    md5 = 0x05,
    user = 0x06
}

class Binary: BsonValue, Equatable {
    public var bsonType: BsonType { return .binary }
    var data: Data
    var subtype: BsonSubtype

    init(data: Data, subtype: BsonSubtype) {
        self.data = data
        self.subtype = subtype
    }

    init(base64: String, subtype: BsonSubtype) {
        guard let dataObj = Data(base64Encoded: base64) else {
            preconditionFailure("failed to create Data object from base64 string \(base64)")
        }
        self.data = dataObj
        self.subtype = subtype
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        let subtype = bson_subtype_t(UInt32(self.subtype.rawValue))
        let length = self.data.count
        let byteArray = [UInt8](self.data)
        return bson_append_binary(data, key, Int32(key.count), subtype, byteArray, UInt32(length))
    }

    static func fromBSON(_ iter: inout bson_iter_t) -> Binary {
        let subtypePointer = UnsafeMutablePointer<bson_subtype_t>.allocate(capacity: 1)
        let lengthPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let dataPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        bson_iter_binary(&iter, subtypePointer, lengthPointer, dataPointer)

        guard let data = dataPointer.pointee else {
            preconditionFailure("failed to retrieve data stored for binary BSON value")
        }

        let dataObj = Data(bytes: data, count: Int(lengthPointer.pointee))

        guard let subtype = BsonSubtype(rawValue: Int(subtypePointer.pointee.rawValue)) else {
            preconditionFailure("failed to retrieve binary subtype for BSON value")
        }

        return Binary(data: dataObj, subtype: subtype)
    }

    static func == (lhs: Binary, rhs: Binary) -> Bool {
        return lhs.data == rhs.data && lhs.subtype == rhs.subtype
    }
}

extension Bool: BsonValue {
    public var bsonType: BsonType { return .boolean }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_bool(data, key, Int32(key.count), self)
    }
}

extension Date: BsonValue {
    public var bsonType: BsonType { return .dateTime }

    init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: Double(msSinceEpoch / 1000))
    }

    public var msSinceEpoch: Int64 { return Int64(self.timeIntervalSince1970 * 1000) }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        let seconds = self.timeIntervalSince1970 * 1000
        return bson_append_date_time(data, key, Int32(key.count), Int64(seconds))
    }
}

class Decimal128: BsonValue, Equatable {
    var data: String
    init(_ data: String) {
        self.data = data
    }
    public var bsonType: BsonType { return .decimal128 }

    static func == (lhs: Decimal128, rhs: Decimal128) -> Bool {
        return lhs.data == rhs.data
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        let value = UnsafeMutablePointer<bson_decimal128_t>.allocate(capacity: 1)
        precondition(bson_decimal128_from_string(self.data, value),
            "Failed to parse Decimal128 string \(self.data)")
        return bson_append_decimal128(data, key, Int32(key.count), value)
    }

     static func fromBSON(_ iter: inout bson_iter_t) -> Decimal128 {
        let value = UnsafeMutablePointer<bson_decimal128_t>.allocate(capacity: 1)
        precondition(bson_iter_decimal128(&iter, value), "Failed to retrieve Decimal128 value")
        let stringValue = UnsafeMutablePointer<Int8>.allocate(capacity: Int(BSON_DECIMAL128_STRING))
        bson_decimal128_to_string(value, stringValue)
        return Decimal128(String(cString: stringValue))
     }

}

extension Double: BsonValue {
    public var bsonType: BsonType { return .double }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_double(data, key, Int32(key.count), self)
    }
}

extension Int: BsonValue {
    public var bsonType: BsonType { return .int32 }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_int32(data, key, Int32(key.count), Int32(self))
    }
}

extension Int32: BsonValue {
    public var bsonType: BsonType { return .int32 }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_int32(data, key, Int32(key.count), self)
    }
}

extension Int64: BsonValue {
    public var bsonType: BsonType { return .int64 }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_int64(data, key, Int32(key.count), self)
    }
}

// for this to be equatable, documents have to be as well
class JavascriptCode: BsonValue {
    var code = ""
    var scope: Document?

    public var bsonType: BsonType {
        if self.scope != nil { return .javascriptWithScope }
        return .javascript
    }

    init(code: String, scope: Document? = nil) {
        self.code = code
        self.scope = scope
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        if let s = self.scope {
            return bson_append_code_with_scope(data, key, Int32(key.count), self.code, s.data)
        }
        return bson_append_code(data, key, Int32(key.count), self.code)
    }

    static func fromBSON(_ iter: inout bson_iter_t) -> JavascriptCode {

        let length = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)

        if bson_iter_type(&iter) == BSON_TYPE_CODE {
            let code = String(cString: bson_iter_code(&iter, length))
            return JavascriptCode(code: code)
        }

        let scopeLength = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let scopePointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        let scopeData = UnsafeMutablePointer<bson_t>.allocate(capacity: 1)
        let code = String(cString: bson_iter_codewscope(&iter, length, scopeLength, scopePointer))

        precondition(bson_init_static(scopeData, scopePointer.pointee, Int(scopeLength.pointee)),
                            "Failed to create a bson_t from scope data")

        let scopeDoc = Document(fromData: scopeData)
        return JavascriptCode(code: code, scope: scopeDoc)
    }
}

class MaxKey: BsonValue, Equatable {
    public var bsonType: BsonType { return .maxKey }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_maxkey(data, key, Int32(key.count))
    }

    static func == (lhs: MaxKey, rhs: MaxKey) -> Bool { return true }
}

class MinKey: BsonValue, Equatable {
    public var bsonType: BsonType { return .minKey }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_minkey(data, key, Int32(key.count))
    }
    static func == (lhs: MinKey, rhs: MinKey) -> Bool { return true }
}

class ObjectId: BsonValue, Equatable {
    public var bsonType: BsonType { return .objectId }
    let oid: UnsafePointer<bson_oid_t>

    init() {
        let oid = UnsafeMutablePointer<bson_oid_t>.allocate(capacity: 1)
        // the second parameter should be a bson_context_t, but for now use nil
        bson_oid_init(oid, nil)
        self.oid = UnsafePointer(oid)
    }

    init(from: UnsafePointer<bson_oid_t>) {
        self.oid = from
    }

    init(from: String) {
        let oid = UnsafeMutablePointer<bson_oid_t>.allocate(capacity: 1)
        bson_oid_init_from_string(oid, from)
        self.oid = UnsafePointer(oid)
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_oid(data, key, Int32(key.count), self.oid)
    }

    static func fromBSON(_ iter: inout bson_iter_t) -> ObjectId {
        guard let oid = bson_iter_oid(&iter) else {
            preconditionFailure("Failed to retrieve ObjectID value")
        }
        return ObjectId(from: oid)
    }

    public var asString: String {
        let data = UnsafeMutablePointer<Int8>.allocate(capacity: 1)
        bson_oid_to_string(self.oid, data)
        return String(cString: data)
    }

    static func == (lhs: ObjectId, rhs: ObjectId) -> Bool { return lhs.asString == rhs.asString }

}

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

extension NSRegularExpression: BsonValue {
    public var bsonType: BsonType { return .regularExpression }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_regex(data, key, Int32(key.count), self.pattern, self.stringOptions)
    }

    static func fromBSON(_ iter: inout bson_iter_t) throws -> NSRegularExpression {
        let options = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
        guard let pattern = bson_iter_regex(&iter, options) else {
            preconditionFailure("Failed to retrieve regular expression pattern")
        }
        guard let stringOptions = options.pointee else {
            preconditionFailure("Failed to retrieve regular expression options")
        }

        let opts = NSRegularExpression.optionsFromString(String(cString: stringOptions))
        return try self.init(pattern: String(cString: pattern), options: opts)
    }

    // Convert a string of options flags into an equivalent NSRegularExpression.Options.
    static func optionsFromString(_ stringOptions: String) -> NSRegularExpression.Options {
        var optsObj: NSRegularExpression.Options = []
        for o in stringOptions {
            if let value = regexOptsMap[o] {
                 optsObj.update(with: value)
            }
        }
        return optsObj
    }

    // Convert this instance's Options object into an alphabetically-sorted string of characters.
    public var stringOptions: String {
        var optsString = ""
        for (char, o) in regexOptsMap { if options.contains(o) { optsString += String(char) } }
        return String(optsString.sorted())
    }
}

extension String: BsonValue {
    public var bsonType: BsonType { return .string }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_utf8(data, key, Int32(key.count), self, Int32(self.count))
    }
}

class Timestamp: BsonValue, Equatable {
    public var bsonType: BsonType { return .timestamp }
    var timestamp = UInt32(0)
    var increment = UInt32(0)

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

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_timestamp(data, key, Int32(key.count), self.timestamp, self.increment)
    }

    static func fromBSON(_ iter: inout bson_iter_t) -> Timestamp {
        let t = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let i = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        bson_iter_timestamp(&iter, t, i)
        return Timestamp(timestamp: t.pointee, inc: i.pointee)
    }

    static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.increment == rhs.increment
    }

}
