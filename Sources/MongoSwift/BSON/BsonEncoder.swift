import Foundation
import libbson

/// Types that conform to the BsonEncodable protocol can be encoded to a BSON document. 
/// Since a BsonEncodable knows how to encode itself to a document, it can be used in 
/// place of a BSONValue.
public protocol BsonEncodable: BsonValue {
    /**
     * Encodes this value to a BsonEncoder.
     *
     * - Parameters:
     *   - to: A `BsonEncoder` with which to encode this value
     */
    func encode(to encoder: BsonEncoder) throws

    /**
     * Returns a list of fields that should be skipped when encoding 
     * this type. This method only needs to be implemented if there
     * are fields to skip and this type is utilizing the default 
     * `encode(to encoder: BsonEncoder)` implementation. 
     */
    var skipFields: [String] { get }
}

/// Extension of BSONEncodable to make it actually implement BsonValue.
extension BsonEncodable {
    public var bsonType: BsonType { return .document }
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        // Use a BsonEncoder to get a Document, and then call Document.encode. 
        let encoder = BsonEncoder()
        if let doc = try encoder.encode(self) {
            try doc.encode(to: data, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        // in the future we should use a BsonDecoder here 
        return Document.from(iter: &iter)
    }
}

/// Extracts the underlying value, converting it to a non-optional if it is optional.
func unwrap(_ any: Any) -> Any {
    let mirror = Mirror(reflecting: any)
    if mirror.displayStyle != .optional {
        return any
    }

    if mirror.children.count == 0 { return NSNull() }
    let (_, some) = mirror.children.first!
    return some
}

/// Extension of BsonEncodable to provide a default encode(to encoder: BsonEncoder) implementation
/// and default skipFields value.
extension BsonEncodable {
    public func encode(to encoder: BsonEncoder) throws {
        let mirror = Mirror(reflecting: self)
        for (key, value) in mirror.children {
            guard let key = key else { continue }
            if self.skipFields.contains(key) { continue }
            let v = unwrap(value)
            try encoder.encode(v as? BsonValue, forKey: key)
        }
    }

    // By default, skip no fields
    public var skipFields: [String] { return [] }
}

/// A BsonEncoder for encoding BsonEncodable types to BSON documents. 
public class BsonEncoder {
    fileprivate var _encoder = _BsonEncoder()

    public enum NilEncodingStrategy {
        /// If a provided value is nil, do not encode it.
        /// If a top-level container is empty, do not encode it.
        case omit

        /// Encode nil values if they are present. If a top-level
        /// container is empty, encode an empty document.
        case include
    }

    /// The strategy to use for encoding nil values. Defaults to `omit`.
    open var nilEncodingStrategy: NilEncodingStrategy = .omit

    // Create a new BsonEncoder, optionally passing in a NilEncodingStrategy.
    public init(nilStrategy: NilEncodingStrategy = .omit) {
        self.nilEncodingStrategy = nilStrategy
    }

    /**
    * Encodes value using this BsonEncoder. 
    *
    * - Parameters:
    *   - value: an object that implements the BsonEncodable protocol
    * 
    * - Returns: a `Document` containing the serialized BSON data. 
    */
    public func encode(_ value: BsonEncodable?) throws -> Document? {
        guard let v = value else {
            return self.nilEncodingStrategy == .include ? Document() : nil
        }

        try v.encode(to: self)
        let doc = _encoder.storage.popContainer()

        if self.nilEncodingStrategy == .omit && doc == [:] as Document {
            return nil
        }

        return doc
    }

    /**
    * Stores a `BsonValue` under the provided key. 
    *
    * - Parameters:
    *   - value: A `BsonValue` (possibly also a `BsonEncodable`) to store under this key
    *   - key: A `String` to store this value under
    * 
    */
    public func encode(_ value: BsonValue?, forKey key: String) throws {
        if let v = value {
            var container = _encoder.container()
            try container.encode(v, forKey: key)
        } else if self.nilEncodingStrategy == .include {
            var container = _encoder.container()
            container.encodeNil(forKey: key)
        }
    }

}

/// A private class for use by BsonEncoder. _BsonEncoder handles storage for the 
/// encoder and provides encoding containers. 
private class _BsonEncoder {

    /// The encoder's storage
    fileprivate var storage: _BsonEncodingStorage

    fileprivate init() {
        storage = _BsonEncodingStorage()
    }

    /// Get a top-container into which BSON values can be encoded.
    fileprivate func container() -> _BsonKeyedEncodingContainer {
        let topContainer: MutableDictionary = storage.getContainer()
        return _BsonKeyedEncodingContainer(referencing: self, wrapping: topContainer)
    }
}

/// A wrapper around the top-level MutableDictionary, handling its creation and storage. 
private struct _BsonEncodingStorage {

    /// A top-level container representing a BSON document. 
    fileprivate var container = MutableDictionary()

    /// Creates a new top-level container and saves it, and returns the container 
    /// for use by a _BsonEncoder. 
    fileprivate mutating func getContainer() -> MutableDictionary {
        return container
    }

    /// Returns the current container as a Document, and disassociates it from this 
    // _BsonEncodingStorage. Should only be called when all values have been encoded.
    fileprivate mutating func popContainer() -> Document {
        defer {container = MutableDictionary()}
        return container.asDocument()
    }
}

/// A keyed coding container, storing key-value pairs to be serialized into a BSON document. 
private struct _BsonKeyedEncodingContainer {
    /// The encoder we're writing to.
    private let encoder: _BsonEncoder

    /// The container we're writing to.
    private let container: MutableDictionary

