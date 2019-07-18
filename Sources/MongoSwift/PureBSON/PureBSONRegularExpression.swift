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

        self.pattern = try String(cStringData: &data)
        self.options = try String(cStringData: &data)
    }

    internal func toBSON() -> Data {
        var data = self.pattern.toCStringData()
        data.append(self.options.toCStringData())
        return data
    }
}
