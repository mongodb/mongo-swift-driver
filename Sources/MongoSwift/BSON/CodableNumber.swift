import Foundation

/// A protocol for numbers that require encoding/decoding support but are not necessarily BSON types.
internal protocol CodableNumber {
    /// Attempts to initialize this type from an analogous `BSONValue`. Returns `nil`
    /// the `from` value cannot be accurately represented as this type.
    init?(from value: BSONValue)

    /// Initializer for creating from `Int`, `Int32`, `Int64`
    init?<T: BinaryInteger>(exactly source: T)

    /// Initializer for creating from a `Double`
    init?(exactly source: Double)

    /// Converts this number to a `BSONValue`. Returns `nil` if it cannot
    /// be represented exactly.
    var bsonValue: BSONValue? { get }
}

extension CodableNumber {
    internal init?(from value: BSONValue) {
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
    internal var bsonValue: BSONValue? {
        return self as? BSONValue
    }
}

extension Int: CodableNumber {}
extension Int32: CodableNumber {}
extension Int64: CodableNumber {}

extension Int8: CodableNumber {
    internal var bsonValue: BSONValue? {
        // Int8 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension Int16: CodableNumber {
    internal var bsonValue: BSONValue? {
        // Int16 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension UInt8: CodableNumber {
    internal var bsonValue: BSONValue? {
        // UInt8 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension UInt16: CodableNumber {
    internal var bsonValue: BSONValue? {
        // UInt16 always fits in an Int32
        return Int32(exactly: self)
    }
}

extension UInt32: CodableNumber {
    internal var bsonValue: BSONValue? {
        // try an Int32 first
        if let int32 = Int32(exactly: self) {
            return int32
        }
        // otherwise, will always fit in an Int64
        return Int64(exactly: self)
    }
}

extension UInt64: CodableNumber {
    internal var bsonValue: BSONValue? {
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

extension UInt: CodableNumber {
    internal var bsonValue: BSONValue? {
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
extension Double: CodableNumber {
    internal init?(from value: BSONValue) {
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
extension Float: CodableNumber {
    internal init?(from value: BSONValue) {
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

    internal var bsonValue: BSONValue? {
        // a Float can always be represented as a Double
        return Double(exactly: self)
    }
}
