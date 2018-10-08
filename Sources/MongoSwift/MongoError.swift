import Foundation
import libmongoc

/// The possible errors that can occur when using this package.
public enum MongoError {
    /// Thrown when an invalid connection string is provided when initializing a `MongoClient`.
    case invalidUri(message: String)
    /// Thrown when a `MongoClient` is invalid.
    case invalidClient()
    /// Thrown when the server sends an invalid response.
    case invalidResponse()
    /// Thrown when a `MongoCursor` is invalid.
    case invalidCursor(message: String)
    /// Thrown when a `MongoCollection` is invalid.
    case invalidCollection(message: String)
    /// Thrown when there is an error executing a command.
    case commandError(message: String)
    /// Thrown when there is an error parsing raw BSON `Data`. 
    case bsonParseError(domain: UInt32, code: UInt32, message: String)
    /// Thrown when there is an error encoding a `BsonValue` to a `Document`.
    case bsonEncodeError(message: String)
    /// Thrown when there is an error decoding a `BsonValue` from a `Document`.
    case bsonDecodeError(message: String)
    /// Thrown when the value stored under a key in a `Document` does not match the expected type.
    case typeError(message: String)
    /// Thrown when there is an error involving a `ReadConcern`. 
    case readConcernError(message: String)
    /// Thrown when there is an error involving a `ReadPreference`.
    case readPreferenceError(message: String)
    /// Thrown when a user-provided argument is invalid.
    case invalidArgument(message: String)
    /// Thrown when there is an error executing a multi-document insert operation.
    case insertManyError(code: UInt32, message: String, result: InsertManyResult?, writeErrors: [WriteError],
        writeConcernError: WriteConcernError?)
    /// Thrown when there is an error executing a bulk write operation.
    case bulkWriteError(code: UInt32, message: String, result: BulkWriteResult?, writeErrors: [WriteError],
        writeConcernError: WriteConcernError?)
}

/// An extension of `MongoError` to support printing out descriptive error messages.
extension MongoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidUri(message), let .invalidCursor(message),
            let .invalidCollection(message), let .commandError(message),
            let .bsonParseError(_, _, message), let .bsonEncodeError(message),
            let .typeError(message), let .readConcernError(message),
            let .readPreferenceError(message), let .invalidArgument(message):
            return message
        case let .bulkWriteError(code, message, _, _, _):
            return "\(message) (error code \(code))"
        default:
            return nil
        }
    }
}

internal func toErrorString(_ error: bson_error_t) -> String {
    var e = error
    return withUnsafeBytes(of: &e.message) { (rawPtr) -> String in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
    }
}

internal func bsonEncodeError(value: BsonValue, forKey: String) -> MongoError {
    return MongoError.bsonEncodeError(message:
        "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType)")
}
