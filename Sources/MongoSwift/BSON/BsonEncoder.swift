import Foundation
import libmongoc

/// `BsonEncoder` facilitates the encoding of `Encodable` values into BSON.
public class BsonEncoder {

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        return _Options(userInfo: userInfo)
    }

    /// Initializes `self`.
    public init() {}

    /// Encodes the given top-level value and returns its BSON representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Document` containing the encoded BSON data.
    /// - throws: An error if any value throws an error during encoding.
    public func encode<T: Encodable>(_ value: T) throws -> Document {
        // if the value being encoded is already a `Document` we're done
        switch value {
        case let doc as Document:
            return doc
        case let abv as AnyBsonValue:
            if let doc = abv.value as? Document { return doc }
        default:
            break
        }

        let encoder = _BsonEncoder(options: self.options)

        guard let topLevel = try encoder.box(value) else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [],
                                      debugDescription: "Top-level \(T.self) did not encode any values."))
        }

        guard let dict = topLevel as? MutableDictionary else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [],
                                      debugDescription: "Top-level \(T.self) was not encoded as a complete document."))
        }

        return dict.asDocument()
    }

    /// Encodes the given top-level optional value and returns its BSON representation. Returns nil if the
    /// value is nil or if it contains no data.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Document` containing the encoded BSON data, or nil if there is no data to encode.
    /// - throws: An error if any value throws an error during encoding.
    public func encode<T: Encodable>(_ value: T?) throws -> Document? {
        guard let value = value else { return nil }
        let encoded = try self.encode(value)
        if encoded == [:] { return nil }
        return encoded
    }

    /// Encodes the given array of top-level values and returns an array of their BSON representations.
    ///
    /// - parameter values: The values to encode.
    /// - returns: A new `[Document]` containing the encoded BSON data.
    /// - throws: An error if any value throws an error during encoding.
    public func encode<T: Encodable>(_ values: [T]) throws -> [Document] {
        return try values.map { try self.encode($0) }
    }

    /// Encodes the given array of top-level optional values and returns an array of their BSON representations. 
    /// Any value that is nil or contains no data will be mapped to nil.
    ///
    /// - parameter values: The values to encode.
    /// - returns: A new `[Document?]` containing the encoded BSON data. Any value that is nil or 
    ///            contains no data will be mapped to nil.
    /// - throws: An error if any value throws an error during encoding.
    public func encode<T: Encodable>(_ values: [T?]) throws -> [Document?] {
        return try values.map { try self.encode($0) }
    }
}

/// :nodoc: An internal class to implement the `Encoder` protocol.
internal class _BsonEncoder: Encoder {

    /// The encoder's storage.
    internal var storage: _BsonEncodingStorage

    /// Options set on the top-level encoder.
    fileprivate let options: BsonEncoder._Options

    /// The path to the current point in encoding.
    public var codingPath: [CodingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        return self.options.userInfo
    }

    /// Initializes `self` with the given top-level encoder options.
    fileprivate init(options: BsonEncoder._Options, codingPath: [CodingKey] = []) {
        self.options = options
        self.storage = _BsonEncodingStorage()
        self.codingPath = codingPath
    }

    /// Returns whether a new element can be encoded at this coding path.
    ///
    /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
    fileprivate var canEncodeNewValue: Bool {
        return self.storage.count == self.codingPath.count
    }

