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
