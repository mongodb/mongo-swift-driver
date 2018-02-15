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
}

/// Extension of BSONEncodable to make it actually implement BsonValue.
extension BsonEncodable {
    public var bsonType: BsonType { return .document }
    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        // Use a BsonEncoder to get a Document, and then call Document.bsonAppend. 
        let encoder = BsonEncoder()
        do {
            let doc: Document = try encoder.encode(self)
            return doc.bsonAppend(data: data, key: key)
        } catch {
            return false
        }
    }
}

/// A BsonEncoder for encoding BsonEncodable types to BSON documents. 
public class BsonEncoder {
    fileprivate var _encoder = _BsonEncoder()

    /**
    * Encodes value using this BsonEncoder. 
    *
    * - Parameters:
    *   - value: an object that implements the BsonEncodable protocol
    * 
    * - Returns: a `Document` containing the serialized BSON data. 
    */
    public func encode(_ value: BsonEncodable) throws -> Document {
        try value.encode(to: self)
        return _encoder.storage.popContainer()
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
        }
    }

}

/// A private class wrapping a Swift array so we can pass it by reference for 
/// encoder storage purposes. We use this rather than NSMutableArray because
/// it allows us to more easily preserve type information. 
private class MutableArray {
    fileprivate var array = [Any]()
    fileprivate func append(_ value: Any) {
        array.append(value)
    }
}

/// A private class wrapping a Swift dictionary so we can pass it by reference
/// for encoder storage purposes. We use this rather than NSMutableDictionary 
/// because it allows us to more easily preserve type information. 
private class MutableDictionary {
    fileprivate var dictionary = [String: Any]()
    subscript(key: String) -> Any? {
        get { return dictionary[key] }
        set(newValue) { dictionary[key] = newValue }
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
        return dictToDocument(container)
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

/**
* Converts a `MutableDictionary` to a BSON document. Should only be called if you're sure sure the dictionary 
* only has values that can be successfully cast to BSON values. 
*
* - Parameters: 
*   - dict: a `MutableDictionary` with `String` keys and `BsonValue` values
*
* - Returns: A BSON `Document` containing the data from arr. 
*/
private func dictToDocument(_ dict: MutableDictionary) -> Document {
    let doc = Document()
    for (k, v) in dict.dictionary {
        doc[k] = getBsonValue(v)
    }
    return doc
}

/**
* Converts a `MutableArray` to a BSON document, where the keys "0", "1", etc. correspond to array indices. 
* Should only be used if you're sure the array only contains values that can be successfully cast to BSON values.
*
* - Parameters: 
*   - arr: a `MutableArray` containing only `BsonValue`s
*
* - Returns: A BSON `Document` containing the data from arr. 
*/
private func arrayToDocument(_ arr: MutableArray) -> Document {
    let doc = Document()
    for (i, v) in arr.array.enumerated() {
        doc[String(i)] = getBsonValue(v)
    }
    return doc
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
private func getBsonValue(_ value: Any) -> BsonValue {
    switch value {
    case let val as MutableDictionary:
        return dictToDocument(val)
    case let val as MutableArray:
        return arrayToDocument(val)
    case let val as BsonValue:
        return val
    default:
        preconditionFailure("Value \(value) with type \(type(of: value)) didn't match any expected types")
    }
}