    /// Initializes a new keyed coding container with the provided encoder and container. 
    fileprivate init(referencing encoder: _BsonEncoder, wrapping container: MutableDictionary) {
        self.encoder = encoder
        self.container = container
    }

    /// Stores nil in this container under the provided key. 
    mutating func encodeNil(forKey key: String) { container[key] = NSNull() }

    /// Stores value in this container under the provided key. 
    mutating func encode(_ value: BsonValue, forKey key: String) throws {
        switch value {

        // If it's an array, create a new nested unkeyed container, stored under the 
        // provided key, and copy in array values. 
        case let val as [BsonValue]:
            var nested = nestedUnkeyedContainer(forKey: key)
            for e in val { try nested.encode(e) }

        // If it's a map, create a new nested keyed container, stored under the provided key,
        // and copy in the key-value pairs. 
        case let val as [String: BsonValue]:
            var nested = nestedContainer(forKey: key)
            for (k, v) in val { try nested.encode(v, forKey: k) }

        case let val as BsonEncodable:
            let encoder = BsonEncoder()
            try val.encode(to: encoder)
            container[key] = encoder._encoder.storage.popContainer()

        // Otherwise it must be a single value, so store it under the provided key. 
        default:
            container[key] = value
        }
    }

    /// Create a new nested container and store it in this container under the provided key. 
    private mutating func nestedContainer(forKey key: String) -> _BsonKeyedEncodingContainer {
        let dictionary = MutableDictionary()
        container[key] = dictionary
        return _BsonKeyedEncodingContainer(referencing: encoder, wrapping: dictionary)
    }

    /// Create a new nested unkeyed container and store it in this container under the provided key. 
    private mutating func nestedUnkeyedContainer(forKey key: String) -> _BsonUnkeyedEncodingContainer {
        let array = MutableArray()
        container[key] = array
        return _BsonUnkeyedEncodingContainer(referencing: encoder, wrapping: array)
    }
}

/// An unkeyed coding container, storing an ordered sequence of values to be serialized into a BSON array. 
private struct _BsonUnkeyedEncodingContainer {
    /// The encoder we're writing to.
    private let encoder: _BsonEncoder

    /// The container we're writing to.
    private let container: MutableArray

    /// Initializes a new unkeyed coding container with the provided encoder and container. 
    fileprivate init(referencing encoder: _BsonEncoder, wrapping container: MutableArray) {
        self.encoder = encoder
        self.container = container
    }

    /// Adds nil to the end of this container.  
    mutating func encodeNil() { container.append(NSNull()) }

    /// Adds value to the end of this container.
    mutating func encode(_ value: BsonValue) throws {
        switch value {

        // If it's an array, create a new nested unkeyed container, stored at the end of this
        // container, and copy in array values. 
        case let val as [BsonValue]:
            var nested = nestedUnkeyedContainer()
            for e in val { try nested.encode(e) }

        case let val as BsonEncodable:
            let encoder = BsonEncoder()
            try val.encode(to: encoder)
            container.append(encoder._encoder.storage.popContainer())

        // Otherwise it must be a single value, so just add value to the end of the container. 
        default:
            container.append(value)
        }
    }

    /// Create a new nested container and store it at the end of this container. 
    private mutating func nestedContainer() -> _BsonKeyedEncodingContainer {
        let dictionary = MutableDictionary()
        container.append(dictionary)
        return _BsonKeyedEncodingContainer(referencing: encoder, wrapping: dictionary)
    }

    /// Create a new nested array and store it at the end of this container.
    private mutating func nestedUnkeyedContainer() -> _BsonUnkeyedEncodingContainer {
        let array = MutableArray()
        container.append(array)
        return _BsonUnkeyedEncodingContainer(referencing: encoder, wrapping: array)
    }
}

/// A private class wrapping a Swift array so we can pass it by reference for 
/// encoder storage purposes. We use this rather than NSMutableArray because
/// it allows us to preserve Swift type information. 
private class MutableArray {
    var array = [Any]()
    fileprivate func append(_ value: Any) {
        array.append(value)
    }

    /// Converts self to a `Document` where keys "0", "1", etc.
    /// correspond to array indices. 
    func asDocument() -> Document {
        var doc = Document()
        for (i, v) in array.enumerated() {
            doc[String(i)] = getBsonValue(v)
        }
        return doc
    }
}

/// A private class wrapping a Swift dictionary so we can pass it by reference
/// for encoder storage purposes. We use this rather than NSMutableDictionary 
/// because it allows us to preserve Swift type information.
private class MutableDictionary {
    var dictionary = [String: Any]()
    subscript(key: String) -> Any? {
        get { return dictionary[key] }
        set(newValue) { dictionary[key] = newValue }
    }

    /// Converts self to a `Document` with equivalent key-value pairs.
    func asDocument() -> Document {
        var doc = Document()
        for (k, v) in dictionary {
            doc[k] = getBsonValue(v)
        }
        return doc
    }
}

/**
* Given a value, gets a corresponding BSONValue (which is possibly a standalone value, or could be a nested 
* array or document.) Should only be used when you're sure the casting will succeed. 
*
* - Parameters:
*   - value: A value that is known to be a `MutableDictionary`, `MutableArray`, or `BsonValue`.
*
* - Returns: A `BsonValue` equivalent to value. 
*/
private func getBsonValue(_ value: Any) -> BsonValue? {
    switch value {
    case let val as MutableDictionary:
        return val.asDocument()
    case let val as MutableArray:
        return val.asDocument()
    case let val as BsonValue:
        return val
    case _ as NSNull:
        return nil
    default:
        preconditionFailure("Value \(value) with type \(type(of: value)) didn't match any expected types")
    }
}
