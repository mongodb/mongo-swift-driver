import Foundation

/// `BSONDecoder` facilitates the decoding of BSON into semantic `Decodable` types.
public class BSONDecoder {
    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    internal static var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
    }()

    /// Enum representing the various strategies for decoding `Date`s from BSON.
    ///
    /// As per the BSON specification, the default strategy is to decode `Date`s from BSON datetime objects.
    ///
    /// - SeeAlso: bsonspec.org
    public enum DateDecodingStrategy {
        /// Decode `Date`s stored as BSON datetimes (default).
        case bsonDateTime

        /// Decode `Date`s stored as numbers of seconds since January 1, 1970.
        case millisecondsSince1970

        /// Decode `Date`s stored as numbers of milliseconds since January 1, 1970.
        case secondsSince1970

        /// Decode `Date`s by deferring to their default decoding implementation.
        case deferredToDate

        /// Decode `Date`s stored as ISO8601 formatted strings.
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Decode `Date`s stored as strings parsable by the given formatter.
        case formatted(DateFormatter)

        /// Decode `Date`s using the provided closure.
        case custom((_ decoder: Decoder) throws -> Date)
    }

    /// Enum representing the various strategies for decoding `UUID`s from BSON.
    ///
    /// As per the BSON specification, the default strategy is to decode `UUID`s from BSON binary types with the UUID
    /// subtype.
    ///
    /// - SeeAlso: bsonspec.org
    public enum UUIDDecodingStrategy {
        /// Decode `UUID`s by deferring to their default decoding implementation.
        case deferredToUUID

        /// Decode `UUID`s stored as the `BSONBinary` type (default).
        case binary
    }

    /// Enum representing the various strategies for decoding `Data`s from BSON.
    ///
    /// As per the BSON specification, the default strategy is to decode `Data`s from BSON binary types with the generic
    /// binary subtype.
    ///
    /// - SeeAlso: bsonspec.org
    public enum DataDecodingStrategy {
        /// Decode `Data`s by deferring to their default decoding implementation.
        ///
        /// Note: The default decoding implementation attempts to decode the `Data` from a `[UInt8]`, but because BSON
        /// does not support integer types other `Int32` and `Int64`, it actually decodes from an `[Int32]` stored
        /// in BSON. This strategy paired with its corresponding encoding strategy results in an inefficient storage of
        /// the `Data` in BSON.
        case deferredToData

        /// Decode `Data`s stored as the `BSONBinary` type (default).
        case binary

        /// Decode `Data`s stored as base64 encoded strings.
        case base64

        /// Decode `Data`s using the provided closure.
        case custom((_ decoder: Decoder) throws -> Data)
    }

    /// Contextual user-provided information for use during decoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// The strategy used for decoding `Date`s with this instance.
    public var dateDecodingStrategy: DateDecodingStrategy = .bsonDateTime

    /// The strategy used for decoding `UUID`s with this instance.
    public var uuidDecodingStrategy: UUIDDecodingStrategy = .binary

    /// The strategy used for decoding `Data`s with this instance.
    public var dataDecodingStrategy: DataDecodingStrategy = .binary

    /// Options set on the top-level decoder to pass down the decoding hierarchy.
    internal struct _Options {
        internal let userInfo: [CodingUserInfoKey: Any]
        internal let dateDecodingStrategy: DateDecodingStrategy
        internal let uuidDecodingStrategy: UUIDDecodingStrategy
        internal let dataDecodingStrategy: DataDecodingStrategy
    }

    /// The options set on the top-level decoder.
    fileprivate var options: _Options {
        _Options(
            userInfo: self.userInfo,
            dateDecodingStrategy: self.dateDecodingStrategy,
            uuidDecodingStrategy: self.uuidDecodingStrategy,
            dataDecodingStrategy: self.dataDecodingStrategy
        )
    }

    /// Initializes `self`.
    public init(options: CodingStrategyProvider? = nil) {
        self.configureWithOptions(options: options)
    }

    /// Initializes `self` by using the options of another `BSONDecoder` and the provided options, with preference
    /// going to the provided options in the case of conflicts.
    internal init(copies other: BSONDecoder, options: CodingStrategyProvider?) {
        self.userInfo = other.userInfo
        self.dateDecodingStrategy = other.dateDecodingStrategy
        self.uuidDecodingStrategy = other.uuidDecodingStrategy
        self.dataDecodingStrategy = other.dataDecodingStrategy
        self.configureWithOptions(options: options)
    }

    internal func configureWithOptions(options: CodingStrategyProvider?) {
        self.dateDecodingStrategy = options?.dateCodingStrategy?.rawValue.decoding ?? self.dateDecodingStrategy
        self.uuidDecodingStrategy = options?.uuidCodingStrategy?.rawValue.decoding ?? self.uuidDecodingStrategy
        self.dataDecodingStrategy = options?.dataCodingStrategy?.rawValue.decoding ?? self.dataDecodingStrategy
    }

    /**
     * Decodes a top-level value of the given type from the given BSON document.
     *
     * - Parameter type: The type of the value to decode.
     * - Parameter document: The BSON document to decode from.
     * - Returns: A value of the requested type.
     * - Throws: `DecodingError` if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_ type: T.Type, from document: BSONDocument) throws -> T {
        // if the requested type is `BSONDocument` we're done
        if let doc = document as? T {
            return doc
        }
        let _decoder = _BSONDecoder(referencing: .document(document), options: self.options)
        do {
            return try type.init(from: _decoder)
        } catch let error as BSONErrorProtocol {
            let unknownErrorMessage = "Unknown Error occurred while decoding BSON"
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Unable to decode BSON: \(error.errorDescription ?? unknownErrorMessage)"
                )
            )
        }
    }

    /**
     * Decodes a top-level value of the given type from the given BSON data.
     *
     * - Parameter type: The type of the value to decode.
     * - Parameter data: The BSON data to decode from.
     * - Returns: A value of the requested type.
     * - Throws: `DecodingError` if the BSON data is corrupt or if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try self.decode(type, from: BSONDocument(fromBSON: data))
    }

    /**
     * Decodes a top-level value of the given type from the given JSON/extended JSON string.
     *
     * - Parameter type: The type of the value to decode.
     * - Parameter json: The JSON string to decode from.
     * - Returns: A value of the requested type.
     * - Throws: `DecodingError` if the JSON data is corrupt or if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_: T.Type, from json: String) throws -> T {
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

        if let doc = try? BSONDocument(fromJSON: wrapped) {
            let s = try self.decode(DecodableWrapper<T>.self, from: doc)
            return s.value
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Unable to parse JSON string \(json)"
            ))
    }

    /// A struct to wrap a `Decodable` type, allowing us to support decoding to types that
    /// are not inside a wrapping object (for ex., Int or String).
    private struct DecodableWrapper<T: Decodable>: Decodable {
        let value: T
    }
}

/// :nodoc: An internal class to actually implement the `Decoder` protocol.
internal class _BSONDecoder: Decoder {
    /// The decoder's storage.
    internal var storage: _BSONDecodingStorage

    /// Options set on the top-level decoder.
    internal let options: BSONDecoder._Options

    /// The path to the current point in decoding.
    public fileprivate(set) var codingPath: [CodingKey]

    /// Contextual user-provided information for use during decoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        self.options.userInfo
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
    fileprivate init(
        referencing container: BSON,
        at codingPath: [CodingKey] = [],
        options: BSONDecoder._Options
    ) {
        self.storage = _BSONDecodingStorage()
        self.storage.push(container: container)
        self.codingPath = codingPath
        self.options = options
    }

    // Returns the data stored in this decoder as represented in a container keyed by the given key type.
    public func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let topContainer = self.storage.topContainer.documentValue else {
            throw DecodingError._typeMismatch(
                at: self.codingPath,
                expectation: BSONDocument.self,
                reality: self.storage.topContainer.bsonValue
            )
        }

        let container = _BSONKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }

    // Returns the data stored in this decoder in a container appropriate for holding a single primitive value.
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }

    // Returns the data stored in this decoder in a container appropriate for holding values with no keys.
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let arr = self.storage.topContainer.arrayValue else {
            throw DecodingError._typeMismatch(
                at: self.codingPath,
                expectation: [BSON].self,
                reality: self.storage.topContainer.bsonValue
            )
        }

        return _BSONUnkeyedDecodingContainer(referencing: self, wrapping: arr)
    }
}

// Storage for a _BSONDecoder.
internal struct _BSONDecodingStorage {
    /// The container stack, consisting of `BSONValue`s.
    fileprivate private(set) var containers: [BSON] = []

    /// Initializes `self` with no containers.
    fileprivate init() {}

    /// The count of containers stored.
    fileprivate var count: Int { self.containers.count }

    /// The container at the top of the stack.
    internal var topContainer: BSON {
        guard !self.containers.isEmpty else {
            fatalError("Empty container stack.")
        }
        // swiftlint:disable:next force_unwrapping
        return self.containers.last! // guaranteed safe because of precondition.
    }

    /// Adds a new container to the stack.
    fileprivate mutating func push(container: BSON) {
        self.containers.append(container)
    }

    /// Pops the top container from the stack.
    fileprivate mutating func popContainer() {
        guard !self.containers.isEmpty else {
            fatalError("Empty container stack.")
        }
        self.containers.removeLast()
    }
}

/// Extend _BSONDecoder to add methods for "unboxing" values as various types.
extension _BSONDecoder {
    /// Unbox a type using the provided closure.
    fileprivate func unboxCustom<T>(_ value: BSON, f: (BSON) -> T?) throws -> T {
        // We throw in the case of BSONNull because nulls should be requested through decodeNil().
        guard value != .null else {
            throw DecodingError.valueNotFound(
                T.self,
                DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Expected a non-null type."
                )
            )
        }

        guard let typed = f(value) else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: T.self, reality: value.bsonValue)
        }
        return typed
    }

    /// Attempt to unbox a type that conforms to `BSONValue`.
    fileprivate func unboxBSONValue<T: BSONValue>(_ value: BSON, as type: T.Type) throws -> T {
        // We throw in the case of BSONNull because nulls should be requested through decodeNil().
        guard value != .null else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Expected a non-null type."
                )
            )
        }

        guard let typed = value.bsonValue as? T else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value.bsonValue)
        }
        return typed
    }

    /// Attempt to unbox a type that conforms to `CodableNumber`.
    fileprivate func unboxNumber<T: CodableNumber>(_ value: BSON, as type: T.Type) throws -> T {
        guard let primitive = T(from: value) else {
            throw DecodingError._numberMismatch(at: self.codingPath, expectation: type, reality: value.bsonValue)
        }
        return primitive
    }

    /// Attempt to unbox a `Data` according to the set `DataDecodingStrategy`.
    fileprivate func unboxData(_ value: BSON) throws -> Data {
        switch self.options.dataDecodingStrategy {
        case .deferredToData:
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try Data(from: self)
        case .binary:
            let binary = try self.unboxCustom(value) { $0.binaryValue }
            guard let data = binary.data.getBytes(at: 0, length: binary.data.writerIndex) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "Cannot read \(binary.data.writerIndex) bytes from Binary.data"
                    )
                )
            }
            return Data(data)
        case .base64:
            let base64Str = try self.unboxCustom(value) { $0.stringValue }

            guard let data = Data(base64Encoded: base64Str) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "Malformatted base64 encoded string. Got: \(value)"
                    )
                )
            }
            return data
        case let .custom(f):
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try f(self)
        }
    }

    /// Attempt to unbox a `Data` according to the set `DateDecodingStrategy`.
    fileprivate func unboxDate(_ value: BSON) throws -> Date {
        switch self.options.dateDecodingStrategy {
        case .bsonDateTime:
            let date = try self.unboxCustom(value) { $0.dateValue }
            return date
        case .deferredToDate:
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try Date(from: self)
        case .millisecondsSince1970:
            let ms = try unboxNumber(value, as: Int64.self)
            return Date(msSinceEpoch: ms)
        case .secondsSince1970:
            let seconds = try unboxNumber(value, as: Double.self)
            return Date(timeIntervalSince1970: seconds)
        case .iso8601:
            let isoString = try self.unboxCustom(value) { $0.stringValue }
            guard let date = BSONDecoder.iso8601Formatter.date(from: isoString) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "String \"\(isoString)\" is not a properly formatted " +
                            "ISO 8601 Date string."
                    )
                )
            }
            return date
        case let .custom(f):
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try f(self)
        case let .formatted(formatter):
            let dateString = try self.unboxCustom(value) { $0.stringValue }
            guard let date = formatter.date(from: dateString) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "String \"\(dateString)\" does not match the format " +
                            "expected by formatter."
                    )
                )
            }
            return date
        }
    }

    /// Attempt to unbox a `Data` according to the set `UUIDDecodingStrategy`.
    fileprivate func unboxUUID(_ value: BSON) throws -> UUID {
        switch self.options.uuidDecodingStrategy {
        case .deferredToUUID:
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try UUID(from: self)
        case .binary:
            let binary = try self.unboxCustom(value) { $0.binaryValue }
            do {
                return try binary.toUUID()
            } catch {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: error.localizedDescription
                    )
                )
            }
        }
    }

    fileprivate func unbox<T: Decodable>(_ value: BSON, as type: T.Type) throws -> T {
        // swiftlint:disable force_cast
        switch type {
        case is Date.Type:
            // We know T is a Date and unboxDate returns a Date or throws, so this cast will always work.
            return try self.unboxDate(value) as! T
        case is UUID.Type:
            // We know T is a UUID and unboxUUID returns a UUID or throws, so this cast will always work.
            return try self.unboxUUID(value) as! T
        case is Data.Type:
            // We know T is a Data and unboxData returns a Data or throws, so this cast will always work.
            return try self.unboxData(value) as! T
        case is BSON.Type:
            switch value {
            case .datetime:
                // We know T is a BSON so this cast will always work.
                return try BSON.datetime(self.unboxDate(value)) as! T
            default:
                // We know T is a BSON so this cast will always work.
                return value as! T
            }
        default:
            break
        }
        // swiftlint:enable force_cast

        // if the data is already stored as the correct type in the document, then we can short-circuit
        // and just return the typed value here
        if let val = value.bsonValue as? T {
            return val
        }

        self.storage.push(container: value)
        defer { self.storage.popContainer() }
        return try T(from: self)
    }
}

/// A keyed decoding container, backed by a `BSONDocument`.
private struct _BSONKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    /// A reference to the decoder we're reading from.
    private let decoder: _BSONDecoder

    /// A reference to the container we're reading from.
    fileprivate let container: BSONDocument

    /// The path of coding keys taken to get to this point in decoding.
    public private(set) var codingPath: [CodingKey]

    /// Initializes `self`, referencing the given decoder and container.
    fileprivate init(referencing decoder: _BSONDecoder, wrapping container: BSONDocument) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
    }

    /// All the keys the decoder has for this container.
    public var allKeys: [Key] {
        self.container.keys.compactMap { Key(stringValue: $0) }
    }

    /// Returns a Boolean value indicating whether the decoder contains a value associated with the given key.
    public func contains(_ key: Key) -> Bool {
        self.container.hasKey(key.stringValue)
    }

    /// A string description of a CodingKey, for use in error messages.
    private func _errorDescription(of key: CodingKey) -> String {
        "\(key) (\"\(key.stringValue)\")"
    }

    /// Private helper function to check for a value in self.container. Returns the value stored
    /// under `key`, or throws an error if the value is not found.
    private func getValue(forKey key: Key) throws -> BSON {
        guard let entry = try self.container.getValue(for: key.stringValue) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: self.decoder.codingPath,
                    debugDescription: "No value associated with key \(self._errorDescription(of: key))."
                )
            )
        }
        return entry
    }

    /// Decode a BSONValue type from this container for the given key.
    private func decodeBSONType<T: BSONValue>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            try decoder.unboxBSONValue(entry, as: type)
        }
    }

    /// Decodes a CodableNumber type from this container for the given key.
    private func decodeNumber<T: CodableNumber>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            try decoder.unboxNumber(entry, as: type)
        }
    }

    /// Decodes a Decodable type from this container for the given key.
    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let entry = try getValue(forKey: key)
        return try self.decoder.with(pushedKey: key) {
            let value = try decoder.unbox(entry, as: type)
            guard !(value is BSONNull) || type == BSONNull.self else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(
                        codingPath: self.decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
                )
            }
            return value
        }
    }

    /// Decodes a null value for the given key.
    public func decodeNil(forKey key: Key) throws -> Bool {
        // check if the key exists in the document, so we can differentiate between
        // the key being set to nil and the key not existing at all.
        guard self.contains(key) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: self.decoder.codingPath,
                    debugDescription: "Key \(self._errorDescription(of: key)) not found."
                )
            )
        }
        return try self.container.getValue(for: key.stringValue) == .null
    }

    // swiftlint:disable line_length
    public func decode(_: Bool.Type, forKey key: Key) throws -> Bool { try self.decodeBSONType(Bool.self, forKey: key) }
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try self.decodeNumber(type, forKey: key) }
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try self.decodeNumber(type, forKey: key) }
    public func decode(_: String.Type, forKey key: Key) throws -> String { try self.decodeBSONType(String.self, forKey: key) }
    // swiftlint:enable line_length

    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    public func nestedContainer<NestedKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try self.decoder.with(pushedKey: key) {
            let value = try getValue(forKey: key)

            guard let doc = value.documentValue else {
                throw DecodingError._typeMismatch(
                    at: self.codingPath,
                    expectation: BSONDocument.self,
                    reality: value.bsonValue
                )
            }

            let container = _BSONKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: doc)
            return KeyedDecodingContainer(container)
        }
    }

    /// Returns the data stored for the given key as represented in an unkeyed container.
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try self.decoder.with(pushedKey: key) {
            let value = try getValue(forKey: key)

            guard let array = value.arrayValue else {
                throw DecodingError._typeMismatch(
                    at: self.codingPath,
                    expectation: [BSON].self,
                    reality: value.bsonValue
                )
            }

            return _BSONUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
        }
    }

    /// Private method to create a superDecoder for the provided key.
    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        try self.decoder.with(pushedKey: key) {
            guard let value = try self.container.getValue(for: key.stringValue) else {
                throw DecodingError.keyNotFound(
                    key,
                    DecodingError.Context(
                        codingPath: self.decoder.codingPath,
                        debugDescription: "Could not find key \(key) in Decoder container"
                    )
                )
            }
            return _BSONDecoder(
                referencing: value,
                at: self.decoder.codingPath,
                options: self.decoder.options
            )
        }
    }

    /// Returns a Decoder instance for decoding super from the container associated with the default super key.
    public func superDecoder() throws -> Decoder {
        try self._superDecoder(forKey: _BSONKey.super)
    }

    // Returns a Decoder instance for decoding super from the container associated with the given key.
    public func superDecoder(forKey key: Key) throws -> Decoder {
        try self._superDecoder(forKey: key)
    }
}

private struct _BSONUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    /// A reference to the decoder we're reading from.
    private let decoder: _BSONDecoder

    /// A reference to the container we're reading from.
    private let container: [BSON]

    /// The path of coding keys taken to get to this point in decoding.
    public private(set) var codingPath: [CodingKey]

    /// The index of the element we're about to decode.
    public private(set) var currentIndex: Int

    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _BSONDecoder, wrapping container: [BSON]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
    }

    /// The number of elements contained within this container.
    public var count: Int? { self.container.count }

    /// A Boolean value indicating whether there are no more elements left to be decoded in the container.
    public var isAtEnd: Bool { self.currentIndex >= self.count! }
    // swiftlint:disable:previous force_unwrapping
    // `.count` always returns a value and is only an `Int?` because it's required of the
    // UnkeyedDecodingContainer protocol.

    /// A private helper function to check if we're at the end of the container, and if so throw an error.
    private func checkAtEnd() throws {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(
                BSON.self,
                DecodingError.Context(
                    codingPath: self.decoder.codingPath + [_BSONKey(index: self.currentIndex)],
                    debugDescription: "Unkeyed container is at end."
                )
            )
        }
    }

    /// Decodes a BSONValue type from this container.
    private mutating func decodeBSONType<T: BSONValue>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()
        return try self.decoder.with(pushedKey: _BSONKey(index: self.currentIndex)) {
            let typed = try self.decoder.unboxBSONValue(self.container[currentIndex], as: type)
            self.currentIndex += 1
            return typed
        }
    }

    /// Decodes a CodableNumber type from this container.
    private mutating func decodeNumber<T: CodableNumber>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()
        return try self.decoder.with(pushedKey: _BSONKey(index: self.currentIndex)) {
            let typed = try self.decoder.unboxNumber(self.container[currentIndex], as: type)
            self.currentIndex += 1
            return typed
        }
    }

    /// Decodes a Decodable type from this container.
    public mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try self.checkAtEnd()
        return try self.decoder.with(pushedKey: _BSONKey(index: self.currentIndex)) {
            let decoded = try self.decoder.unbox(self.container[currentIndex], as: T.self)
            guard !(decoded is BSONNull) else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(
                        codingPath: self.decoder.codingPath + [_BSONKey(index: self.currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
                )
            }
            self.currentIndex += 1
            return decoded
        }
    }

    /// Decodes a null value from this container.
    public mutating func decodeNil() throws -> Bool {
        try self.checkAtEnd()

        if self.container[self.currentIndex] == .null {
            self.currentIndex += 1
            return true
        }
        return false
    }

    /// Decode all required types from this container using the helpers defined above.
    public mutating func decode(_ type: Bool.Type) throws -> Bool { try self.decodeBSONType(type) }
    public mutating func decode(_ type: Int.Type) throws -> Int { try self.decodeNumber(type) }
    public mutating func decode(_ type: Int8.Type) throws -> Int8 { try self.decodeNumber(type) }
    public mutating func decode(_ type: Int16.Type) throws -> Int16 { try self.decodeNumber(type) }
    public mutating func decode(_ type: Int32.Type) throws -> Int32 { try self.decodeNumber(type) }
    public mutating func decode(_ type: Int64.Type) throws -> Int64 { try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt.Type) throws -> UInt { try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try self.decodeNumber(type) }
    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try self.decodeNumber(type) }
    public mutating func decode(_ type: Float.Type) throws -> Float { try self.decodeNumber(type) }
    public mutating func decode(_ type: Double.Type) throws -> Double { try self.decodeNumber(type) }
    public mutating func decode(_ type: String.Type) throws -> String { try self.decodeBSONType(type) }

    /// Decodes a nested container keyed by the given type.
    public mutating func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type)
        throws -> KeyedDecodingContainer<NestedKey> {
        try self.decoder.with(pushedKey: _BSONKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let doc = try self.decodeBSONType(BSONDocument.self)
            self.currentIndex += 1
            let container = _BSONKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: doc)
            return KeyedDecodingContainer(container)
        }
    }

    /// Decodes an unkeyed nested container.
    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try self.decoder.with(pushedKey: _BSONKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let array = try self.decodeBSONType([BSON].self)
            self.currentIndex += 1
            return _BSONUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
        }
    }

    /// Decodes a nested container and returns a Decoder instance for decoding super from that container.
    public mutating func superDecoder() throws -> Decoder {
        try self.decoder.with(pushedKey: _BSONKey(index: self.currentIndex)) {
            try self.checkAtEnd()
            let value = self.container[self.currentIndex]
            self.currentIndex += 1
            return _BSONDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options)
        }
    }
}

/// :nodoc:
extension _BSONDecoder: SingleValueDecodingContainer {
    /// Assert that the top container for this decoder is non-null.
    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Expected \(type) but found null value instead."
                )
            )
        }
    }

    /// Internal method used to decode directly to a `BSON`.
    internal func decodeBSON() throws -> BSON {
        if self.decodeNil() {
            return .null
        }
        return try self.unbox(self.storage.topContainer, as: BSON.self)
    }

    /// Decode a BSONValue type from this container.
    private func decodeBSONType<T: BSONValue>(_: T.Type) throws -> T {
        try self.expectNonNull(T.self)
        return try self.unboxBSONValue(self.storage.topContainer, as: T.self)
    }

    /// Decode a CodableNumber type from this container.
    private func decodeNumber<T: CodableNumber>(_: T.Type) throws -> T {
        try self.expectNonNull(T.self)
        return try self.unboxNumber(self.storage.topContainer, as: T.self)
    }

    /// Decode a Decodable type from this container.
    public func decode<T: Decodable>(_: T.Type) throws -> T {
        try self.expectNonNull(T.self)
        return try self.unbox(self.storage.topContainer, as: T.self)
    }

    /// Decode a null value from this container.
    public func decodeNil() -> Bool { self.storage.topContainer == .null }

    /// Decode all the required types from this container using the helpers defined above.
    public func decode(_ type: Bool.Type) throws -> Bool { try self.decodeBSONType(type) }
    public func decode(_ type: Int.Type) throws -> Int { try self.decodeNumber(type) }
    public func decode(_ type: Int8.Type) throws -> Int8 { try self.decodeNumber(type) }
    public func decode(_ type: Int16.Type) throws -> Int16 { try self.decodeNumber(type) }
    public func decode(_ type: Int32.Type) throws -> Int32 { try self.decodeNumber(type) }
    public func decode(_ type: Int64.Type) throws -> Int64 { try self.decodeNumber(type) }
    public func decode(_ type: UInt.Type) throws -> UInt { try self.decodeNumber(type) }
    public func decode(_ type: UInt8.Type) throws -> UInt8 { try self.decodeNumber(type) }
    public func decode(_ type: UInt16.Type) throws -> UInt16 { try self.decodeNumber(type) }
    public func decode(_ type: UInt32.Type) throws -> UInt32 { try self.decodeNumber(type) }
    public func decode(_ type: UInt64.Type) throws -> UInt64 { try self.decodeNumber(type) }
    public func decode(_ type: Float.Type) throws -> Float { try self.decodeNumber(type) }
    public func decode(_ type: Double.Type) throws -> Double { try self.decodeNumber(type) }
    public func decode(_ type: String.Type) throws -> String { try self.decodeBSONType(type) }
}

internal struct _BSONKey: CodingKey {
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

    // swiftlint:disable:next force_unwrapping
    internal static let `super` = _BSONKey(stringValue: "super")! // this initializer never actually returns nil.
}

extension DecodingError {
    internal static func _typeMismatch(
        at path: [CodingKey],
        expectation: Any.Type,
        reality: BSONValue
    ) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(type(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }

    internal static func _numberMismatch(
        at path: [CodingKey],
        expectation: Any.Type,
        reality: BSONValue
    ) -> DecodingError {
        let description = "Expected to find a value that can be represented as a \(expectation), " +
            "but found value \(String(describing: reality)) of type \(type(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }
}
