import Foundation
import mongoc

/// `BSONEncoder` facilitates the encoding of `Encodable` values into BSON.
public class PureBSONEncoder {
    /**
     * Enum representing the various strategies for encoding `Date`s.
     *
     * As per the BSON specification, the default strategy is to encode `Date`s as BSON datetime objects.
     *
     * - SeeAlso: bsonspec.org
     */
    public enum DateEnfcodingStrategy {
        /// Encode the `Date` by deferring to its default encoding implementation.
        case deferredToDate

        /// Encode the `Date` as a BSON datetime object (default).
        case bsonDateTime

        /// Encode the `Date` as a 64-bit integer counting the number of milliseconds since January 1, 1970.
        case millisecondsSince1970

        /// Encode the `Date` as a BSON double counting the number of seconds since January 1, 1970.
        case secondsSince1970

        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Encode the `Date` as a string formatted by the given formatter.
        case formatted(DateFormatter)

        /// Encode the `Date` by using the given closure.
        /// If the closure does not encode a value, an empty document will be encoded in its place.
        case custom((Date, Encoder) throws -> Void)
    }

    /**
     * Enum representing the various strategies for encoding `UUID`s.
     *
     * As per the BSON specification, the default strategy is to encode `UUID`s as BSON binary types with the UUID
     * subtype.
     *
     * - SeeAlso: bsonspec.org
     */
    public enum UUIDEnfcodingStrategy {
        /// Encode the `UUID` by deferring to its default encoding implementation.
        case deferredToUUID

        /// Encode the `UUID` as a BSON binary type (default).
        case binary
    }

    /**
     * Enum representing the various strategies for encoding `Data`s.
     *
     * As per the BSON specification, the default strategy is to encode `Data`s as BSON binary types with the generic
     * binary subtype.
     *
     * - SeeAlso: bsonspec.org
     */
    public enum DatafEncodingStrategy {
        /**
         * Encode the `Data` by deferring to its default encoding implementation.
         *
         * Note: The default encoding implementation attempts to encode the `Data` as a `[UInt8]`, but because BSON
         * does not support integer types besides `Int32` or `Int64`, it actually gets encoded to BSON as an `[Int32]`.
         * This results in a space inefficient storage of the `Data` (using 4 bytes of BSON storage per byte of data).
         */
        case deferredToData

        /// Encode the `Data` as a BSON binary type (default).
        case binary

        /// Encode the `Data` as a base64 encoded string.
        case base64

        /// Encode the `Data` by using the given closure.
        /// If the closure does not encode a value, an empty document will be encoded in its place.
        case custom((Data, Encoder) throws -> Void)
    }

    /// The strategy to use for encoding `Date`s with this instance.
    public var dateEncodingStrategy: BSONEncoder.DateEncodingStrategy = .bsonDateTime

    /// The strategy to use for encoding `UUID`s with this instance.
    public var uuidEncodingStrategy: BSONEncoder.UUIDEncodingStrategy = .binary

