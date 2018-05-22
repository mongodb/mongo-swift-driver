import Foundation

/// A protocol for numbers that require encoding/decoding support but are not necessarily BSON types.
internal protocol CodableNumber {
    /// Attempts to initialize this type from an analogous BsonValue. Returns nil
    /// the `from` value cannot be accurately represented as this type.
    init?(from value: BsonValue)

    /// when we rewrite encoder, will add a `asBsonValue` method here that handles the 
    /// CodableNumber -> BsonValue conversion

    /// Initializer for creating from Int, Int32, Int64
    init?<T: BinaryInteger>(exactly source: T)

    /// Initializer for creating from a Double
    init?(exactly source: Double)
}

extension CodableNumber {
    init?(from value: BsonValue) {
        switch value {
        case let v as Int:
            if let exact = Self(exactly: v) { self = exact; return }
        case let v as Int32:
            if let exact = Self(exactly: v) { self = exact; return }
        case let v as Int64:
            if let exact = Self(exactly: v) { self = exact; return }
        case let v as Double:
            if let exact = Self(exactly: v) { self = exact; return }
        default:
            break
        }
        return nil
    }
}

extension Int: CodableNumber {}
extension Int8: CodableNumber {}
extension Int16: CodableNumber {}
extension Int32: CodableNumber {}
extension Int64: CodableNumber {}
extension UInt8: CodableNumber {}
extension UInt16: CodableNumber {}
extension UInt32: CodableNumber {}
extension UInt64: CodableNumber {}
extension UInt: CodableNumber {}

/// Override the default initializer due to a runtime assertion that fails
/// when initializing a Double from an Int (possible Swift bug?)
extension Double: CodableNumber {
    init?(from value: BsonValue) {
        switch value {
        case let v as Int:
            if let exact = Double(exactly: v) { self = exact; return }
        case let v as Int32:
            if let exact = Double(exactly: v) { self = exact; return }
        case let v as Int64:
            if let exact = Double(exactly: v) { self = exact; return }
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
    init?(from value: BsonValue) {
        switch value {
        case let v as Int:
            if let exact = Float(exactly: v) { self = exact; return }
        case let v as Int32:
            if let exact = Float(exactly: v) { self = exact; return }
        case let v as Int64:
            if let exact = Float(exactly: v) { self = exact; return }
        case let v as Double:
            if let exact = Float(exactly: v) { self = exact; return }
        default:
            break
        }
        return nil
    }
}
