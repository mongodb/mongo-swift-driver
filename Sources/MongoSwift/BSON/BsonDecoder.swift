import Foundation

/// `BsonDecoder` facilitates the decoding of BSON into semantic `Decodable` types.
public class BsonDecoder {

    /// Contextual user-provided information for use during decoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

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

    /// Decodes a top-level value of the given type from the given BSON document.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter document: The BSON document to decode from.
    /// - returns: A value of the requested type.
    /// - throws: An error if any value throws an error during decoding.
    public func decode<T: Decodable>(_ type: T.Type, from document: Document) throws -> T {
        /// if the requested type is `Document` we're done
        if let doc = document as? T { return doc }
        let _decoder = _BsonDecoder(referencing: document, options: self.options)
        return try type.init(from: _decoder)
    }

    /// Decodes a top-level value of the given type from the given BSON data.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The BSON data to decode from.
    /// - returns: A value of the requested type.
    /// - throws: An error if the BSON data is corrupt, or if any value throws an error during decoding.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        return try self.decode(type, from: Document(fromBSON: data))
    }

    /// Decodes a top-level value of the given type from the given JSON/extended JSON string.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter json: The JSON string to decode from.
    /// - returns: A value of the requested type.
    /// - throws: An error if the JSON data is corrupt, or if any value throws an error during decoding.
    public func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        // we nest the input JSON in another object, and then decode to a `DecodableWrapper`
        // wrapping an object of the requested type. since our decoder only supports decoding
        // objects, this allows us to additionally handle decoding to primitive types like a
        // `String` or an `Int`.
        // while this is not needed to decode JSON representing objects, it is difficult to
        // determine when JSON represents an object vs. a primitive value -- for example,
        // {"$numberInt": "42"} is a JSON object and looks like an object type but is actually
        // a primitive type, Int32. so for simplicity, we just always assume wrapping is needed,
        // and pay a small performance penalty of decoding a few extra bytes.
        let wrapped = "{\"value\": \(json)}"

        if let doc = try? Document(fromJSON: wrapped) {
            let s = try self.decode(DecodableWrapper<T>.self, from: doc)
            return s.value
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [],
                                  debugDescription: "Unable to parse JSON string \(json)"))
    }

    /// A struct to wrap a `Decodable` type, allowing us to support decoding to types that
    /// are not inside a wrapping object (for ex., Int or String).
    private struct DecodableWrapper<T: Decodable>: Decodable {
        let value: T
    }
}

/// :nodoc: An internal class to actually implement the `Decoder` protocol.
internal class _BsonDecoder: Decoder {

    /// The decoder's storage.
    internal var storage: _BsonDecodingStorage

    /// Options set on the top-level decoder.
    fileprivate let options: BsonDecoder._Options

    /// The path to the current point in decoding.
    public fileprivate(set) var codingPath: [CodingKey]

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
    fileprivate init(referencing container: BsonValue?, at codingPath: [CodingKey] = [],
                     options: BsonDecoder._Options) {
        self.storage = _BsonDecodingStorage()
        self.storage.push(container: container)
        self.codingPath = codingPath
        self.options = options
    }

    // Returns the data stored in this decoder as represented in a container keyed by the given key type.
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard self.storage.topContainer != nil  else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<Key>.self,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription:
                                      "Cannot get keyed decoding container -- found null value instead."))
        }

        guard let topContainer = self.storage.topContainer as? Document else {
            throw DecodingError._typeMismatch(at: self.codingPath,
                                              expectation: Document.self,
                                              reality: self.storage.topContainer)
        }

        let container = _BsonKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }

    // Returns the data stored in this decoder in a container appropriate for holding a single primitive value.
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }

    // Returns the data stored in this decoder in a container appropriate for holding values with no keys.
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard self.storage.topContainer != nil else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription:
                                      "Cannot get unkeyed decoding container -- found null value instead."))
        }

        guard let arr = self.storage.topContainer as? [BsonValue?] else {
            throw DecodingError._typeMismatch(at: self.codingPath,
                                              expectation: [BsonValue?].self,
                                              reality: self.storage.topContainer)
        }

        return _BsonUnkeyedDecodingContainer(referencing: self, wrapping: arr)
    }
}

// Storage for a _BsonDecoder.
internal struct _BsonDecodingStorage {

    /// The container stack, consisting of `BsonValue?`s. 
    fileprivate private(set) var containers: [BsonValue?] = []

