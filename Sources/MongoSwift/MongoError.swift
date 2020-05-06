import CLibMongoC
import Foundation

/// An empty protocol for encapsulating all errors that this package can throw.
public protocol MongoError: LocalizedError {}

// TODO: update this link and the one below (SWIFT-319)
/// A MongoDB server error code.
/// - SeeAlso: https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.yml
public typealias ServerErrorCode = Int

/// Protocol conformed to by errors that may contain error labels.
public protocol LabeledError: MongoError {
    /// Labels that may describe the context in which this error was thrown.
    var errorLabels: [String]? { get }
}

/// Protocol conformed to by errors returned from the MongoDB deployment.
public protocol ServerError: LabeledError {}

/// Thrown when commands experience errors on the server that prevent execution.
public struct CommandError: ServerError {
    /// A numerical code identifying the error.
    public let code: ServerErrorCode

    /// A human-readable string identifying the error code.
    public let codeName: String

    /// A message from the server describing the error.
    public let message: String

    /// Labels that may describe the context in which this error was thrown.
    public let errorLabels: [String]?
}

/// An error that is thrown when a single write command fails on the server.
public struct WriteError: ServerError {
    /// The write error associated with this error.
    public let writeFailure: WriteFailure?

    /// The write concern error associated with this error.
    public let writeConcernFailure: WriteConcernFailure?

    /// Labels that may describe the context in which this error was thrown.
    public let errorLabels: [String]?
}

/// A error that ocurred while executing a bulk write.
public struct BulkWriteError: ServerError {
    /// The errors that occured during individual writes as part of a bulk write.
    /// This field might be nil if the error was a write concern related error.
    public let writeFailures: [BulkWriteFailure]?

    /// The error that occured on account of write concern failure.
    public let writeConcernFailure: WriteConcernFailure?

    /// Any other error that might have occurred during the execution of a bulk write
    /// (e.g. a connection failure that occurred after a few inserts already succeeded)
    public let otherError: Error?

    /// The partial result of any successful operations that occurred as part of a bulk write.
    public let result: BulkWriteResult?

    /// Labels that may describe the context in which this error was thrown.
    public let errorLabels: [String]?
}

/// A protocol describing errors caused by improper usage of the driver by the user.
public protocol UserError: MongoError {}

/// An error thrown when the driver is incorrectly used.
public struct LogicError: UserError {
    internal let message: String

    public var errorDescription: String { self.message }
}

/// An error thrown when the user passes in invalid arguments to a driver method.
public struct InvalidArgumentError: UserError {
    internal let message: String

    public var errorDescription: String { self.message }
}

/// The possible errors that can occur unexpectedly driver-side.
public protocol RuntimeError: MongoError {}

/// An error thrown when the driver encounters a internal error not caused by the user. This is usually indicative of
/// a bug in the driver or system related failure (e.g. memory allocation failure).
public struct InternalError: RuntimeError {
    internal let message: String

    public var errorDescription: String { self.message }
}

/// An error thrown when encountering a connection or socket related error.
/// May contain labels providing additional information on the nature of the error.
public struct ConnectionError: RuntimeError, LabeledError {
    public let message: String

    public let errorLabels: [String]?

    public var errorDescription: String { "\(self.message), errorLabels: \(self.errorLabels ?? [])" }
}

/// An error thrown when encountering an authentication related error (e.g. invalid credentials).
public struct AuthenticationError: RuntimeError {
    internal let message: String

    public var errorDescription: String { self.message }
}

/// An error thrown when trying to use a feature that the deployment does not support.
public struct CompatibilityError: RuntimeError {
    internal let message: String

    public var errorDescription: String { self.message }
}

/// An error that occured when trying to select a server (e.g. a timeout, or no server matched read preference).
///
/// - SeeAlso: https://docs.mongodb.com/manual/core/read-preference-mechanics/
public struct ServerSelectionError: RuntimeError {
    internal let message: String

    public var errorDescription: String { self.message }
}

/// A struct to represent a single write error not resulting from an executed write operation.
public struct WriteFailure: Codable {
    /// An integer value identifying the error.
    public let code: ServerErrorCode

    /// A human-readable string identifying the error.
    public let codeName: String

    /// A description of the error.
    public let message: String

    private enum CodingKeys: String, CodingKey {
        case code
        case codeName
        case message = "errmsg"
    }