    public func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        // If an existing keyed container was already requested, return that one.
        let topContainer: MutableDictionary
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? MutableDictionary else {
                preconditionFailure(
                    "Attempt to push new keyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }
        let container = _BsonKeyedEncodingContainer<Key>(
            referencing: self, codingPath: self.codingPath, wrapping: topContainer)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: MutableArray
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? MutableArray else {
                preconditionFailure(
                    "Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }

        return _BsonUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

internal struct _BsonEncodingStorage {

    /// The container stack.
    /// Elements may be any BsonValue type.
    internal var containers: [BsonValue?] = []

    /// Initializes `self` with no containers.
    fileprivate init() {}

    fileprivate var count: Int {
        return self.containers.count
    }

    fileprivate mutating func pushKeyedContainer() -> MutableDictionary {
        let dictionary = MutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> MutableArray {
        let array = MutableArray()
        self.containers.append(array)
        return array
    }

    fileprivate mutating func push(container: BsonValue?) {
        self.containers.append(container)
    }

    fileprivate mutating func popContainer() -> BsonValue? {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.popLast()!
    }
}

/// _BsonReferencingEncoder is a special subclass of _BsonEncoder which has its own storage, but references the 
/// contents of a different encoder. It's used in superEncoder(), which returns a new encoder for encoding a 
/// superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't 
// necessarily know when it's done being used (to write to the original container).
private class _BsonReferencingEncoder: _BsonEncoder {

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(MutableArray, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(MutableDictionary, String)
    }

    /// The encoder we're referencing.
    fileprivate let encoder: _BsonEncoder

    /// The container reference itself.
    private let reference: Reference

    fileprivate init(referencing encoder: _BsonEncoder, at index: Int, wrapping array: MutableArray) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        self.codingPath.append(_BsonKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    fileprivate init(referencing encoder: _BsonEncoder, key: CodingKey, wrapping dictionary: MutableDictionary) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, key.stringValue)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        self.codingPath.append(key)
    }

    override fileprivate var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
    }

    /// Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let value: BsonValue?
        switch self.storage.count {
        case 0: value = nil
        case 1: value = self.storage.popContainer()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case .array(let array, let index):
            array.insert(value, at: index)

        case .dictionary(let dictionary, let key):
            dictionary[key] = value
        }
    }

}

/// Extend _BsonEncoder to add methods for "boxing" values.
extension _BsonEncoder {

    /// Converts a `CodableNumber` to a `BsonValue` type. Throws if `value` cannot be 
    /// exactly represented by an `Int`, `Int32`, `Int64`, or `Double`. 
    fileprivate func boxNumber<T: CodableNumber>(_ value: T) throws -> BsonValue {
        guard let number = value.bsonValue else {
            throw EncodingError._numberError(at: self.codingPath, value: value)
        }
        return number
    }

    fileprivate func box<T: Encodable>(_ value: T) throws -> BsonValue? {
        // if it's already a BsonValue, just return it, unless if it is an 
        // array. technically [Any] is a BsonValue, but we can only use this
        // short-circuiting if all the elements are actually BsonValues.
        if let bsonValue = value as? BsonValue, !(bsonValue is [Any]) {
            return bsonValue
        } else if let bsonArray = value as? [BsonValue?] {
            return bsonArray
        }

        // The value should request a container from the _BsonEncoder.
        let depth = self.storage.count
        do {
            try value.encode(to: self)
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if self.storage.count > depth { _ = self.storage.popContainer() }
            throw error
        }

        // The top container should be a new container.
        guard self.storage.count > depth else { return nil }
        return self.storage.popContainer()
    }
}

private struct _BsonKeyedEncodingContainer<K: CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K

    /// A reference to the encoder we're writing to.
    private let encoder: _BsonEncoder

    /// A reference to the container we're writing to.
    private let container: MutableDictionary

    /// The path of coding keys taken to get to this point in encoding.
    public private(set) var codingPath: [CodingKey]

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: _BsonEncoder, codingPath: [CodingKey],
                     wrapping container: MutableDictionary) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }

    public mutating func encodeNil(forKey key: Key) throws { self.container[key.stringValue] = nil }
    public mutating func encode(_ value: Bool, forKey key: Key) throws { self.container[key.stringValue] = value }
    public mutating func encode(_ value: Int, forKey key: Key) throws { self.container[key.stringValue] = value }
    public mutating func encode(_ value: Int8, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: Int16, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: Int32, forKey key: Key) throws { self.container[key.stringValue] = value }
    public mutating func encode(_ value: Int64, forKey key: Key) throws { self.container[key.stringValue] = value }
    public mutating func encode(_ value: UInt, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: UInt8, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: UInt16, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: UInt32, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: UInt64, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: String, forKey key: Key) throws { self.container[key.stringValue] = value }
    public mutating func encode(_ value: Float, forKey key: Key) throws { try self.encodeNumber(value, forKey: key) }
    public mutating func encode(_ value: Double, forKey key: Key) throws { self.container[key.stringValue] = value }

