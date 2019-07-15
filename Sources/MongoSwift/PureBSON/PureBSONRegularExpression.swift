import Foundation

/// A struct to represent a BSON regular expression.
public struct PureBSONRegularExpression: PureBSONValue {
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

    public init(from data: Data) throws {
        guard !data.isEmpty else {
            throw RuntimeError.internalError(message: "empty buffer provided to regex initializer")
        }

        // Check that 2 null bytes are in the buffer and that the buffer is null terminated.
        guard data.filter({ $0 == 0 }).count == 2 && data.last ?? 1 == 0 else {
            throw RuntimeError.internalError(message: "improperly formatted regex BSON")
        }

        let pattern = data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> String in
            String(cString: ptr)
        }

        let options = data[(pattern.utf8.count + 1)...].withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> String in
            String(cString: ptr)
        }

        self.init(pattern: pattern, options: options)
    }
}
