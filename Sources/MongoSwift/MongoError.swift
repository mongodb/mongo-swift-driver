import Foundation
import mongoc

/// An empty protocol for encapsulating all errors that this package can throw.
public protocol MongoSwiftError: LocalizedError {}

// TODO: update this link and the one below (SWIFT-319)
/// A MongoDB server error code.
/// - SeeAlso: https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err
public typealias ServerErrorCode = Int

/// The possible errors corresponding to types of errors encountered in the MongoDB server.
/// These errors may contain labels providing additional information on their origin.
/// - SeeAlso: https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err
public enum ServerError: MongoSwiftError {
    /// Thrown when commands experience errors on the server that prevent execution.
    case commandError(code: ServerErrorCode, message: String, errorLabels: [String]?)

    /// Thrown when a single write command fails on the server.
    /// Note: Only one of `writeConcernError` or `writeError` will be populated at a time.
    case writeError(writeError: WriteError?, writeConcernError: WriteConcernError?, errorLabels: [String]?)

    /// Thrown when the server returns errors as part of an executed bulk write.
    /// Note: `writeErrors` may not be present if the error experienced was a Write Concern related error.
    case bulkWriteError(writeErrors: [BulkWriteError]?,
                        writeConcernError: WriteConcernError?,
                        result: BulkWriteResult?,
                        errorLabels: [String]?)

    public var errorDescription: String? {
        switch self {
        case let .commandError(code: _, message: msg, errorLabels: _):
            return msg
        case let .writeError(writeError: writeErr, writeConcernError: wcErr, errorLabels: _):
            if let writeErr = writeErr {
                return writeErr.message
            } else if let wcErr = wcErr {
                return wcErr.message
            }
            return "" // should never get here
        case let .bulkWriteError(writeErrors: writeErrs, writeConcernError: wcErr, result: _, errorLabels: _):
            if let writeErrs = writeErrs {
                return writeErrs.map({ bwe in bwe.message }).joined(separator: ", ")
            } else if let wcErr = wcErr {
                return wcErr.message
            }
            return "" // should never get here
        }
    }
}

/// The possible errors caused by improper use of the driver by the user.
public enum UserError: MongoSwiftError {
    /// Thrown when the driver is incorrectly used.
    case logicError(message: String)

    /// Thrown when the user passes in invalid arguments to a driver method.
    case invalidArgumentError(message: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidArgumentError(message: msg), let .logicError(message: msg):
            return msg
        }
    }
}

/// The possible errors that can occur unexpectedly during runtime.
public enum RuntimeError: MongoSwiftError {
    /// Thrown when the driver encounters a internal error not caused by the user. This is usually indicative of a bug
    /// or system related failure (e.g. during memory allocation).
    case internalError(message: String)

    /// Thrown when encountering a connection or socket related error.
    /// May contain labels providing additional information on the nature of the error.
    case connectionError(message: String, errorLabels: [String]?)

    /// Thrown when encountering an authentication related error (e.g. invalid credentials).
    case authenticationError(message: String)

    public var errorDescription: String? {
        switch self {
        case let .internalError(message: msg),
             let .connectionError(message: msg, errorLabels: _),
             let .authenticationError(message: msg):
            return msg
        }
    }
}

/// A struct to represent a single write error not resulting from an executed bulk write.
public struct WriteError: Codable {
    /// An integer value identifying the error.
    public let code: ServerErrorCode

    /// A description of the error.
    public let message: String

    private enum CodingKeys: String, CodingKey {
        case code
        case message = "errmsg"
    }
}

/// A struct to represent a write concern error resulting from an executed bulk write.
public struct WriteConcernError: Codable {
    /// An integer value identifying the write concern error.
    public let code: ServerErrorCode

    /// A document identifying the write concern setting related to the error.
    public let details: Document

    /// A description of the error.
    public let message: String

    private enum CodingKeys: String, CodingKey {
        case code
        case details = "errInfo"
        case message = "errmsg"
    }
}

/// A struct to represent a write error resulting from an executed bulk write.
public struct BulkWriteError: Codable {
    /// An integer value identifying the error.
    public let code: ServerErrorCode

    /// A description of the error.
    public let message: String

    /// The index of the request that errored.
    public let index: Int

    /// The request that errored.
    public let request: WriteModel? = nil

    private enum CodingKeys: String, CodingKey {
        case code
        case message = "errmsg"
        case index
    }
}

/// Internal helper function used to get an appropriate error from a libmongoc error. This should NOT be used to get
/// `.writeError`s or `.bulkWriteError`s. Instead, construct those from replies returned from libmongoc functions.
internal func parseMongocError(error: bson_error_t, errorLabels: [String]? = nil) -> MongoSwiftError {
    let domain = mongoc_error_domain_t(rawValue: error.domain)
    let code = mongoc_error_code_t(rawValue: error.code)
    let message = toErrorString(error)

    switch (domain, code) {
    case (MONGOC_ERROR_CLIENT, MONGOC_ERROR_CLIENT_AUTHENTICATE):
        return RuntimeError.authenticationError(message: message)
    case (MONGOC_ERROR_COMMAND, MONGOC_ERROR_COMMAND_INVALID_ARG):
        return UserError.invalidArgumentError(message: message)
    case (MONGOC_ERROR_SERVER, _):
        return ServerError.commandError(
                code: ServerErrorCode(code.rawValue),
                message: message,
                errorLabels: errorLabels)
    case (MONGOC_ERROR_STREAM, _),
         (MONGOC_ERROR_SERVER_SELECTION, MONGOC_ERROR_SERVER_SELECTION_FAILURE),
         (MONGOC_ERROR_PROTOCOL, MONGOC_ERROR_PROTOCOL_BAD_WIRE_VERSION):
        return RuntimeError.connectionError(message: message, errorLabels: errorLabels)
    default:
        assert(errorLabels == nil, "errorLabels set on error, but were not thrown as a MongoSwiftError. " +
                "Labels: \(errorLabels ?? [])")
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
