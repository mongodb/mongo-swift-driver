import Foundation
import mongoc

/// An empty protocol for encapsulating all errors that this package can throw.
protocol MongoSwiftError: Error {}

/// The possible errors corresponding to types of errors encountered in the MongoDB server.
///
/// - SeeAlso: https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err
public enum ServerError: MongoSwiftError {
    /// Thrown when commands experience errors on the server that prevent execution.
    case commandError(code: Int, message: String)

    /// Thrown when errors occur on the server during commands that write not as part of a bulk write.
    ///
    /// Note: Only one of writeConcernError or writeError will populated at a time.
    case writeError(writeError: WriteError?, writeConcernError: WriteConcernError?)

    /// Thrown when the server returns errors as part of an executed bulk write.
    ///
    /// Note: writeErrors may not be present if the error experienced was a Write Concern related error.
    case bulkWriteError(writeErrors: [BulkWriteError]?, writeConcernError: WriteConcernError?, result: BulkWriteResult?)
}

/// The possible errors caused by improper use of the driver by the user.
public enum UserError: MongoSwiftError {
    /// Thrown when the driver is incorrectly used.
    case logicError(message: String)

    /// Thrown when the user passes in invalid arguments to a driver method.
    case invalidArgument(message: String)
}

/// The possible errors that can occur unexpectedly during runtime.
public enum RuntimeError: MongoSwiftError {
    /// Thrown when the driver encounters a internal error not caused by the user. This is usually indicative of a bug
    /// or system related failure (e.g. during memory allocation).
    case internalError(message: String)

    /// Thrown when encountering a connection or socket related error.
    case connectionError(message: String)

    /// Thrown when encountering an authentication related error (e.g. invalid credentials).
    case authenticationError(message: String)
}

/// Internal listing of mongoc error domains. Because they're defined in libmongoc via a typedef'd enum, we cannot get
/// their raw values in Swift. Hence, we define them here. The same goes for the error codes below.
internal enum MongoCErrorDomain: UInt32 {
    case clientError = 1
    case streamError
    case protocolError
    case cursorError
    case queryError
    case insertError
    case saslError
    case bsonError
    case matcherError
    case namespaceError
    case commandError
    case collectionError
    case gridfsError
    case scramError
    case serverSelectionError
    case writeConcernError
    case serverError
    case transactionError
}

/// Internal listing of relevant mongoc error codes.
internal enum MongoCErrorCode: UInt32 {
    case authenticateError = 11
    case invalidArg = 22
    case badWireVersion = 15
    case selectionFailure = 13051
}

/// Internal helper function used to get an appropriate error from a libmongoc error. This should NOT be used to get
/// `.writeError`s or `.bulkWriteError`s.
// swiftlint:disable:next cyclomatic_complexity
internal func parseMongocError(domain: UInt32, code: UInt32, message: String) -> MongoSwiftError {
    guard let mongocDomain = MongoCErrorDomain(rawValue: domain) else {
        return RuntimeError.internalError(message: message)
    }

    switch mongocDomain {
    case .clientError:
        if code == MongoCErrorCode.authenticateError.rawValue {
            return RuntimeError.authenticationError(message: message)
        }
    case .commandError:
        if code == MongoCErrorCode.invalidArg.rawValue {
            return UserError.invalidArgument(message: message)
        }
    case .serverError:
        return ServerError.commandError(code: Int(code), message: message)
    case .streamError:
        return RuntimeError.connectionError(message: message)
    case .serverSelectionError:
        if code == MongoCErrorCode.selectionFailure.rawValue {
            return RuntimeError.connectionError(message: message)
        }
    case .protocolError:
        if code == MongoCErrorCode.badWireVersion.rawValue {
            return RuntimeError.connectionError(message: message)
        }
    default:
        break
    }

    return RuntimeError.internalError(message: message)
}

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
    /// Thrown when there is an error encoding a `BSONValue` to a `Document`.
    case bsonEncodeError(message: String)
    /// Thrown when there is an error decoding a `BSONValue` from a `Document`.
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
    return withUnsafeBytes(of: &e.message) { rawPtr -> String in
        // if baseAddress is nil, the buffer is empty.
        guard let baseAddress = rawPtr.baseAddress else {
            return ""
        }
        return String(cString: baseAddress.assumingMemoryBound(to: CChar.self))
    }
}

internal func bsonEncodeError(value: BSONValue, forKey: String) -> MongoError {
    return MongoError.bsonEncodeError(message:
        "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType)")
}