    /// The strategy to use for encoding `Data`s with this instance.
    public var dataEncodingStrategy: BSONEncoder.DataEncodingStrategy = .binary

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let userInfo: [CodingUserInfoKey: Any]
        let dateEncodingStrategy: BSONEncoder.DateEncodingStrategy
        let uuidEncodingStrategy: BSONEncoder.UUIDEncodingStrategy
        let dataEncodingStrategy: BSONEncoder.DataEncodingStrategy
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        return _Options(userInfo: self.userInfo,
                        dateEncodingStrategy: self.dateEncodingStrategy,
                        uuidEncodingStrategy: self.uuidEncodingStrategy,
                        dataEncodingStrategy: self.dataEncodingStrategy
                )
    }

    /// Initializes `self`.
    public init(options: CodingStrategyProvider? = nil) {
        self.configureWithOptions(options: options)
    }

    /// Initializes `self` by using the options of another `BSONEncoder` and the provided options, with preference
    /// going to the provided options in the case of conflicts.
    internal init(copies other: PureBSONEncoder, options: CodingStrategyProvider?) {
        self.userInfo = other.userInfo
        self.dateEncodingStrategy = other.dateEncodingStrategy
        self.uuidEncodingStrategy = other.uuidEncodingStrategy
        self.dataEncodingStrategy = other.dataEncodingStrategy

        self.configureWithOptions(options: options)
    }

    internal func configureWithOptions(options: CodingStrategyProvider?) {
        self.dateEncodingStrategy = options?.dateCodingStrategy?.rawValue.encoding ?? self.dateEncodingStrategy
        self.uuidEncodingStrategy = options?.uuidCodingStrategy?.rawValue.encoding ?? self.uuidEncodingStrategy
        self.dataEncodingStrategy = options?.dataCodingStrategy?.rawValue.encoding ?? self.dataEncodingStrategy
    }

    /**
     * Encodes the given top-level value and returns its BSON representation.
     *
     * - Parameter value: The value to encode.
     * - Returns: A new `PureBSONDocument` containing the encoded BSON data.
     * - Throws: `EncodingError` if any value throws an error during encoding.
     */
    public func encode<T: Encodable>(_ value: T) throws -> PureBSONDocument {
        // if the value being encoded is already a `Document` we're done
        switch value {
        case let doc as PureBSONDocument:
            return doc
        case let bson as BSON:
            if case let .document(doc) = bson {
                return doc
            }
        default:
            break
        }

        let encoder = _PureBSONEncoder(options: self.options)

        guard let boxedValue = try encoder.box_(value) else {
            throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(codingPath: [],
                                          debugDescription: "Top-level \(T.self) did not encode any values."))
        }

        guard let dict = boxedValue as? PureBSONMutableDictionary else {
            throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(codingPath: [],
                                          debugDescription: "Top-level \(T.self) was not encoded as a complete document."))
        }

        return dict.asDocument()
    }

    /**
     * Encodes the given top-level optional value and returns its BSON representation. Returns nil if the
     * value is nil or if it contains no data.
     *
     * - Parameter value: The value to encode.
     * - Returns: A new `Document` containing the encoded BSON data, or nil if there is no data to encode.
     * - Throws: `EncodingError` if any value throws an error during encoding.
     */
    public func encode<T: Encodable>(_ value: T?) throws -> PureBSONDocument? {
        guard let value = value else {
            return nil
        }
        let encoded = try self.encode(value)
        return encoded == [:] ? nil : encoded
    }

    /**
     * Encodes the given array of top-level values and returns an array of their BSON representations.
     *
     * - Parameter values: The values to encode.
     * - Returns: A new `[Document]` containing the encoded BSON data.
     * - Throws: `EncodingError` if any value throws an error during encoding.
     */
    public func encode<T: Encodable>(_ values: [T]) throws -> [PureBSONDocument] {
        return try values.map { try self.encode($0) }
    }

    /**
     * Encodes the given array of top-level optional values and returns an array of their BSON representations.
     * Any value that is nil or contains no data will be mapped to nil.
     *
     * - Parameter values: The values to encode.
     * - Returns: A new `[Document?]` containing the encoded BSON data. Any value that is nil or
     *            contains no data will be mapped to nil.
     * - Throws: `EncodingError` if any value throws an error during encoding.
     */
    public func encode<T: Encodable>(_ values: [T?]) throws -> [PureBSONDocument?] {
        return try values.map { try self.encode($0) }
    }
}

/// :nodoc: An internal class to implement the `Encoder` protocol.
internal class _PureBSONEncoder: Encoder {
    /// The encoder's storage.
    internal var storage: _PureBSONEncodingStorage

    /// Options set on the top-level encoder.
    fileprivate let options: PureBSONEncoder._Options

    /// The path to the current point in encoding.
    public var codingPath: [CodingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        return self.options.userInfo
    }