    // TODO: can remove this once SERVER-36755 is resolved
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(ServerErrorCode.self, forKey: .code)
        self.message = try container.decode(String.self, forKey: .message)
        self.codeName = try container.decodeIfPresent(String.self, forKey: .codeName) ?? ""
    }

    // TODO: can remove this once SERVER-36755 is resolved
    internal init(code: ServerErrorCode, codeName: String, message: String) {
        self.code = code
        self.codeName = codeName
        self.message = message
    }
}

/// A struct to represent a write concern error resulting from an executed write operation.
public struct WriteConcernFailure: Codable {
    /// An integer value identifying the write concern error.
    public let code: ServerErrorCode

    /// A human-readable string identifying write concern error.
    public let codeName: String

    /// A document identifying the write concern setting related to the error.
    public let details: Document?

    /// A description of the error.
    public let message: String

    /// Labels that may describe the context in which this error was thrown.
    public let errorLabels: [String]?

    private enum CodingKeys: String, CodingKey {
        case code
        case codeName
        case details = "errInfo"
        case message = "errmsg"
        case errorLabels
    }

    // TODO: can remove this once SERVER-36755 is resolved
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(ServerErrorCode.self, forKey: .code)
        self.message = try container.decode(String.self, forKey: .message)
        self.codeName = try container.decodeIfPresent(String.self, forKey: .codeName) ?? ""
        self.details = try container.decodeIfPresent(Document.self, forKey: .details)
        self.errorLabels = try container.decodeIfPresent([String].self, forKey: .errorLabels)
    }

    // TODO: can remove this once SERVER-36755 is resolved
    internal init(
        code: ServerErrorCode, codeName: String, details: Document?, message: String, errorLabels: [String]? = nil
    ) {
        self.code = code
        self.codeName = codeName
        self.message = message
        self.details = details
        self.errorLabels = errorLabels
    }
}

/// A struct to represent a write error resulting from an executed bulk write.
public struct BulkWriteFailure: Codable {
    /// An integer value identifying the error.
    public let code: ServerErrorCode

    /// A human-readable string identifying the error.
    public let codeName: String

    /// A description of the error.
    public let message: String

    /// The index of the request that errored.
    public let index: Int

    private enum CodingKeys: String, CodingKey {
        case code
        case codeName
        case message = "errmsg"
        case index
    }

    // TODO: can remove this once SERVER-36755 is resolved
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(ServerErrorCode.self, forKey: .code)
        self.message = try container.decode(String.self, forKey: .message)
        self.index = try container.decode(Int.self, forKey: .index)
        self.codeName = try container.decodeIfPresent(String.self, forKey: .codeName) ?? ""
    }

    // TODO: can remove this once SERVER-36755 is resolved
    internal init(code: ServerErrorCode, codeName: String, message: String, index: Int) {
        self.code = code
        self.codeName = codeName
        self.message = message
        self.index = index
    }
}

// swiftlint:disable cyclomatic_complexity

/// Gets an appropriate error from a libmongoc error. Additional details may be provided in the form of a server reply
/// document.
private func parseMongocError(_ error: bson_error_t, reply: Document?) -> MongoError {
    let domain = mongoc_error_domain_t(rawValue: error.domain)
    let code = mongoc_error_code_t(rawValue: error.code)
    let message = toErrorString(error)

    let errorLabels = reply?["errorLabels"]?.arrayValue?.asArrayOf(String.self)
    let codeName = reply?["codeName"]?.stringValue ?? ""

    switch (domain, code) {
    case (MONGOC_ERROR_CLIENT, MONGOC_ERROR_CLIENT_AUTHENTICATE):
        return AuthenticationError(message: message)
    case (MONGOC_ERROR_CLIENT, MONGOC_ERROR_CLIENT_SESSION_FAILURE):
        // If user attempts to start a session against a server that doesn't support it, we throw a compat error.
        if message.lowercased().contains("support sessions") {
            return CompatibilityError(message: "Deployment does not support sessions")
        }
        // Otherwise, a generic internal error.
        return InternalError(message: message)
    case (MONGOC_ERROR_COMMAND, MONGOC_ERROR_COMMAND_INVALID_ARG):
        return InvalidArgumentError(message: message)
    case (MONGOC_ERROR_SERVER, _):
        return CommandError(
            code: ServerErrorCode(code.rawValue),
            codeName: codeName,
            message: message,
            errorLabels: errorLabels
        )
    case (MONGOC_ERROR_STREAM, _):
        return ConnectionError(message: message, errorLabels: errorLabels)
    case (MONGOC_ERROR_SERVER_SELECTION, MONGOC_ERROR_SERVER_SELECTION_FAILURE):
        return ServerSelectionError(message: message)
    case (MONGOC_ERROR_CURSOR, MONGOC_ERROR_CURSOR_INVALID_CURSOR):
        return InvalidArgumentError(message: message)
    case (MONGOC_ERROR_CURSOR, MONGOC_ERROR_CHANGE_STREAM_NO_RESUME_TOKEN):
        return LogicError(message: message)
    case (MONGOC_ERROR_PROTOCOL, MONGOC_ERROR_PROTOCOL_BAD_WIRE_VERSION):
        return CompatibilityError(message: message)
    case (MONGOC_ERROR_TRANSACTION, MONGOC_ERROR_TRANSACTION_INVALID_STATE):
        return LogicError(message: message)
    default:
        assert(
            errorLabels == nil, "errorLabels set on error, but were not thrown as a MongoError. " +
                "Labels: \(errorLabels ?? [])"
        )
        return InternalError(message: message)
    }
}

