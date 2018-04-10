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
    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        // Use a BsonEncoder to get a Document, and then call Document.bsonAppend. 
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

/// Extension of BsonEncodable to provide a default encode(to encoder: BsonEncoder) implementation.
extension BsonEncodable {
    public func encode(to encoder: BsonEncoder) throws {
        let mirror = Mirror(reflecting: self)
        for (key, value) in mirror.children {
            guard let key = key else { continue }
            let v = unwrap(value)
            try encoder.encode(v as? BsonValue, forKey: key)
        }
    }
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

/// `BsonDecoder` facilitates the decoding of BSON into semantic `Decodable` types.
public class BsonDecoder {

    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Options set on the top-level decoder to pass down the decoding hierarchy.
    fileprivate struct _Options {
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level decoder.
    fileprivate var options: _Options {
        return _Options(userInfo: userInfo)
    }

    /// Initializes `self`.
    public init() {}

    /// Decodes a top-level value of the given type from the given BSON representation.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The BSON document to decode from.
    /// - returns: A value of the requested type.
    /// - throws: An error if any value throws an error during decoding.
    public func decode<T: Decodable>(_ type: T.Type, from data: Document) throws -> T {
        let _decoder = _BsonDecoder(referencing: data, options: self.options)
        return try type.init(from: _decoder)
    }
}

private class _BsonDecoder: Decoder {

    /// The decoder's storage.
    fileprivate var storage: _BsonDecodingStorage

    /// Options set on the top-level decoder.
    fileprivate let options: BsonDecoder._Options

    /// The path to the current point in decoding.
    fileprivate(set) public var codingPath: [CodingKey]

    /// Contextual user-provided information for use during decoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        return self.options.userInfo
    }

    /// Performs the given closure with the given key pushed onto the end of the current coding path.
    ///
    /// - parameter key: The key to push. May be nil for unkeyed containers.
    /// - parameter work: The work to perform with the key in the path.
    fileprivate func with<T>(pushedKey key: CodingKey, _ work: () throws -> T) rethrows -> T {
        self.codingPath.append(key)
        let ret: T = try work()
        self.codingPath.removeLast()
        return ret
    }

    /// Initializes `self` with the given top-level container and options.
    fileprivate init(referencing container: BsonValue?, at codingPath: [CodingKey] = [], options: BsonDecoder._Options) {
        self.storage = _BsonDecodingStorage()
        self.storage.push(container: container)
        self.codingPath = codingPath
        self.options = options
    }

    // Returns the data stored in this decoder as represented in a container keyed by the given key type.
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard self.storage.topContainer != nil  else {
            throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self,
                                  DecodingError.Context(codingPath: self.codingPath,
                                                        debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }

        guard let topContainer = self.storage.topContainer as? Document else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: Document.self, reality: self.storage.topContainer)
        }

        let container = _BsonKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }

    // Returns the data stored in this decoder as represented in a container appropriate for holding a single primitive value.
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }

    // Returns the data stored in this decoder as represented in a container appropriate for holding values with no keys.
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard self.storage.topContainer != nil else {
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                  DecodingError.Context(codingPath: self.codingPath,
                                                        debugDescription: "Cannot get unkeyed decoding container -- found null value instead."))
        }

        guard let arr = self.storage.topContainer as? [BsonValue?] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [BsonValue?].self, reality: self.storage.topContainer)
        }

        return _BsonUnkeyedDecodingContainer(referencing: self, wrapping: arr)
    }
}

// Storage for a _BsonDecoder.
private struct _BsonDecodingStorage {

    /// The container stack, consisting of `BsonValue?`s. 
    private(set) fileprivate var containers: [BsonValue?] = []

    /// Initializes `self` with no containers.
    fileprivate init() {}

    /// The count of containers stored.
    fileprivate var count: Int { return self.containers.count }

    /// The container at the top of the stack.
    fileprivate var topContainer: BsonValue? {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.last!
    }

    /// Adds a new container to the stack.
    fileprivate mutating func push(container: BsonValue?) {
        self.containers.append(container)
    }

    /// Pops the top container from the stack. 
    fileprivate mutating func popContainer() {
        precondition(self.containers.count > 0, "Empty container stack.")
        self.containers.removeLast()
    }
}

/// Just a temporary error to make code compile until we implement everything.
struct UnimplementedError: LocalizedError {
    public var errorDescription: String? { return "Unimplemented" }
}

/// A protocol for types that are not BSON types but require decoding support. 
private protocol NonBsonValue {
    init(from: BsonValue) throws
}

extension Int8: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension Int16: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt8: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt16: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt32: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt64: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension UInt: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

extension Float: NonBsonValue {
    init(from: BsonValue) throws {
        throw UnimplementedError()
    }
}

/// Extend _BsonDecoder to add methods for "unboxing" values as various types.
extension _BsonDecoder {

    fileprivate func unboxBsonValue<T: BsonValue>(_ value: BsonValue?, as type: T.Type) throws -> T? {
        guard let typed = value as? T else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        return typed
    }