    /// Initializes `self` with the given top-level encoder options.
    fileprivate init(options: PureBSONEncoder._Options, codingPath: [CodingKey] = []) {
        self.options = options
        self.storage = _PureBSONEncodingStorage()
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
        let topContainer: PureBSONMutableDictionary
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? PureBSONMutableDictionary else {
                fatalError(
                    "Attempt to push new keyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }
        let container = _PureBSONKeyedEncodingContainer<Key>(
            referencing: self, codingPath: self.codingPath, wrapping: topContainer)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: PureBSONMutableArray
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? PureBSONMutableArray else {
                fatalError(
                    "Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }

        return _PureBSONUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

internal struct _PureBSONEncodingStorage {
    /// The container stack.
    /// Elements may be any `BSONValue` type.
    internal var containers: [PureBSONValue] = []

    /// Initializes `self` with no containers.
    fileprivate init() {}

    fileprivate var count: Int {
        return self.containers.count
    }

    fileprivate mutating func pushKeyedContainer() -> PureBSONMutableDictionary {
        let dictionary = PureBSONMutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> PureBSONMutableArray {
        let array = PureBSONMutableArray()
        self.containers.append(array)
        return array
    }

    fileprivate mutating func push(container: PureBSONValue) {
        self.containers.append(container)
    }

    fileprivate mutating func popContainer() -> PureBSONValue {
        guard !self.containers.isEmpty else {
            fatalError("Empty container stack.")
        }
        // swiftlint:disable:next force_unwrapping
        return self.containers.popLast()! // guaranteed safe because of precondition.
    }
}

/// `_BSONReferencingEncoder` is a special subclass of `_BSONEncoder` which has its own storage, but references the
/// contents of a different encoder. It's used in superEncoder(), which returns a new encoder for encoding a
/// superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't
// necessarily know when it's done being used (to write to the original container).
private class _PureBSONReferencingEncoder: _PureBSONEncoder {
    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(PureBSONMutableArray, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(PureBSONMutableDictionary, String)
    }

    /// The encoder we're referencing.
    fileprivate let encoder: _PureBSONEncoder

    /// The container reference itself.
    private let reference: Reference

    fileprivate init(referencing encoder: _PureBSONEncoder, at index: Int, wrapping array: PureBSONMutableArray) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        self.codingPath.append(_PureBSONKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    fileprivate init(referencing encoder: _PureBSONEncoder, key: CodingKey, wrapping dictionary: PureBSONMutableDictionary) {
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
        let value: PureBSONValue
        switch self.storage.count {
        case 0: value = PureBSONDocument()
        case 1: value = self.storage.popContainer()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case let .array(array, index):
            array.insert(value, at: index)

        case let .dictionary(dictionary, key):
            dictionary[key] = value
        }
    }
}

/// Extend `_BSONEncoder` to add methods for "boxing" values.
extension _PureBSONEncoder {
    /// Converts a `CodableNumber` to a `BSONValue` type. Throws if `value` cannot be
    /// exactly represented by an `Int`, `Int32`, `Int64`, or `Double`.
    fileprivate func boxNumber<T: PureCodableNumber>(_ value: T) throws -> PureBSONValue {
        // swiftlint:disable:next force_cast
        guard let number = value.pureBsonValue else {
            throw EncodingError._PurenumberError(at: self.codingPath, value: value)
        }
        return number
    }

    /// Returns the value as a `BSONValue` if possible. Otherwise, returns an empty `Document`.
    fileprivate func box<T: Encodable>(_ value: T) throws -> PureBSONValue {
        return try self.box_(value) ?? PureBSONDocument()
    }

    fileprivate func handleCustomStrategy<T: Encodable>(
            encodeFunc f: (T, Encoder) throws -> Void,
            forValue value: T
    ) throws -> PureBSONValue? {
        let depth = self.storage.count

        do {
            try f(value, self)
        } catch {
            if self.storage.count > depth {
                _ = self.storage.popContainer()
            }
            throw error
        }

        // The closure didn't encode anything.
        guard self.storage.count > depth else {
            return nil
        }

        return self.storage.popContainer()
    }

    /// Returns the date as a `BSONValue`, or nil if no values were encoded by the custom encoder strategy.
    fileprivate func boxDate(_ date: Date) throws -> PureBSONValue? {
        switch self.options.dateEncodingStrategy {
        case .bsonDateTime:
            return date
        case .deferredToDate:
            try date.encode(to: self)
            return self.storage.popContainer()
        case .millisecondsSince1970:
            return date.msSinceEpoch
        case .secondsSince1970:
            return date.timeIntervalSince1970
        case .formatted(let formatter):
            return formatter.string(from: date)
        case .iso8601:
            guard #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
            return PureBSONDecoder.iso8601Formatter.string(from: date)
        case .custom(let f):
            return try handleCustomStrategy(encodeFunc: f, forValue: date)
        }
    }

    /// Returns the uuid as a `BSONValue`.
    fileprivate func boxUUID(_ uuid: UUID) throws -> PureBSONValue {
        switch self.options.uuidEncodingStrategy {
        case .deferredToUUID:
            try uuid.encode(to: self)
            return self.storage.popContainer()
        case .binary:
            return try PureBSONBinary(from: uuid)
        }
    }

    fileprivate func boxData(_ data: Data) throws -> PureBSONValue? {
        switch self.options.dataEncodingStrategy {
        case .deferredToData:
            try data.encode(to: self)
            return self.storage.popContainer()
        case .binary:
            return try PureBSONBinary(data: data, subtype: .generic)
        case .base64:
            return data.base64EncodedString()
        case .custom(let f):
            return try handleCustomStrategy(encodeFunc: f, forValue: data)
        }
    }

    /// Returns the value as a `BSONValue` if possible. Otherwise, returns nil.
    fileprivate func box_<T: Encodable>(_ value: T) throws -> PureBSONValue? {
        switch value {
        case let date as Date:
            return try boxDate(date)
        case let uuid as UUID:
            return try boxUUID(uuid)
        case let data as Data:
            return try boxData(data)
        default:
            break
        }

        // if it's already a `BSONValue`, just return it, unless if it is an
        // array. technically `[Any]` is a `BSONValue`, but we can only use this
        // short-circuiting if all the elements are actually BSONValues.
        if let bsonValue = value as? PureBSONValue {
            return bsonValue
        } else if let bson = value as? BSON {
            return bson.bsonValue
        }

        if let bsonArray = value as? [PureBSONValue] {
            return bsonArray.map { $0.bson }
        }

        // The value should request a container from the _BSONEncoder.
        let depth = self.storage.count
        do {
            try value.encode(to: self)
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if self.storage.count > depth { _ = self.storage.popContainer() }
            throw error
        }

        // The top container should be a new container.
        guard self.storage.count > depth else {
            return nil
        }
        return self.storage.popContainer()
    }
}

private struct _PureBSONKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    /// A reference to the encoder we're writing to.
    private let encoder: _PureBSONEncoder

    /// A reference to the container we're writing to.
    private let container: PureBSONMutableDictionary

    /// The path of coding keys taken to get to this point in encoding.
    public private(set) var codingPath: [CodingKey]

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: _PureBSONEncoder,
                     codingPath: [CodingKey],
                     wrapping container: PureBSONMutableDictionary) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }

    public mutating func encodeNil(forKey key: Key) throws { self.container[key.stringValue] = PureBSONNull() }
    public mutating func encode(_ value: Bool, forKey key: Key) throws { self.container[key.stringValue] = value }
    public mutating func encode(_ value: Int, forKey key: Key) throws { self.container[key.stringValue] = Int64(value) }
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

    private mutating func encodeNumber<T: PureCodableNumber>(_ value: T, forKey key: Key) throws {
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
        let dictionary = PureBSONMutableDictionary()
        self.container[key.stringValue] = dictionary

        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }

        let container = _PureBSONKeyedEncodingContainer<NestedKey>(
            referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let array = PureBSONMutableArray()
        self.container[key.stringValue] = array

        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }

        return _PureBSONUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }

    public mutating func superEncoder() -> Encoder {
        return _PureBSONReferencingEncoder(referencing: self.encoder, key: _PureBSONKey.super, wrapping: self.container)
    }

    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return _PureBSONReferencingEncoder(referencing: self.encoder, key: key, wrapping: self.container)
    }
}

private struct _PureBSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    /// A reference to the encoder we're writing to.
    private let encoder: _PureBSONEncoder

    /// A reference to the container we're writing to.
    private let container: PureBSONMutableArray

    /// The path of coding keys taken to get to this point in encoding.
    public private(set) var codingPath: [CodingKey]

    /// The number of elements encoded into the container.
    public var count: Int {
        return self.container.count
    }

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: _PureBSONEncoder, codingPath: [CodingKey], wrapping container: PureBSONMutableArray) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }

