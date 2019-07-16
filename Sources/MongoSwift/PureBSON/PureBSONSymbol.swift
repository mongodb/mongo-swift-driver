import Foundation

/// A struct to represent the deprecated Symbol type.
/// Symbols cannot be instantiated, but they can be read from existing documents that contain them.
public struct PureBSONSymbol: PureBSONValue, CustomStringConvertible {
    public var description: String {
        return stringValue
    }

    /// String representation of this `Symbol`.
    public let stringValue: String

    internal init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    internal init(from data: Data) throws {
        self.stringValue = try String(from: data)
    }

    internal func toBSON() -> Data {
        return self.stringValue.toBSON()
    }
}

extension PureBSONSymbol: Equatable {}

extension PureBSONSymbol: Hashable {}