    fileprivate func unboxNonBsonValue<T: NonBsonValue>(_ value: BsonValue?, as type: T.Type) throws -> T? {
        guard let unwrapped = value else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        return try T(from: unwrapped)
    }

    fileprivate func unbox<T: Decodable>(_ value: BsonValue?, as type: T.Type) throws -> T? {
        self.storage.push(container: value)
        defer { self.storage.popContainer() }
        return try T(from: self)
    }
}

/// A keyed decoding container, backed by a `Document`.
private struct _BsonKeyedDecodingContainer<K: CodingKey> : KeyedDecodingContainerProtocol {
    typealias Key = K

    /// A reference to the decoder we're reading from.
    private let decoder: _BsonDecoder

    /// A reference to the container we're reading from.
    private let container: Document

    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]

    /// Initializes `self`, referencing the given decoder and container.
    fileprivate init(referencing decoder: _BsonDecoder, wrapping container: Document) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
    }

    /// All the keys the decoder has for this container.
    public var allKeys: [Key] {
        return self.container.keys.compactMap { Key(stringValue: $0) }
    }

    /// Returns a Boolean value indicating whether the decoder contains a value associated with the given key.
    public func contains(_ key: Key) -> Bool {
        return self.container.keys.contains(key.stringValue)
    }

    /// A string description of a CodingKey, for use in error messages.
    private func _errorDescription(of key: CodingKey) -> String {
        return "\(key) (\"\(key.stringValue)\")"
    }

    /// Private helper function to check for a value in self.container. Returns the value stored
    /// under `key`, or throws an error if the value is not found.
    private func getValue(forKey key: Key) throws -> BsonValue {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(_errorDescription(of: key))."))
        }
        return entry
    }

    /// Decode a BsonValue type from this container for the given key.
    private func decodeBsonType<T: BsonValue>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            guard let value = try decoder.unboxBsonValue(entry, as: type) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
            }
            return value
        }
    }

    /// Decodes a NonBsonValue type from this container for the given key.
    private func decodeNonBsonType<T: NonBsonValue>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            guard let value = try decoder.unboxNonBsonValue(entry, as: type) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
            }
            return value
        }
    }

    /// Decodes a Decodable type from this container for the given key.
    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            guard let value = try decoder.unbox(entry, as: type) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
            }
            return value
        }
    }

    /// Decodes a null value for the given key.
    public func decodeNil(forKey key: Key) throws -> Bool {
        // check if the key exists in the document, so we can differentiate between
        // the key being set to nil and the key not existing at all.
        if !self.contains(key) {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Key \(_errorDescription(of: key)) not found."))
        }
        return self.container[key.stringValue] == nil
    }

    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { return try decodeBsonType(type, forKey: key) }
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int { return try decodeBsonType(type, forKey: key) }
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { return try decodeBsonType(type, forKey: key) }
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { return try decodeBsonType(type, forKey: key) }
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float { return try decodeNonBsonType(type, forKey: key) }
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return try decodeBsonType(type, forKey: key) }
    public func decode(_ type: String.Type, forKey key: Key) throws -> String { return try decodeBsonType(type, forKey: key) }

    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return try self.decoder.with(pushedKey: key) {
            let value = try getValue(forKey: key)

            guard let doc = value as? Document else {
                throw DecodingError._typeMismatch(at: self.codingPath, expectation: Document.self, reality: value)
            }

            let container = _BsonKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: doc)
            return KeyedDecodingContainer(container)
        }
    }

    /// Returns the data stored for the given key as represented in an unkeyed container.
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try self.decoder.with(pushedKey: key) {
            let value = try getValue(forKey: key)

            guard let array = value as? [BsonValue?] else {
                throw DecodingError._typeMismatch(at: self.codingPath, expectation: [BsonValue?].self, reality: value)
            }

            return _BsonUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
        }
    }

    /// Private method to create a superDecoder for the provided key.
    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        return self.decoder.with(pushedKey: key) {
            let value: BsonValue? = self.container[key.stringValue]
            return _BsonDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options)
        }
    }

    /// Returns a Decoder instance for decoding super from the container associated with the default super key.
    public func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: _BsonKey.super)
    }

    // Returns a Decoder instance for decoding super from the container associated with the given key.
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
}

private struct _BsonUnkeyedDecodingContainer: UnkeyedDecodingContainer {

    /// A reference to the decoder we're reading from.
    private let decoder: _BsonDecoder