    private mutating func encodeNumber<T: CodableNumber>(_ value: T, forKey key: Key) throws {
        // put the key on the codingPath in case the attempt to convert the number fails and we throw
        self.encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        self.container[key.stringValue] = try encoder.boxNumber(value)
    }

    public mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        self.encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        self.container[key.stringValue] = try encoder.box(value)
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type,
                                                    forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let dictionary = MutableDictionary()
        self.container[key.stringValue] = dictionary

        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }

        let container = _BsonKeyedEncodingContainer<NestedKey>(
            referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let array = MutableArray()
        self.container[key.stringValue] = array

        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }

        return _BsonUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }

    public mutating func superEncoder() -> Encoder {
        return _BsonReferencingEncoder(referencing: self.encoder, key: _BsonKey.super, wrapping: self.container)

    }

    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return _BsonReferencingEncoder(referencing: self.encoder, key: key, wrapping: self.container)
    }
}

private struct _BsonUnkeyedEncodingContainer: UnkeyedEncodingContainer {

    /// A reference to the encoder we're writing to.
    private let encoder: _BsonEncoder

    /// A reference to the container we're writing to.
    private let container: MutableArray

    /// The path of coding keys taken to get to this point in encoding.
    public private(set) var codingPath: [CodingKey]

    /// The number of elements encoded into the container.
    public var count: Int {
        return self.container.count
    }

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: _BsonEncoder, codingPath: [CodingKey], wrapping container: MutableArray) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }

    public mutating func encodeNil() throws { self.container.add(nil) }
    public mutating func encode(_ value: Bool) throws { self.container.add(value) }
    public mutating func encode(_ value: Int) throws { self.container.add(value) }
    public mutating func encode(_ value: Int8) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: Int16) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: Int32) throws { self.container.add(value) }
    public mutating func encode(_ value: Int64) throws { self.container.add(value) }
    public mutating func encode(_ value: UInt) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: UInt8) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: UInt16) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: UInt32) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: UInt64) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: String) throws { self.container.add(value) }
    public mutating func encode(_ value: Float) throws { try self.encodeNumber(value) }
    public mutating func encode(_ value: Double) throws { self.container.add(value) }

    private mutating func encodeNumber<T: CodableNumber>(_ value: T) throws {
        self.encoder.codingPath.append(_BsonKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }

        self.container.add(try encoder.boxNumber(value))
    }

    public mutating func encode<T: Encodable>(_ value: T) throws {
        self.encoder.codingPath.append(_BsonKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }

        self.container.add(try encoder.box(value))
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
        -> KeyedEncodingContainer<NestedKey> {
        self.codingPath.append(_BsonKey(index: self.count))
        defer { self.codingPath.removeLast() }

        let dictionary = MutableDictionary()
        self.container.add(dictionary)

        let container = _BsonKeyedEncodingContainer<NestedKey>(
            referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self.codingPath.append(_BsonKey(index: self.count))
        defer { self.codingPath.removeLast() }

        let array = MutableArray()
        self.container.add(array)
        return _BsonUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }

    public mutating func superEncoder() -> Encoder {
         return _BsonReferencingEncoder(referencing: self.encoder, at: self.container.count, wrapping: self.container)
    }
}

/// :nodoc:
extension _BsonEncoder: SingleValueEncodingContainer {

    private func assertCanEncodeNewValue() {
        precondition(self.canEncodeNewValue,
                     "Attempt to encode value through single value container when previously value already encoded.")
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.storage.push(container: nil)
    }

    public func encode(_ value: Bool) throws { try self.encodeBsonType(value) }
    public func encode(_ value: Int) throws { try self.encodeBsonType(value) }
    public func encode(_ value: Int8) throws { try self.encodeNumber(value) }
    public func encode(_ value: Int16) throws { try self.encodeNumber(value) }
    public func encode(_ value: Int32) throws { try self.encodeBsonType(value) }
    public func encode(_ value: Int64) throws { try self.encodeBsonType(value) }
    public func encode(_ value: UInt) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt8) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt16) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt32) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt64) throws { try self.encodeNumber(value) }
    public func encode(_ value: String) throws { try self.encodeBsonType(value) }
    public func encode(_ value: Float) throws { try self.encodeNumber(value) }
    public func encode(_ value: Double) throws { try self.encodeBsonType(value) }

    private func encodeNumber<T: CodableNumber>(_ value: T) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: try self.boxNumber(value))
    }

    private func encodeBsonType<T: BsonValue>(_ value: T) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: value)
    }

    public func encode<T: Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: try self.box(value))
    }
}

