import Foundation
import mongoc

/// An empty protocol for encapsulating all errors that this package can throw.
public protocol MongoError: LocalizedError {}

// TODO: update this link and the one below (SWIFT-319)
/// A MongoDB server error code.
/// - SeeAlso: https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err
public typealias ServerErrorCode = Int

/// The possible errors corresponding to types of errors encountered in the MongoDB server.
/// These errors may contain labels providing additional information on their origin.
/// - SeeAlso: https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err
public enum ServerError: MongoError {
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
public enum UserError: MongoError {
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
public enum RuntimeError: MongoError {
    /// Thrown when the driver encounters a internal error not caused by the user. This is usually indicative of a bug
    /// or system related failure (e.g. during memory allocation).
    case internalError(message: String)

    /// Thrown when encountering a connection or socket related error.
    /// May contain labels providing additional information on the nature of the error.
    case connectionError(message: String, errorLabels: [String]?)

    /// Thrown when encountering an authentication related error (e.g. invalid credentials).
    case authenticationError(message: String)

    /// Thrown when trying to use a feature that the deployment does not support.
    case compatibilityError(message: String)

    public var errorDescription: String? {
        switch self {
        case let .internalError(message: msg),
             let .connectionError(message: msg, errorLabels: _),
             let .authenticationError(message: msg),
             let .compatibilityError(message: msg):
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
    public let details: Document?

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

    private enum CodingKeys: String, CodingKey {
        case code
        case message = "errmsg"
        case index
    }
}

/// Internal helper function used to get an appropriate error from a libmongoc error. This should NOT be used to get
/// `.writeError`s or `.bulkWriteError`s. Instead, construct those using `getErrorFromReply`.
internal func parseMongocError(_ error: bson_error_t, errorLabels: [String]? = nil) -> MongoError {
    let domain = mongoc_error_domain_t(rawValue: error.domain)
    let code = mongoc_error_code_t(rawValue: error.code)
    let message = toErrorString(error)

    switch (domain, code) {
    case (MONGOC_ERROR_CLIENT, MONGOC_ERROR_CLIENT_AUTHENTICATE):
        return RuntimeError.authenticationError(message: message)
    case (MONGOC_ERROR_CLIENT, MONGOC_ERROR_CLIENT_SESSION_FAILURE):
        // If user attempts to start a session against a server that doesn't support it, we throw a compat error.
        if message.lowercased().contains("support sessions") {
            return RuntimeError.compatibilityError(message: "Deployment does not support sessions")
        }
        // Otherwise, a generic internal error.
        return RuntimeError.internalError(message: message)
    case (MONGOC_ERROR_COMMAND, MONGOC_ERROR_COMMAND_INVALID_ARG):
        return UserError.invalidArgumentError(message: message)
    case (MONGOC_ERROR_SERVER, _):
        return ServerError.commandError(
                code: ServerErrorCode(code.rawValue),
                message: message,
                errorLabels: errorLabels)
    case (MONGOC_ERROR_STREAM, _), (MONGOC_ERROR_SERVER_SELECTION, MONGOC_ERROR_SERVER_SELECTION_FAILURE):
        return RuntimeError.connectionError(message: message, errorLabels: errorLabels)
    case (MONGOC_ERROR_CURSOR, MONGOC_ERROR_CURSOR_INVALID_CURSOR):
        return UserError.logicError(message: message)
    case (MONGOC_ERROR_PROTOCOL, MONGOC_ERROR_PROTOCOL_BAD_WIRE_VERSION):
        return RuntimeError.compatibilityError(message: message)
    default:
        assert(errorLabels == nil, "errorLabels set on error, but were not thrown as a MongoError. " +
                "Labels: \(errorLabels ?? [])")
        return RuntimeError.internalError(message: message)
    }
}

/// Internal function used to get an appropriate error from a server reply to a command.
internal func getErrorFromReply(
        bsonError: bson_error_t,
        from reply: Document,
        forBulkWrite bulkWrite: BulkWriteOperation? = nil,
        withResult result: BulkWriteResult? = nil) -> MongoError {
    // if writeErrors or writeConcernErrors aren't present, then this is likely a commandError.
    guard reply["writeErrors"] != nil || reply["writeConcernErrors"] != nil else {
        return parseMongocError(bsonError, errorLabels: reply["errorLabels"] as? [String])
    }

    let fallback = RuntimeError.internalError(message: "Got error from the server but couldn't parse it. " +
            "Message: \(toErrorString(bsonError))")

    do {
        let decoder = BSONDecoder()

        var writeConcernError: WriteConcernError?
        if let writeConcernErrors = reply["writeConcernErrors"] as? [Document], !writeConcernErrors.isEmpty {
            writeConcernError = try decoder.decode(WriteConcernError.self, from: writeConcernErrors[0])
        }

        if let bulkWrite = bulkWrite {
            return try getBulkWriteErrorFromReply(
                    from: reply,
                    forBulkWrite: bulkWrite,
                    withResult: result,
                    withWriteConcernError: writeConcernError) ?? fallback
        }

        return try getWriteErrorFromReply(from: reply, withWriteConcernError: writeConcernError) ?? fallback
    } catch {
        return fallback
    }
}

/// Function used to extract a write error from a server reply.
private func getWriteErrorFromReply(
        from reply: Document,
        withWriteConcernError wcErr: WriteConcernError? = nil) throws -> MongoError? {
    let decoder = BSONDecoder()
    var writeError: WriteError?
    if let writeErrors = reply["writeErrors"] as? [Document], !writeErrors.isEmpty {
        writeError = try decoder.decode(WriteError.self, from: writeErrors[0])
    }

    guard writeError != nil || wcErr != nil else {
        return nil
    }

    return ServerError.writeError(
            writeError: writeError,
            writeConcernError: wcErr,
            errorLabels: reply["errorLabels"] as? [String]
    )
}

/// Function used to extract bulk write errors from a server reply.
private func getBulkWriteErrorFromReply(
        from reply: Document,
        forBulkWrite bulkWrite: BulkWriteOperation,
        withResult result: BulkWriteResult? = nil,
        withWriteConcernError wcErr: WriteConcernError? = nil) throws -> MongoError? {
    let decoder = BSONDecoder()

    var bulkWriteErrors: [BulkWriteError] = []
    if let writeErrors = reply["writeErrors"] as? [Document] {
        bulkWriteErrors = try writeErrors.map { try decoder.decode(BulkWriteError.self, from: $0) }
    }

    // Need to create new result that omits the ids that failed in insertedIds.
    var errResult: BulkWriteResult?
    if let result = result {
        let ordered = try bulkWrite.opts?.getValue(for: "ordered") as? Bool ?? true

        // remove the unsuccessful inserts/upserts from the insertedIds/upsertedIds maps
        let filterFailures = { (map: [Int: BSONValue], nSucceeded: Int) -> [Int: BSONValue] in
            guard nSucceeded > 0 else {
                return [:]
            }

            if ordered { // remove all after the last index that succeeded
                let maxIndex = map.keys.sorted()[nSucceeded - 1]
                return map.filter { $0.key <= maxIndex }
            } else { // if unordered, just remove those that have write errors associated with them
                let errs = bulkWriteErrors.map { $0.index }
                return map.filter { !errs.contains($0.key) }
            }
        }

        errResult = BulkWriteResult(
                deletedCount: result.deletedCount,
                insertedCount: result.insertedCount,
                insertedIds: filterFailures(result.insertedIds, result.insertedCount),
                matchedCount: result.matchedCount,
                modifiedCount: result.modifiedCount,
                upsertedCount: result.upsertedCount,
                upsertedIds: filterFailures(result.upsertedIds, result.upsertedCount)
        )
    }

    return ServerError.bulkWriteError(
            writeErrors: bulkWriteErrors,
            writeConcernError: wcErr,
            result: errResult,
            errorLabels: reply["errorLabels"] as? [String]
    )
}

/// Internal function used by write methods performing single writes that are implemented via the bulk API. Catches any
/// ServerError.bulkWriteErrors thrown by the given closure and converts them to ServerError.writeErrors. All other
/// errors will be propagated as-is.
internal func convertingBulkWriteErrors<T>(_ body: () throws -> T) throws -> T {
    do {
        return try body()
    } catch let ServerError.bulkWriteError(bulkWriteErrors, writeConcernError, _, errorLabels) {
        var writeError: WriteError?
        if let bwes = bulkWriteErrors, !bwes.isEmpty {
            writeError = WriteError(code: bwes[0].code, message: bwes[0].message)
        }
        throw ServerError.writeError(writeError: writeError,
                                     writeConcernError: writeConcernError,
                                     errorLabels: errorLabels)
    }
}

internal func toErrorString(_ error: bson_error_t) -> String {
    return withUnsafeBytes(of: error.message) { rawPtr -> String in
        // if baseAddress is nil, the buffer is empty.
        guard let baseAddress = rawPtr.baseAddress else {
            return ""
        }
        return String(cString: baseAddress.assumingMemoryBound(to: CChar.self))
    }
}

internal func bsonTooLargeError(value: BSONValue, forKey: String) -> MongoError {
    return RuntimeError.internalError(message:
        "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType): document too large")
}

internal func wrongIterTypeError(_ iter: DocumentIterator, expected type: BSONValue.Type) -> MongoError {
    return UserError.logicError(message: "Tried to retreive a \(type) from an iterator whose next type " +
            "is \(iter.currentType) for key \(iter.currentKey)")
}
