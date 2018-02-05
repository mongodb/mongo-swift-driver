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
}

extension Array: BsonValue {
    public var bsonType: BsonType { return .array }
}

extension Bool: BsonValue {
    public var bsonType: BsonType { return .boolean }
}

extension Date: BsonValue {
    public var bsonType: BsonType { return .dateTime }

    init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: Double(msSinceEpoch / 1000))
    }

    public var msSinceEpoch: Int64 { return Int64(self.timeIntervalSince1970 * 1000) }
}

extension Double: BsonValue {
    public var bsonType: BsonType { return .double }
}

extension Int: BsonValue {
    public var bsonType: BsonType { return .int32 }
}

extension Int32: BsonValue {
    public var bsonType: BsonType { return .int32 }
}

extension Int64: BsonValue {
    public var bsonType: BsonType { return .int64 }
}

class MaxKey: BsonValue, Equatable {
    public var bsonType: BsonType { return .maxKey }
    static func == (lhs: MaxKey, rhs: MaxKey) -> Bool { return true }
}

class MinKey: BsonValue, Equatable {
    public var bsonType: BsonType { return .minKey }
    static func == (lhs: MinKey, rhs: MinKey) -> Bool { return true }
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
}
