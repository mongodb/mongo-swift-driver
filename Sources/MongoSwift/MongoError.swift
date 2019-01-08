import Foundation
import mongoc

/// An empty protocol for encapsulating all errors that this package can throw.
public protocol MongoSwiftError: Error {}

/// The possible errors corresponding to types of errors encountered in the MongoDB server.
/// These errors may contain labels providing additional information on their origin.
/// - SeeAlso: https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err
public enum ServerError: MongoSwiftError, Equatable {
    /// Thrown when commands experience errors on the server that prevent execution.
    case commandError(code: Int, message: String, errorLabels: [String]?)

    /// Thrown when errors occur on the server during commands that write not as part of a bulk write
    /// Note: Only one of writeConcernError or writeError will populated at a time.
    case writeError(writeError: WriteError?, writeConcernError: WriteConcernError?, errorLabels: [String]?)

    /// Thrown when the server returns errors as part of an executed bulk write.
    /// Note: writeErrors may not be present if the error experienced was a Write Concern related error.
    case bulkWriteError(writeErrors: [BulkWriteError]?,
                        writeConcernError: WriteConcernError?,
                        result: BulkWriteResult?,
                        errorLabels: [String]?)

    public static func == (lhs: ServerError, rhs: ServerError) -> Bool {
        switch (lhs, rhs) {
        case let (.commandError(code: lhsCode, message: _, errorLabels: lhsErrorLabels),
                  .commandError(code: rhsCode, message: _, errorLabels: rhsErrorLabels)):
            return lhsCode == rhsCode && lhsErrorLabels?.sorted() == rhsErrorLabels?.sorted()
        case let (.writeError(writeError: lhsWriteError, writeConcernError: lhsWCError, errorLabels: lhsErrorLabels),
                  .writeError(writeError: rhsWriteError, writeConcernError: rhsWCError, errorLabels: rhsErrorLabels)):
            return lhsWriteError == rhsWriteError
                    && lhsWCError == rhsWCError
                    && lhsErrorLabels?.sorted() == rhsErrorLabels?.sorted()
        case let (.bulkWriteError(writeErrors: lhsWriteErrors,
                                  writeConcernError: lhsWCError,
                                  result: _,
                                  errorLabels: lhsErrorLabels),
                  .bulkWriteError(writeErrors: rhsWriteErrors,
                                  writeConcernError: rhsWCError,
                                  result: _,
                                  errorLabels: rhsErrorLabels)):
            let cmp = { (l: BulkWriteError, r: BulkWriteError) in l.index < r.index }
            return lhsWriteErrors?.sorted(by: cmp) == rhsWriteErrors?.sorted(by: cmp)
                    && lhsWCError == rhsWCError
                    && lhsErrorLabels?.sorted() == rhsErrorLabels?.sorted()
        default:
            return false
        }
    }
}

/// The possible errors caused by improper use of the driver by the user.
public enum UserError: MongoSwiftError, Equatable {
    /// Thrown when the driver is incorrectly used.
    case logicError(message: String)

    /// Thrown when the user passes in invalid arguments to a driver method.
    case invalidArgument(message: String)

    public static func == (lhs: UserError, rhs: UserError) -> Bool {
        switch (lhs, rhs) {
        case (.logicError(message: _), .logicError(message: _)),
             (.invalidArgument(message: _), .invalidArgument(message: _)):
            return true
        default:
            return false
        }
    }
}

/// The possible errors that can occur unexpectedly during runtime.
public enum RuntimeError: MongoSwiftError, Equatable {
    /// Thrown when the driver encounters a internal error not caused by the user. This is usually indicative of a bug
    /// or system related failure (e.g. during memory allocation).
    case internalError(message: String)

    /// Thrown when encountering a connection or socket related error.
    /// May contain labels providing additional information on the nature of the error.
    case connectionError(message: String, errorLabels: [String]?)

    /// Thrown when encountering an authentication related error (e.g. invalid credentials).
    case authenticationError(message: String)

    public static func == (lhs: RuntimeError, rhs: RuntimeError) -> Bool {
        switch (lhs, rhs) {
        case (.internalError(message: _), .internalError(message: _)),
             (.connectionError(message: _, errorLabels: _), .connectionError(message: _, errorLabels: _)),
             (.authenticationError(message: _), .authenticationError(message: _)):
            return true
        default:
            return false
        }
    }
}

/// Internal helper function used to get an appropriate error from a libmongoc error. This should NOT be used to get
/// `.writeError`s or `.bulkWriteError`s.
internal func parseMongocError(error: bson_error_t, errorLabels: [String]? = nil) -> MongoSwiftError {
    let domain = mongoc_error_domain_t(rawValue: error.domain)
    let code = mongoc_error_code_t(rawValue: error.code)
    let message = toErrorString(error)

    switch (domain, code) {
    case (MONGOC_ERROR_CLIENT, MONGOC_ERROR_CLIENT_AUTHENTICATE):
        return RuntimeError.authenticationError(message: message)
    case (MONGOC_ERROR_COMMAND, MONGOC_ERROR_COMMAND_INVALID_ARG):
        return UserError.invalidArgument(message: message)
    case (MONGOC_ERROR_SERVER, _):
        return ServerError.commandError(code: Int(code.rawValue), message: message, errorLabels: errorLabels)
    case (MONGOC_ERROR_STREAM, _):
        return RuntimeError.connectionError(message: message, errorLabels: errorLabels)
    case (MONGOC_ERROR_SERVER_SELECTION, MONGOC_ERROR_SERVER_SELECTION_FAILURE):
        return RuntimeError.connectionError(message: message, errorLabels: errorLabels)
    case (MONGOC_ERROR_PROTOCOL, MONGOC_ERROR_PROTOCOL_BAD_WIRE_VERSION):
        return RuntimeError.connectionError(message: message, errorLabels: errorLabels)
    default:
        return RuntimeError.internalError(message: message)
    }
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
    case bulkWriteError(code: UInt32, message: String, result: BulkWriteResult?, writeErrors: [BulkWriteError],
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
