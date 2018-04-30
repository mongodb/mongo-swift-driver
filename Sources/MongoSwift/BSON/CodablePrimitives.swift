import Foundation

/// Just a temporary error to make code compile until we implement everything.
struct UnimplementedError: LocalizedError {
    public var errorDescription: String? { return "Unimplemented" }
}

/// A protocol for types that are not BSON types but require encoding/decoding support. 
internal protocol Primitive {
	/// Attempts to initialize this type from an analogous BsonValue. Throws if 
	/// the `from` value cannot be accurately represented as this type.
    init(from: BsonValue) throws

    /// when we rewrite encoder, will add a `asBsonValue` method here that handles the 
    /// Primitive -> BsonValue conversion
}

extension Int8: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension Int16: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt8: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt16: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt32: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt64: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension Float: Primitive {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}
