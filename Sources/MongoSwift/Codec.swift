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
        // Use a BsonEncoder to get a Ddcument, and then call Document.bsonAppend. 
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
        let topContainer: NSMutableDictionary = storage.getContainer()
        return _BsonKeyedEncodingContainer(referencing: self, wrapping: topContainer)
    }
}

/// A wrapper around the top-level NSMutableDictionary, handling its creation and storage. 
private struct _BsonEncodingStorage {

    /// A top-level container representing a BSON document. 
    fileprivate var container = NSMutableDictionary()

    /// Creates a new top-level container and saves it, and returns the container 
    /// for use by a _BsonEncoder. 
    fileprivate mutating func getContainer() -> NSMutableDictionary {
        return container
    }

    /// Returns the current container as a Document, and disassociates it from this 
    // _BsonEncodingStorage. Should only be called when all values have been encoded.
    fileprivate mutating func popContainer() -> Document {
        defer {container = NSMutableDictionary()}
        return dictToDocument(container)
    }
}

/// A keyed coding container, storing key-value pairs to be serialized into a BSON document. 
private struct _BsonKeyedEncodingContainer {
    /// The encoder we're writing to.
    private let encoder: _BsonEncoder

    /// The container we're writing to.
    private let container: NSMutableDictionary

    /// Initializes a new keyed coding container with the provided encoder and container. 
    fileprivate init(referencing encoder: _BsonEncoder, wrapping container: NSMutableDictionary) {
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
        let dictionary = NSMutableDictionary()
        container[key] = dictionary
        return _BsonKeyedEncodingContainer(referencing: encoder, wrapping: dictionary)
    }

    /// Create a new nested unkeyed container and store it in this container under the provided key. 
    private mutating func nestedUnkeyedContainer(forKey key: String) -> _BsonUnkeyedEncodingContainer {
        let array = NSMutableArray()
        container[key] = array
        return _BsonUnkeyedEncodingContainer(referencing: encoder, wrapping: array)
    }
}

/// An unkeyed coding container, storing an ordered sequence of values to be serialized into a BSON array. 
private struct _BsonUnkeyedEncodingContainer {
    /// The encoder we're writing to.
    private let encoder: _BsonEncoder

    /// The container we're writing to.
    private let container: NSMutableArray

    /// Initializes a new unkeyed coding container with the provided encoder and container. 
    fileprivate init(referencing encoder: _BsonEncoder, wrapping container: NSMutableArray) {
        self.encoder = encoder
        self.container = container
    }

    /// Adds nil to the end of this container.  
    mutating func encodeNil() { container.add(NSNull()) }

    /// Adds value to the end of this container.
    mutating func encode(_ value: BsonValue) throws {
        switch value {

        // If it's an array, create a new nested unkeyed container, stored at the end of this
        // container, and copy in array values. 
        case let val as [BsonValue]:
            var nested = nestedUnkeyedContainer()
            for e in val { try nested.encode(e) }

        // If it's a map, create a new nested, keyed container, stored at the end of this container,
        //  and copy in key-value pairs.
        case let val as [String: BsonValue]:
            var nested = nestedContainer()
            for (k, v) in val { try nested.encode(v, forKey: k) }

        case let val as BsonEncodable:
            let encoder = BsonEncoder()
            try val.encode(to: encoder)
            container.add(encoder._encoder.storage.popContainer())

        // Otherwise it must be a single value, so just add value to the end of the container. 
        default:
            container.add(value)
        }
    }

    /// Create a new nested container and store it at the end of this container. 
    private mutating func nestedContainer() -> _BsonKeyedEncodingContainer {
        let dictionary = NSMutableDictionary()
        container.add(dictionary)
        return _BsonKeyedEncodingContainer(referencing: encoder, wrapping: dictionary)
    }

    /// Create a new nested array and store it at the end of this container.
    private mutating func nestedUnkeyedContainer() -> _BsonUnkeyedEncodingContainer {
        let array = NSMutableArray()
        container.add(array)
        return _BsonUnkeyedEncodingContainer(referencing: encoder, wrapping: array)
    }
}

/**
* Converts an `NSDictionary` to a BSON document. Should only be called if you're sure sure the dictionary 
* only contains `String` keys and `BsonValue` values, i.e. when the `NSDictionary` came from a 
* `BsonKeyedCodingContainer`.  
*
* - Parameters: 
*   - arr: an `NSDictionary` with `String` keys and `BsonValue` values
*
* - Returns: A BSON `Document` containing the data from arr. 
*/
private func dictToDocument(_ dict: NSDictionary) -> Document {
    let doc = Document()
    for (k, v) in dict {
        guard let key = k as? String else { preconditionFailure("Could not cast key to string") }
        doc[key] = getBsonValue(v)
    }
    return doc
}

/**
* Converts an `NSArray` to a BSON document, where the keys "0", "1", etc. correspond to array indices. 
* Should only be called if you're sure sure the array only contains `BsonValue`s, i.e. when the `NSArray`
* came from a `BsonUnkeyedCodingContainer`.  
*
* - Parameters: 
*   - arr: an `NSArray` containing only `BsonValue`s
*
* - Returns: A BSON `Document` containing the data from arr. 
*/
private func arrayToDocument(_ arr: NSArray) -> Document {
    let doc = Document()
    for (i, v) in arr.enumerated() {
        doc[String(i)] = getBsonValue(v)
    }
    return doc
}

/**
* Given a value, gets a corresponding BSONValue (which is possibly a standalone value, or could be a nested 
* array or document.) Should only be used when you're sure the casting will succeed. 
*
* - Parameters:
*   - value: A value that is a `NSDictionary`, `NSArray`, or `BsonValue`.
*
* - Returns: A `BsonValue` equivalent to value. 
*/
private func getBsonValue(_ value: Any) -> BsonValue {
    switch value {
    case let val as NSDictionary:
        return dictToDocument(val)
    case let val as NSArray:
        return arrayToDocument(val)
    case let val as BsonValue:
        return val
    default:
        preconditionFailure("Value \(value) with type \(type(of: value)) didn't match any expected types")
    }
}
