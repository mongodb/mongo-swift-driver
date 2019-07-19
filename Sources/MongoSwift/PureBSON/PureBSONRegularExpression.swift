import Foundation

/// A struct to represent a BSON regular expression.
public struct PureBSONRegularExpression: Codable {
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
}

extension PureBSONRegularExpression: Equatable {}

extension PureBSONRegularExpression: Hashable {}

extension PureBSONRegularExpression: PureBSONValue {
    internal static var bsonType: BSONType { return .regularExpression }

    internal var bson: BSON { return .regex(self) }

    internal init(from data: inout Data) throws {
        guard data.count >= 2 else {
            throw RuntimeError.internalError(message: "expected to get at least 2 bytes, got \(data.count)")
        }

        let pattern = try String(cStringData: &data)
        let options = try String(cStringData: &data)

        self.init(pattern: pattern, options: options)
    }

    internal func toBSON() -> Data {
        var data = self.pattern.toCStringData()
        data.append(self.options.toCStringData())
        return data
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
    public convenience init(fromPure regex: PureBSONRegularExpression) throws {
        let opts = NSRegularExpression.optionsFromString(regex.options)
        try self.init(pattern: regex.pattern, options: opts)
    }
}