// swiftlint:enable cyclomatic_complexity

/// Internal function used to get an appropriate error from a libmongoc error and/or a server reply to a command.
internal func extractMongoError(error bsonError: bson_error_t, reply: Document? = nil) -> MongoError {
    // if the reply is nil or writeErrors or writeConcernErrors aren't present, then this is likely a commandError.
    guard let serverReply: Document = reply,
        !(serverReply["writeErrors"]?.arrayValue ?? []).isEmpty ||
        !(serverReply["writeConcernError"]?.documentValue?.keys ?? []).isEmpty ||
        !(serverReply["writeConcernErrors"]?.arrayValue ?? []).isEmpty else {
        return parseMongocError(bsonError, reply: reply)
    }

    let fallback = InternalError(
        message: "Got error from the server but couldn't parse it. Message: \(toErrorString(bsonError))"
    )

    do {
        var writeError: WriteFailure?
        if let writeErrors = serverReply["writeErrors"]?.arrayValue?.compactMap({ $0.documentValue }),
            !writeErrors.isEmpty {
            writeError = try BSONDecoder().decode(WriteFailure.self, from: writeErrors[0])
        }
        let wcError = try extractWriteConcernError(from: serverReply)

        guard writeError != nil || wcError != nil else {
            return fallback
        }

        return WriteError(
            writeFailure: writeError,
            writeConcernFailure: wcError,
            errorLabels: serverReply["errorLabels"]?.arrayValue?.asArrayOf(String.self)
        )
    } catch {
        return fallback
    }
}

