import Foundation

/// A protocol for numbers that require encoding/decoding support but are not necessarily BSON types.
internal protocol PureCodableNumber {
    /// Attempts to initialize this type from an analogous `BSONValue`. Returns `nil`
    /// the `from` value cannot be accurately represented as this type.
    init?(from value: PureBSONValue)

    /// Initializer for creating from `Int`, `Int32`, `Int64`
    init?<T: BinaryInteger>(exactly source: T)

    /// Initializer for creating from a `Double`
    init?(exactly source: Double)

    /// Converts this number to a `BSONValue`. Returns `nil` if it cannot
    /// be represented exactly.
    var pureBsonValue: PureBSONValue? { get }
}

extension PureCodableNumber {
    internal init?(from value: PureBSONValue) {
        switch value {
        case let v as Int:
            if let exact = Self(exactly: v) {
                self = exact
                return
            }
        case let v as Int32:
            if let exact = Self(exactly: v) {
                self = exact
                return
            }
        case let v as Int64:
            if let exact = Self(exactly: v) {
                self = exact
                return
            }
        case let v as Double:
            if let exact = Self(exactly: v) {
                self = exact
                return
            }
        default:
            break
        }
        return nil
    }

    /// By default, just try casting the number to a `BSONValue`. Types
    /// where that will not work provide their own implementation of the
    /// `bsonValue` computed property.
    internal var pureBsonValue: PureBSONValue? {
        return self as? PureBSONValue
    }
}

extension Int: PureCodableNumber {}
extension Int32: PureCodableNumber {}
extension Int64: PureCodableNumber {}

extension Int8: PureCodableNumber {
    internal var pureBsonValue: PureBSONValue? {
        // Int8 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension Int16: PureCodableNumber {
    internal var pureBsonValue: PureBSONValue? {
        // Int16 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension UInt8: PureCodableNumber {
    internal var pureBsonValue: PureBSONValue? {
        // UInt8 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension UInt16: PureCodableNumber {
    internal var pureBsonValue: PureBSONValue? {
        // UInt16 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension UInt32: PureCodableNumber {
    internal var pureBsonValue: PureBSONValue? {
        // try an Int32 first
        if let int32 = Int32(exactly: self) {
            return int32
        }
        // otherwise, will always fit in an Int64
        return Int64(exactly: self)
    }
}

extension UInt64: PureCodableNumber {
    internal var pureBsonValue: PureBSONValue? {
        if let int32 = Int32(exactly: self) {
            return int32
        }
        if let int64 = Int64(exactly: self) {
            return int64
        }
        if let double = Double(exactly: self) {
            return double
        }
        // we could consider trying a Decimal128 here. However,
        // it's not clear how we could support decoding something
        // stored as Decimal128 back to a UInt64 without access
        // to libbson internals.
        return nil
    }
}

extension UInt: PureCodableNumber {
    internal var pureBsonValue: PureBSONValue? {
        if let int32 = Int32(exactly: self) {
            return int32
        }
        if let int64 = Int64(exactly: self) {
            return int64
        }
        if let double = Double(exactly: self) {
            return double
        }
        // we could consider trying a Decimal128 here. However,
        // it's not clear how we could support decoding something
        // stored as Decimal128 back to a UInt without access
        // to libbson internals.
        return nil
    }
}

/// Override the default initializer due to a runtime assertion that fails
/// when initializing a Double from an Int (possible Swift bug?)
extension Double: PureCodableNumber {
    internal init?(from value: PureBSONValue) {
        switch value {
        case let v as Int:
            if let exact = Double(exactly: v) {
                self = exact
                return
            }
        case let v as Int32:
            if let exact = Double(exactly: v) {
                self = exact
                return
            }
        case let v as Int64:
            if let exact = Double(exactly: v) {
                self = exact
                return
            }
        case let v as Double:
            self = v
            return
        default:
            break
        }
        return nil
    }
}

/// Override the default initializer due to a runtime assertion that fails
/// when initializing a Float from an Int (possible Swift bug?)
extension Float: PureCodableNumber {
    internal init?(from value: PureBSONValue) {
        switch value {
        case let v as Int:
            if let exact = Float(exactly: v) {
                self = exact
                return
            }
        case let v as Int32:
            if let exact = Float(exactly: v) {
                self = exact
                return
            }
        case let v as Int64:
            if let exact = Float(exactly: v) {
                self = exact
                return
            }
        case let v as Double:
            if let exact = Float(exactly: v) {
                self = exact
                return
            }
        default:
            break
        }
        return nil
    }

    internal var pureBsonValue: PureBSONValue? {
        // a Float can always be represented as a Double
        return Double(exactly: self)
    }
}