    /// Initializes `self` with no containers.
    fileprivate init() {}

    /// The count of containers stored.
    fileprivate var count: Int { return self.containers.count }

    /// The container at the top of the stack.
    internal var topContainer: BsonValue? {
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

/// Extend _BsonDecoder to add methods for "unboxing" values as various types.
extension _BsonDecoder {

    fileprivate func unboxBsonValue<T: BsonValue>(_ value: BsonValue?, as type: T.Type) throws -> T? {
        guard let typed = value as? T else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        return typed
    }

    fileprivate func unboxNumber<T: CodableNumber>(_ value: BsonValue?, as type: T.Type) throws -> T? {
        guard let unwrapped = value else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }

        guard let primitive = T(from: unwrapped) else {
            throw DecodingError._numberMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        return primitive
    }

    fileprivate func unbox<T: Decodable>(_ value: BsonValue?, as type: T.Type) throws -> T? {
        // if the data is already stored as the correct type in the document, then we can short-circuit
        // and just return the typed value here
        if let val = value as? T { return val }

        // `Date`'s decode method looks for a `Double`. however, this is not how *we* want to look for it
        // given that its encoded as an Int64 in BSON. therefore, if the value wasn't extracted from 
        // the `Document` as type `Date` but we're trying to decode as a `Date`, we should throw an error
        // rather than calling `Date.init(from decoder: Decoder)`. 
        if type == Date.self {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }

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
    fileprivate let container: Document

    /// The path of coding keys taken to get to this point in decoding.
    public private(set) var codingPath: [CodingKey]

    /// Initializes `self`, referencing the given decoder and container.
    fileprivate init(referencing decoder: _BsonDecoder, wrapping container: Document) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
    }

    /// All the keys the decoder has for this container.
    public var allKeys: [Key] {
        #if swift(>=4.1)
        return self.container.keys.compactMap { Key(stringValue: $0) }
        #else
        return self.container.keys.flatMap { Key(stringValue: $0) }
        #endif

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
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: self.decoder.codingPath,
                                      debugDescription: "No value associated with key \(_errorDescription(of: key))."))
        }
        return entry
    }

    /// Decode a BsonValue type from this container for the given key.
    private func decodeBsonType<T: BsonValue>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            guard let value = try decoder.unboxBsonValue(entry, as: type) else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(codingPath: self.decoder.codingPath,
                                          debugDescription: "Expected \(type) value but found null instead."))
            }
            return value
        }
    }

    /// Decodes a CodableNumber type from this container for the given key.
    private func decodeNumber<T: CodableNumber>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            guard let value = try decoder.unboxNumber(entry, as: type) else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(codingPath: self.decoder.codingPath,
                                          debugDescription: "Expected \(type) value but found null instead."))
            }
            return value
        }
    }

    /// Decodes a Decodable type from this container for the given key.
    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            guard let value = try decoder.unbox(entry, as: type) else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(codingPath: self.decoder.codingPath,
                                          debugDescription: "Expected \(type) value but found null instead."))
            }
            return value
        }
    }

    /// Decodes a null value for the given key.
    public func decodeNil(forKey key: Key) throws -> Bool {
        // check if the key exists in the document, so we can differentiate between
        // the key being set to nil and the key not existing at all.
        if !self.contains(key) {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: self.decoder.codingPath,
                                      debugDescription: "Key \(_errorDescription(of: key)) not found."))
        }
        return self.container[key.stringValue] == nil
    }

    // swiftlint:disable line_length
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { return try decodeBsonType(type, forKey: key) }
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return try decodeNumber(type, forKey: key) }
    public func decode(_ type: String.Type, forKey key: Key) throws -> String { return try decodeBsonType(type, forKey: key) }
    // swiftlint:enable line_length

    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type,
                                           forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
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
    public private(set) var codingPath: [CodingKey]

    /// The index of the element we're about to decode.
    public private(set) var currentIndex: Int

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
            throw DecodingError.valueNotFound(
                BsonValue?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_BsonKey(index: self.currentIndex)],
                                      debugDescription: "Unkeyed container is at end."))
        }
    }

    /// Decodes a BsonValue type from this container.
    private mutating func decodeBsonType<T: BsonValue>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()
        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            guard let typed = try self.decoder.unboxBsonValue(self.container[currentIndex], as: type) else {
                throw DecodingError._typeMismatch(at: self.codingPath,
                                                  expectation: type,
                                                  reality: self.container[self.currentIndex])
            }
            self.currentIndex += 1
            return typed
        }
    }

    /// Decodes a CodableNumber type from this container.
    private mutating func decodeNumber<T: CodableNumber>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()
        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            guard let typed = try self.decoder.unboxNumber(self.container[currentIndex], as: type) else {
                throw DecodingError._typeMismatch(at: self.codingPath,
                                                  expectation: type,
                                                  reality: self.container[self.currentIndex])
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
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(
                        codingPath: self.decoder.codingPath + [_BsonKey(index: self.currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."))
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
    public mutating func decode(_ type: Bool.Type) throws -> Bool { return try self.decodeBsonType(type) }
    public mutating func decode(_ type: Int.Type) throws -> Int { return try self.decodeNumber(type) }
    public mutating func decode(_ type: Int8.Type) throws -> Int8 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: Int16.Type) throws -> Int16 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: Int32.Type) throws -> Int32 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: Int64.Type) throws -> Int64 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt.Type) throws -> UInt { return try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 { return try self.decodeNumber(type) }
    public mutating func decode(_ type: Float.Type) throws -> Float { return try self.decodeNumber(type) }
    public mutating func decode(_ type: Double.Type) throws -> Double { return try self.decodeNumber(type) }
    public mutating func decode(_ type: String.Type) throws -> String { return try self.decodeBsonType(type) }

    /// Decodes a nested container keyed by the given type.
    public mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type)
        throws -> KeyedDecodingContainer<NestedKey> {
        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let doc = try self.decodeBsonType(Document.self)
            self.currentIndex += 1
            let container = _BsonKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: doc)
            return KeyedDecodingContainer(container)
        }
    }

    /// Decodes an unkeyed nested container.
    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try self.decoder.with(pushedKey: _BsonKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let array = try self.decodeBsonType([BsonValue].self)
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

/// :nodoc:
extension _BsonDecoder: SingleValueDecodingContainer {

    /// Assert that the top container for this decoder is non-null.
    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription: "Expected \(type) but found null value instead."))
        }
    }

    /// Decode a BsonValue type from this container.
    private func decodeBsonType<T: BsonValue>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unboxBsonValue(self.storage.topContainer, as: T.self)!
    }

    /// Decode a CodableNumber type from this container.
    private func decodeNumber<T: CodableNumber>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unboxNumber(self.storage.topContainer, as: T.self)!
    }

    /// Decode a Decodable type from this container.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unbox(self.storage.topContainer, as: T.self)!
    }

    /// Decode a null value from this container.
    public func decodeNil() -> Bool { return self.storage.topContainer == nil }

    /// Decode all the required types from this container using the helpers defined above.
    public func decode(_ type: Bool.Type) throws -> Bool { return try decodeBsonType(type) }
    public func decode(_ type: Int.Type) throws -> Int { return try decodeNumber(type) }
    public func decode(_ type: Int8.Type) throws -> Int8 { return try decodeNumber(type) }
    public func decode(_ type: Int16.Type) throws -> Int16 { return try decodeNumber(type) }
    public func decode(_ type: Int32.Type) throws -> Int32 { return try decodeNumber(type) }
    public func decode(_ type: Int64.Type) throws -> Int64 { return try decodeNumber(type) }
    public func decode(_ type: UInt.Type) throws -> UInt { return try decodeNumber(type) }
    public func decode(_ type: UInt8.Type) throws -> UInt8 { return try decodeNumber(type) }
    public func decode(_ type: UInt16.Type) throws -> UInt16 { return try decodeNumber(type) }
    public func decode(_ type: UInt32.Type) throws -> UInt32 { return try decodeNumber(type) }
    public func decode(_ type: UInt64.Type) throws -> UInt64 { return try decodeNumber(type) }
    public func decode(_ type: Float.Type) throws -> Float { return try decodeNumber(type) }
    public func decode(_ type: Double.Type) throws -> Double { return try decodeNumber(type) }
    public func decode(_ type: String.Type) throws -> String { return try decodeBsonType(type) }
}

internal struct _BsonKey: CodingKey {
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

    internal init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }

    internal static let `super` = _BsonKey(stringValue: "super")!
}

internal extension DecodingError {
    static func _typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: BsonValue?) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(type(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }

    static func _numberMismatch(at path: [CodingKey], expectation: Any.Type, reality: BsonValue?) -> DecodingError {
        let description = "Expected to find a value that can be represented as a \(expectation), " +
                         "but found value \(String(describing: reality)) of type \(type(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }
}