/// Internal function used to get a `BulkWriteError` from a libmongoc error and a server reply to a
/// `BulkWriteOperation`. If a partial result is provided, an updated result with the failed results filtered out will
/// be returned as part of the error.
internal func extractBulkWriteError<T: Codable>(
    for op: BulkWriteOperation<T>,
    error: bson_error_t,
    reply: Document,
    partialResult: BulkWriteResult? = nil
) -> Error {
    let fallback = InternalError(
        message: "Got error from the server but couldn't parse it. " +
            "Message: \(toErrorString(error))"
    )

    do {
        var bulkWriteErrors: [BulkWriteFailure] = []
        if let writeErrors = reply["writeErrors"]?.arrayValue?.compactMap({ $0.documentValue }) {
            bulkWriteErrors = try writeErrors.map { try BSONDecoder().decode(BulkWriteFailure.self, from: $0) }
        }

        // Need to create new result that omits the ids that failed in insertedIds.
        var errResult: BulkWriteResult?
        if let result = partialResult {
            let ordered = op.options?.ordered ?? true

            // remove the unsuccessful inserts from the insertedIds map
            let filteredIds: [Int: BSON]
            if result.insertedCount == 0 {
                filteredIds = [:]
            } else {
                if ordered { // remove all after the last index that succeeded
                    let maxIndex = result.insertedIds.keys.sorted()[result.insertedCount - 1]
                    filteredIds = result.insertedIds.filter { $0.key <= maxIndex }
                } else { // if unordered, just remove those that have write errors associated with them
                    let errs = Set(bulkWriteErrors.map { $0.index })
                    filteredIds = result.insertedIds.filter { !errs.contains($0.key) }
                }
            }

            errResult = BulkWriteResult(
                deletedCount: result.deletedCount,
                insertedCount: result.insertedCount,
                insertedIds: filteredIds,
                matchedCount: result.matchedCount,
                modifiedCount: result.modifiedCount,
                upsertedCount: result.upsertedCount,
                upsertedIds: result.upsertedIds
            )
        }

        // extract any other error that might have occurred outside of the write/write concern errors. (e.g. connection)
        var other: Error?

        // we want to omit any write concern errors since they will also be reported elsewhere.
        if error.domain != MONGOC_ERROR_WRITE_CONCERN.rawValue {
            other = parseMongocError(error, reply: reply)
        }

        // in the absence of other errors, libmongoc will simply populate the mongoc_error_t with the error code of the
        // first write error and the concatenated error messages of all the write errors. in that case, we just want to
        // omit the "other" error.
        if let commandError = other as? CommandError,
            let wErr = bulkWriteErrors.first,
            wErr.code == commandError.code {
            other = nil
        }

        return BulkWriteError(
            writeFailures: bulkWriteErrors,
            writeConcernFailure: try extractWriteConcernError(from: reply),
            otherError: other,
            result: errResult,
            errorLabels: reply["errorLabels"]?.arrayValue?.asArrayOf(String.self)
        )
    } catch {
        return fallback
    }
}

/// Extracts a `WriteConcernError` from a server reply.
private func extractWriteConcernError(from reply: Document) throws -> WriteConcernFailure? {
    if let writeConcernErrors = reply["writeConcernErrors"]?.arrayValue?.compactMap({ $0.documentValue }),
        !writeConcernErrors.isEmpty {
        return try BSONDecoder().decode(WriteConcernFailure.self, from: writeConcernErrors[0])
    } else if let writeConcernError = reply["writeConcernError"]?.documentValue {
        return try BSONDecoder().decode(WriteConcernFailure.self, from: writeConcernError)
    } else {
        return nil
    }
}

/// Internal function used by write methods performing single writes that are implemented via the bulk API. If the
/// provided error is not a `BulkWriteError`, it will be returned as-is. Otherwise, the error will be converted to a
/// `WriteError`. If conversion fails, an `InternalError` will be returned.
internal func convertBulkWriteError(_ error: Error) -> Error {
    guard let bwe = error as? BulkWriteError else {
        return error
    }

    let writeFailure: WriteFailure? = bwe.writeFailures.flatMap { failures in
        guard let firstFailure = failures.first else {
            return nil
        }
        return WriteFailure(
            code: firstFailure.code,
            codeName: firstFailure.codeName,
            message: firstFailure.message
        )
    }

    if writeFailure != nil || bwe.writeConcernFailure != nil {
        return WriteError(
            writeFailure: writeFailure,
            writeConcernFailure: bwe.writeConcernFailure,
            errorLabels: bwe.errorLabels
        )
    } else if let otherErr = bwe.otherError {
        return otherErr
    }
    return InternalError(message: "Couldn't get error from BulkWriteError")
}

internal func toErrorString(_ error: bson_error_t) -> String {
    withUnsafeBytes(of: error.message) { rawPtr -> String in
        // if baseAddress is nil, the buffer is empty.
        guard let baseAddress = rawPtr.baseAddress else {
            return ""
        }
        return String(cString: baseAddress.assumingMemoryBound(to: CChar.self))
    }
}

internal func bsonTooLargeError(value: BSONValue, forKey: String) -> MongoError {
    InternalError(
        message:
        "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType): document too large"
    )
}

internal func wrongIterTypeError(_ iter: DocumentIterator, expected type: BSONValue.Type) -> MongoError {
    LogicError(
        message: "Tried to retreive a \(type) from an iterator whose next type " +
            "is \(iter.currentType) for key \(iter.currentKey)"
    )
}

internal let failedToRetrieveCursorMessage = "Couldn't get cursor from the server"

extension MongoError {
    /// Determines whether this error is an "ns not found" error.
    internal var isNsNotFound: Bool {
        guard let commandError = self as? CommandError else {
            return false
        }
        return commandError.code == 26
    }
}
