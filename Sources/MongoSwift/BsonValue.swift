import Foundation

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

let optsMap: [String: NSRegularExpression.Options] = [
    "i": .caseInsensitive,
    "m": .anchorsMatchLines,
    "s": .dotMatchesLineSeparators,
    "u": .useUnicodeWordBoundaries,
    "x": .allowCommentsAndWhitespace
]

extension NSRegularExpression: BsonValue {
    public var bsonType: BsonType { return .regularExpression }

    static func optionsFromString(_ options: String) -> NSRegularExpression.Options {
        var opts: NSRegularExpression.Options = []
        for o in options { opts.update(with: optsMap[String(o)]!) }
        return opts
    }

    public var stringOptions: String {
        var opts = ""
        for (str, o) in optsMap { if options.contains(o) { opts += str } }
        return String(opts.sorted())
    }
}

extension String: BsonValue {
    public var bsonType: BsonType { return .string }
}