    /// A reference to the container we're reading from.
    private let container: [BsonValue?]

    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]

    /// The index of the element we're about to decode.
    private(set) public var currentIndex: Int

    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _BsonDecoder, wrapping container: [BsonValue?]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
    }

    /// The number of elements contained within this container.
    public var count: Int? { return self.container.count }

    /// A Boolean value indicating whether there are no more elements left to be decoded in the container.
    public var isAtEnd: Bool { return self.currentIndex >= self.count! }

    /// A private helper function to check if we're at the end of the container, and if so throw an error. 
    private func checkAtEnd() throws {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(BsonValue?.self, DecodingError.Context(codingPath: self.decoder.codingPath + [_BsonKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
    }

    /// Decodes a BsonValue type from this container.
    private mutating func decodeBsonValue<T: BsonValue>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()

        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            guard let typed = try self.decoder.unboxBsonValue(self.container[currentIndex], as: type) else {
                throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: self.container[self.currentIndex])
            }
            self.currentIndex += 1
            return typed
        }
    }

    /// Decodes a NonBsonValue type from this container.
    private mutating func decodeNonBsonValue<T: NonBsonValue>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()

        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            guard let typed = try self.decoder.unboxNonBsonValue(self.container[currentIndex], as: type) else {
                throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: self.container[self.currentIndex])
            }
            self.currentIndex += 1
            return typed
        }
    }

    /// Decodes a Decodable type from this container.
    public mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()

        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[currentIndex], as: T.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_BsonKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            self.currentIndex += 1
            return decoded
        }
    }

    /// Decodes a null value from this container.
    public mutating func decodeNil() throws -> Bool {
        try self.checkAtEnd()

        if self.container[self.currentIndex] == nil {
            self.currentIndex += 1
            return true
        }
        return false
    }

    /// Decode all required types from this container using the helpers defined above.
    public mutating func decode(_ type: Bool.Type) throws -> Bool { return try self.decodeBsonValue(type) }
    public mutating func decode(_ type: Int.Type) throws -> Int { return try self.decodeBsonValue(type) }
    public mutating func decode(_ type: Int8.Type) throws -> Int8 { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: Int16.Type) throws -> Int16 { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: Int32.Type) throws -> Int32 { return try self.decodeBsonValue(type) }
    public mutating func decode(_ type: Int64.Type) throws -> Int64 { return try self.decodeBsonValue(type) }
    public mutating func decode(_ type: UInt.Type) throws -> UInt { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: Float.Type) throws -> Float { return try self.decodeNonBsonValue(type) }
    public mutating func decode(_ type: Double.Type) throws -> Double { return try self.decodeBsonValue(type) }
    public mutating func decode(_ type: String.Type) throws -> String { return try self.decodeBsonValue(type) }

    /// Decodes a nested container keyed by the given type.
    public mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let doc = try self.decodeBsonValue(Document.self)
            self.currentIndex += 1
            let container = _BsonKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: doc)
            return KeyedDecodingContainer(container)
        }
    }

    /// Decodes an unkeyed nested container.
    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let array = try self.decodeBsonValue([BsonValue].self)
            self.currentIndex += 1
            return _BsonUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
        }
    }

    /// Decodes a nested container and returns a Decoder instance for decoding super from that container.
    public mutating func superDecoder() throws -> Decoder {
        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let value = self.container[self.currentIndex]
            self.currentIndex += 1
            return _BsonDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options)
        }
    }
}

extension _BsonDecoder: SingleValueDecodingContainer {

    /// Assert that the top container for this decoder is non-null.
    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected \(type) but found null value instead."))
        }
    }

    /// Decode a BsonValue type from this container.
    private func decodeBsonValue<T: BsonValue>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unboxBsonValue(self.storage.topContainer, as: T.self)!
    }

    /// Decode a NonBsonValue type from this container.
    private func decodeNonBsonValue<T: NonBsonValue>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unboxNonBsonValue(self.storage.topContainer, as: T.self)!
    }

    /// Decode a Decodable type from this container.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unbox(self.storage.topContainer, as: T.self)!
    }

    /// Decode a null value from this container.
    public func decodeNil() -> Bool { return self.storage.topContainer == nil }

    /// Decode all the required types from this container using the helpers defined above.
    public func decode(_ type: Bool.Type) throws -> Bool { return try decodeBsonValue(type) }
    public func decode(_ type: Int.Type) throws -> Int { return try decodeBsonValue(type) }
    public func decode(_ type: Int8.Type) throws -> Int8 { return try decodeNonBsonValue(type) }
    public func decode(_ type: Int16.Type) throws -> Int16 { return try decodeNonBsonValue(type) }
    public func decode(_ type: Int32.Type) throws -> Int32 { return try decodeBsonValue(type) }
    public func decode(_ type: Int64.Type) throws -> Int64 { return try decodeBsonValue(type) }
    public func decode(_ type: UInt.Type) throws -> UInt { return try decodeNonBsonValue(type) }
    public func decode(_ type: UInt8.Type) throws -> UInt8 { return try decodeNonBsonValue(type) }
    public func decode(_ type: UInt16.Type) throws -> UInt16 { return try decodeNonBsonValue(type) }
    public func decode(_ type: UInt32.Type) throws -> UInt32 { return try decodeNonBsonValue(type) }
    public func decode(_ type: UInt64.Type) throws -> UInt64 { return try decodeNonBsonValue(type) }
    public func decode(_ type: Float.Type) throws -> Float { return try decodeNonBsonValue(type) }
    public func decode(_ type: Double.Type) throws -> Double { return try decodeBsonValue(type) }
    public func decode(_ type: String.Type) throws -> String { return try decodeBsonValue(type) }
}

private struct _BsonKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }

    fileprivate init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }

    fileprivate static let `super` = _BsonKey(stringValue: "super")!
}

private extension DecodingError {
    static func _typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: BsonValue?) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(type(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }
}