    public mutating func encodeNil() throws { self.container.add(PureBSONNull()) }
    public mutating func encode(_ value: Bool) throws { self.container.add(value) }
    public mutating func encode(_ value: Int) throws { self.container.add(Int64(value)) }
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

    private mutating func encodeNumber<T: PureCodableNumber>(_ value: T) throws {
        self.encoder.codingPath.append(_PureBSONKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }

        self.container.add(try encoder.boxNumber(value))
    }

    public mutating func encode<T: Encodable>(_ value: T) throws {
        self.encoder.codingPath.append(_PureBSONKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }

        self.container.add(try encoder.box(value))
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
        -> KeyedEncodingContainer<NestedKey> {
        self.codingPath.append(_PureBSONKey(index: self.count))
        defer { self.codingPath.removeLast() }

        let dictionary = PureBSONMutableDictionary()
        self.container.add(dictionary)

        let container = _PureBSONKeyedEncodingContainer<NestedKey>(
            referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self.codingPath.append(_PureBSONKey(index: self.count))
        defer { self.codingPath.removeLast() }

        let array = PureBSONMutableArray()
        self.container.add(array)
        return _PureBSONUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }

    public mutating func superEncoder() -> Encoder {
         return _PureBSONReferencingEncoder(referencing: self.encoder, at: self.container.count, wrapping: self.container)
    }
}

/// :nodoc:
extension _PureBSONEncoder: SingleValueEncodingContainer {
    private func assertCanEncodeNewValue() {
        guard self.canEncodeNewValue else {
            fatalError("Attempt to encode value through single value container when previously value already encoded.")
        }
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.storage.push(container: 1)
    }

    public func encode(_ value: Bool) throws { try self.encodeBSONType(value) }
    public func encode(_ value: Int) throws { try self.encodeBSONType(Int64(value)) }
    public func encode(_ value: Int8) throws { try self.encodeNumber(value) }
    public func encode(_ value: Int16) throws { try self.encodeNumber(value) }
    public func encode(_ value: Int32) throws { try self.encodeBSONType(value) }
    public func encode(_ value: Int64) throws { try self.encodeBSONType(value) }
    public func encode(_ value: UInt) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt8) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt16) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt32) throws { try self.encodeNumber(value) }
    public func encode(_ value: UInt64) throws { try self.encodeNumber(value) }
    public func encode(_ value: String) throws { try self.encodeBSONType(value) }
    public func encode(_ value: Float) throws { try self.encodeNumber(value) }
    public func encode(_ value: Double) throws { try self.encodeBSONType(value) }

    private func encodeNumber<T: PureCodableNumber>(_ value: T) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: try self.boxNumber(value))
    }

    private func encodeBSONType<T: PureBSONValue>(_ value: T) throws {
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
private class PureBSONMutableArray: PureBSONValue {
    internal static var bsonType: BSONType { return .array }
    internal var bson: BSON { return .array(self.array.map { $0.bson }) }

    var array = [PureBSONValue]()

    fileprivate func add(_ value: PureBSONValue) {
        array.append(value)
    }

    var count: Int { return array.count }

    func insert(_ value: PureBSONValue, at index: Int) {
        self.array.insert(value, at: index)
    }

    init() {}

    internal required init(from data: Data) throws {
        fatalError("This method should not be called")
    }

    internal func toBSON() -> Data {
        fatalError("This method should not be called")
    }

    public required init(from decoder: Decoder) throws {
        fatalError("not meant to be decoded")
    }

    public func encode(to encoder: Encoder) throws {
        fatalError("not meant to be encoded")
    }
}

/// A private class wrapping a Swift dictionary so we can pass it by reference
/// for encoder storage purposes. We use this rather than NSMutableDictionary
/// because it allows us to preserve Swift type information.
private class PureBSONMutableDictionary: PureBSONValue {
    static var bsonType: BSONType { return .document }
    var bson: BSON { return .document(self.asDocument()) }

    // rather than using a dictionary, do this so we preserve key orders
    var keys = [String]()
    var values = [PureBSONValue]()

    subscript(key: String) -> PureBSONValue? {
        get {
            guard let index = keys.index(of: key) else {
                return nil
            }
            return values[index]
        }
        set(newValue) {
            if let newValue = newValue {
                keys.append(key)
                values.append(newValue)
            } else {
                guard let index = keys.index(of: key) else {
                    return
                }
                values.remove(at: index)
                keys.remove(at: index)
            }
        }
    }

    /// Converts self to a `Document` with equivalent key-value pairs.
    func asDocument() -> PureBSONDocument {
        var doc = PureBSONDocument()
        for i in 0 ..< self.keys.count {
            doc[self.keys[i]] = self.values[i].bson
        }
        return doc
    }

    init() {}

    internal required init(from data: Data) throws {
        throw RuntimeError.internalError(message: "mutable dict init")
    }

    internal func toBSON() -> Data {
        fatalError("dont call this mutable dict tobson")
    }

    func encode(to encoder: Encoder) throws {
        fatalError("`MutableDictionary` is not meant to be encoded with an `Encoder`")
    }
    required convenience init(from decoder: Decoder) throws {
        fatalError("`MutableDictionary` is not meant to be initialized from a `Decoder`")
    }
}

private extension EncodingError {
    static func _PurenumberError<T: PureCodableNumber>(at path: [CodingKey], value: T) -> EncodingError {
        let description = "Value \(String(describing: value)) of type \(type(of: value)) cannot be " +
                            "exactly represented by a BSON number type (Int, Int32, Int64 or Double)."
        return .invalidValue(value, Context(codingPath: path, debugDescription: description))
    }
}
