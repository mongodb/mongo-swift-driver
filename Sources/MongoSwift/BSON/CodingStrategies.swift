import Foundation

/// Protocol indicating a set of options can be used to configure `BSONEncoder` and `BSONDecoder`.
public protocol CodingStrategyProvider {
    /// Specifies the strategy to use when converting `Date`s between their BSON representations and their
    /// representations in (non `Document`) `Codable` types.
    var dateCodingStrategy: DateCodingStrategy? { get }

    /// Specifies the strategy to use when converting `UUID`s between their BSON representations and their
    /// representations in (non `Document`) `Codable` types.
    var uuidCodingStrategy: UUIDCodingStrategy? { get }

    /// Specifies the strategy to use when converting `Data`s between their BSON representations and their
    /// representations in (non `Document`) `Codable` types.
    var dataCodingStrategy: DataCodingStrategy? { get }
}

/// Options struct used for configuring the coding strategies on `BSONEncoder` and `BSONDecoder`.
public struct BSONCoderOptions: CodingStrategyProvider {
    public var dateCodingStrategy: DateCodingStrategy?

    public var uuidCodingStrategy: UUIDCodingStrategy?

    public var dataCodingStrategy: DataCodingStrategy?

    /// Initializes a new `BSONCoderOptions`.
    public init(dateCodingStrategy: DateCodingStrategy? = nil,
                uuidCodingStrategy: UUIDCodingStrategy? = nil,
                dataCodingStrategy: DataCodingStrategy? = nil) {
        self.dateCodingStrategy = dateCodingStrategy
        self.uuidCodingStrategy = uuidCodingStrategy
        self.dataCodingStrategy = dataCodingStrategy
    }
}

/**
 * Enum representing the various encoding/decoding strategy pairs for `Date`s.
 * Set these on a `MongoClient`, `MongoDatabase`, or `MongoCollection` so that the strategies will be applied when
 * converting `Date`s between their BSON representations and their representations in (non `Document`) `Codable` types.
 *
 * As per the BSON specification, the default strategy is to encode `Date`s as BSON datetime objects.
 *
 * - SeeAlso: bsonspec.org
 */
public enum DateCodingStrategy: RawRepresentable {
    public typealias RawValue = (encoding: BSONEncoder.DateEncodingStrategy, decoding: BSONDecoder.DateDecodingStrategy)

    /// Encode/decode the `Date` by deferring to its default encoding/decoding implementations.
    case deferredToDate

    /// Encode/decode the `Date` to/from a BSON datetime object (default).
    case bsonDateTime

    /// Encode/decode the `Date` to/from a 64-bit integer counting the number of milliseconds since January 1, 1970.
    case millisecondsSince1970

    /// Encode/decode the `Date` to/from a BSON double counting the number of seconds since January 1, 1970.
    case secondsSince1970

    /// Encode/decode the `Date` to/from an ISO-8601-formatted string (in RFC 339 format).
    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    case iso8601

    /// Encode/decode the `Date` to/from a string formatted by the given formatter.
    case formatted(DateFormatter)

    /// Encode the `Date` by using the given `encodeFunc`. Decode the `Date` by using the given `decodeFunc`.
    /// If `encodeFunc` does not encode a value, an empty document will be encoded in its place.
    case custom(encodeFunc: (Date, Encoder) throws -> Void, decodeFunc: (Decoder) throws -> Date)

    public init?(rawValue: RawValue) {
        switch rawValue {
        case (.deferredToDate, .deferredToDate):
            self = .deferredToDate
        case (.bsonDateTime, .bsonDateTime):
            self = .bsonDateTime
        case (.millisecondsSince1970, .millisecondsSince1970):
            self = .millisecondsSince1970
        case (.secondsSince1970, .secondsSince1970):
            self = .secondsSince1970
        case (.iso8601, .iso8601):
            guard #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
            self = .iso8601
        case let (.formatted(encodingFormatter), .formatted(decodingFormatter)):
            guard encodingFormatter == decodingFormatter else {
                return nil
            }
            self = .formatted(encodingFormatter)
        case let (.custom(encodeFunc), .custom(decodeFunc)):
            self = .custom(encodeFunc: encodeFunc, decodeFunc: decodeFunc)
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .deferredToDate:
            return (.deferredToDate, .deferredToDate)
        case .bsonDateTime:
            return (.bsonDateTime, .bsonDateTime)
        case .millisecondsSince1970:
            return (.millisecondsSince1970, .millisecondsSince1970)
        case .secondsSince1970:
            return (.secondsSince1970, .secondsSince1970)
        case .iso8601:
            guard #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
            return (.iso8601, .iso8601)
        case let .formatted(formatter):
            return (.formatted(formatter), .formatted(formatter))
        case let .custom(encodeFunc, decodeFunc):
            return (.custom(encodeFunc), .custom(decodeFunc))
        }
    }
}