/// A private class wrapping a Swift array so we can pass it by reference for 
/// encoder storage purposes. We use this rather than NSMutableArray because
/// it allows us to preserve Swift type information. 
private class MutableArray: BsonValue {

    var bsonType: BsonType { return .array }

    var array = [BsonValue?]()

    fileprivate func add(_ value: BsonValue?) {
        array.append(value)
    }

    var count: Int { return array.count }

    func insert(_ value: BsonValue?, at index: Int) {
        self.array.insert(value, at: index)
    }

    func encode(to storage: DocumentStorage, forKey key: String) throws {
        try self.array.encode(to: storage, forKey: key)
    }

    init() {}

    /// methods required by the BsonValue protocol that we don't actually need/use. MutableArray
    /// is just a BsonValue to simplify usage alongside true BsonValues within the encoder.
    required init(from iter: DocumentIterator) {
        fatalError("`MutableArray` is not meant to be initialized from a `DocumentIterator`")
    }
    func encode(to encoder: Encoder) throws {
        fatalError("`MutableArray` is not meant to be encoded with an `Encoder`")
    }
    required convenience init(from decoder: Decoder) throws {
        fatalError("`MutableArray` is not meant to be initialized from a `Decoder`")
    }
}

/// A private class wrapping a Swift dictionary so we can pass it by reference
/// for encoder storage purposes. We use this rather than NSMutableDictionary 
/// because it allows us to preserve Swift type information.
private class MutableDictionary: BsonValue {

    var bsonType: BsonType { return .document }

    // rather than using a dictionary, do this so we preserve key orders
    var keys = [String]()
    var values = [BsonValue?]()

    subscript(key: String) -> BsonValue? {
        get {
            guard let index = keys.index(of: key) else { return nil }
            return values[index]
        }
        set(newValue) {
            keys.append(key)
            values.append(newValue)
        }
    }

    /// Converts self to a `Document` with equivalent key-value pairs.
    func asDocument() -> Document {
        var doc = Document()
        for i in 0 ..< keys.count {
            doc[keys[i]] = values[i]
        }
        return doc
    }

    func encode(to storage: DocumentStorage, forKey key: String) throws {
        try self.asDocument().encode(to: storage, forKey: key)
    }

    init() {}

    /// methods required by the BsonValue protocol that we don't actually need/use. MutableDictionary
    /// is just a BsonValue to simplify usage alongside true BsonValues within the encoder.
    required init(from iter: DocumentIterator) {
        fatalError("`MutableDictionary` is not meant to be initialized from a `DocumentIterator`")
    }
    func encode(to encoder: Encoder) throws {
        fatalError("`MutableDictionary` is not meant to be encoded with an `Encoder`")
    }
    required convenience init(from decoder: Decoder) throws {
        fatalError("`MutableDictionary` is not meant to be initialized from a `Decoder`")
    }
}

private extension EncodingError {
    static func _numberError<T: CodableNumber>(at path: [CodingKey], value: T) -> EncodingError {
        let description = "Value \(String(describing: value)) of type \(type(of: value)) cannot be " +
                            "exactly represented by a BSON number type (Int, Int32, Int64 or Double)."
        return .invalidValue(value, Context(codingPath: path, debugDescription: description))
    }
}