/**
 * Enum representing the various encoding/decoding strategy pairs for `UUID`s.
 * Set these on a `MongoClient`, `MongoDatabase`, or `MongoCollection` so that the strategies will be applied when
 * converting `UUID`s between their BSON representations and their representations in (non `Document`) `Codable` types.
 *
 * As per the BSON specification, the default strategy is to encode `UUID`s as BSON binary types with the UUID
 * subtype.
 *
 * - SeeAlso: bsonspec.org
 */
public enum UUIDCodingStrategy: RawRepresentable {
    public typealias RawValue = (encoding: BSONEncoder.UUIDEncodingStrategy, decoding: BSONDecoder.UUIDDecodingStrategy)

    /// Encode/decode the `UUID` by deferring to its default encoding/decoding implementations.
    case deferredToUUID

    /// Encode/decode the `UUID` to/from a BSON binary type (default).
    case binary

    public init?(rawValue: RawValue) {
        switch rawValue {
        case (.deferredToUUID, .deferredToUUID):
            self = .deferredToUUID
        case (.binary, .binary):
            self = .binary
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .deferredToUUID:
            return (.deferredToUUID, .deferredToUUID)
        case .binary:
            return (.binary, .binary)
        }
    }
}

/**
 * Enum representing the various encoding/decoding strategy pairs for `Data`s.
 * Set these on a `MongoClient`, `MongoDatabase`, or `MongoCollection` so that the strategies will be applied when
 * converting `Data`s between their BSON representations and their representations in (non `Document`) `Codable` types.
 *
 * As per the BSON specification, the default strategy is to encode `Data`s as BSON binary types with the generic
 * binary subtype.
 *
 * - SeeAlso: bsonspec.org
 */
public enum DataCodingStrategy: RawRepresentable {
    public typealias RawValue = (encoding: BSONEncoder.DataEncodingStrategy, decoding: BSONDecoder.DataDecodingStrategy)

    /**
     * Encode/decode the `Data` by deferring to its default encoding implementations.
     *
     * Note: The default encoding implementation attempts to encode the `Data` as a `[UInt8]`, but because BSON
     * does not support integer types besides `Int32` or `Int64`, it actually gets encoded to BSON as an `[Int32]`.
     * This results in a space inefficient storage of the `Data` (using 4 bytes of BSON storage per byte of data).
     */
    case deferredToData

    /// Encode/decode the `Data` to/from a BSON binary type (default).
    case binary

    /// Encode the `Data` to/from a base64 encoded string.
    case base64

    /// Encode the `Data` by using the given `encodeFunc`. Decode the `Data` by using the given `decodeFunc`.
    /// If `encodeFunc` does not encode a value, an empty document will be encoded in its place.
    case custom(encodeFunc: (Data, Encoder) throws -> Void, decodeFunc: (Decoder) throws -> Data)

    public init?(rawValue: RawValue) {
        switch rawValue {
        case (.deferredToData, .deferredToData):
            self = .deferredToData
        case (.binary, .binary):
            self = .binary
        case (.base64, .base64):
            self = .base64
        case let (.custom(encodeFunc), .custom(decodeFunc)):
            self = .custom(encodeFunc: encodeFunc, decodeFunc: decodeFunc)
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .deferredToData:
            return (.deferredToData, .deferredToData)
        case .binary:
            return (.binary, .binary)
        case .base64:
            return (.base64, .base64)
        case let .custom(encodeFunc, decodeFunc):
            return (.custom(encodeFunc), .custom(decodeFunc))
        }
    }
}
