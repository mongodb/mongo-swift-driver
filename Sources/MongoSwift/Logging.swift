import CLibMongoC
import Foundation
import Logging

extension mongoc_structured_log_level_t {
    /// The swift-log level corresponding to this mongoc log level.
    fileprivate var swiftLogLevel: Logger.Level {
        switch self {
        // .critical is the most severe level available in Swift, so we must
        // map the more severe levels (emergency and alert) down to it.
        case MONGOC_STRUCTURED_LOG_LEVEL_EMERGENCY,
             MONGOC_STRUCTURED_LOG_LEVEL_ALERT,
             MONGOC_STRUCTURED_LOG_LEVEL_CRITICAL:
            return .critical
        case MONGOC_STRUCTURED_LOG_LEVEL_ERROR:
            return .error
        case MONGOC_STRUCTURED_LOG_LEVEL_WARNING:
            return .warning
        case MONGOC_STRUCTURED_LOG_LEVEL_NOTICE:
            return .notice
        case MONGOC_STRUCTURED_LOG_LEVEL_INFO:
            return .info
        case MONGOC_STRUCTURED_LOG_LEVEL_DEBUG:
            return .debug
        case MONGOC_STRUCTURED_LOG_LEVEL_TRACE:
            return .trace
        default:
            // we never expect these log levels to change; the spec lays out
            // all of the values that will ever be permitted for use.
            fatalError("Unrecognized libmongoc log level \(self)")
        }
    }
}

/// If the env var has been set to enable logging, creates a corresponding Logger with the specified level. Else,
/// returns nil.
private func makeLogger(envVar: String, label: String) -> Logger? {
    // No level was provided.
    guard let envVarLevel = ProcessInfo.processInfo.environment[envVar]?.lowercased() else {
        return nil
    }
    // "off" or any unrecognized level. (should we do something different on an unrecognized level?)
    guard let level = Logger.Level(rawValue: envVarLevel) else {
        return nil
    }

    var logger = Logger(label: label)
    logger.logLevel = level
    return logger
}

/// Global loggers corresponding to each component. We will likely add more of these with time as more components are
/// defined in the logging spec.
private let COMMAND_LOGGER = makeLogger(envVar: "MONGODB_LOGGING_COMMAND", label: "MongoSwift.command")
private let SDAM_LOGGER = makeLogger(envVar: "MONGODB_LOGGING_SDAM", label: "MongoSwift.sdam")
private let SERVER_SELECTION_LOGGER = makeLogger(
    envVar: "MONGODB_LOGGING_SERVER_SELECTION", 
    label: "MongoSwift.serverSelection"
)
private let CONNECTION_LOGGER = makeLogger(envVar: "MONGODB_LOGGING_CONNECTION", label: "MongoSwift.connection")

/// For testing purposes, we define fallback loggers which can be mutated as needed to temporarily turn logging on/off
/// during tests. Arguably you could just handle this by making the original variables mutable, but it seemed a bit
/// safer to keep those locked down with their initial values.
internal var TEST_COMMAND_LOGGER: Logger? = nil
internal var TEST_SDAM_LOGGER: Logger? = nil
internal var TEST_SERVER_SELECTION_LOGGER: Logger? = nil
internal var TEST_CONNECTION_LOGGER: Logger? = nil

extension mongoc_structured_log_component_t {
    /// Returns the Swift logger corresponding to the mongoc log component. This value is nil if the user did not
    /// enable logging for the component, or if the component is unrecognized.
    fileprivate var swiftLogger: Logger? {
        switch self {
        case MONGOC_STRUCTURED_LOG_COMPONENT_COMMAND:
            return COMMAND_LOGGER ?? TEST_COMMAND_LOGGER
        case MONGOC_STRUCTURED_LOG_COMPONENT_SDAM:
            return SDAM_LOGGER ?? TEST_SDAM_LOGGER
        case MONGOC_STRUCTURED_LOG_COMPONENT_SERVER_SELECTION:
            return SERVER_SELECTION_LOGGER ?? TEST_SERVER_SELECTION_LOGGER
        case MONGOC_STRUCTURED_LOG_COMPONENT_CONNECTION:
            return CONNECTION_LOGGER ?? TEST_CONNECTION_LOGGER
        default:
            // ignore an unrecognized component. (TODO: codify in spec what should happen here?)
            return nil
        }
    }
}

/// Callback for handling a mongoc structured log message. This is registered one time via `initializeMongoc()`.
internal func handleMongocStructuredLogMessage(entry: OpaquePointer!, _: UnsafeMutableRawPointer?) {
    // Get the level associated with this log message.
    let level = mongoc_structured_log_entry_get_level(entry).swiftLogLevel

    // If a logger exists (meaning the user set a level for it via env var), and the level of this message is less
    // severe than that level, do nothing. Note that libmongoc only assembles the structured log entry (including
    // e.g. serializing commands to extJSON) when we call `get_message` below.
    guard let logger = mongoc_structured_log_entry_get_component(entry).swiftLogger, level >= logger.logLevel else {
        return
    }

    let msg = BSONDocument(copying: mongoc_structured_log_entry_get_message(entry))
    logger.log(
        level: level,
        "\(msg["message"]!.stringValue!)", // assumes message is always present and a string. TODO: perhaps codify in spec?
        metadata: msg.toLoggerMetadata()
    )
}

extension BSONDocument {
    /// Converts a BSONDocument to Logger.Metadata to attach to a log message.
    fileprivate func toLoggerMetadata() -> Logger.Metadata {
        var metadata = Logger.Metadata()
        // libmongoc returns the message along with all of the other data, but we emit it separately.
        for (k, v) in self where k != "message" {
            // just use the string representation of the BSON value. in practice so far, the values in the log entries
            // are only ever integers or strings.
            metadata[k] = "\(v.bsonValue)"
        }
        return metadata
    }
}

// No-op handler to prevent libmongoc from auto-logging to stderr (default behavior for non-structured logging).
// This gets registered via initializeMongoc().
internal func handleMongocLogMessage(
    level _: mongoc_log_level_t,
    domain _: UnsafePointer<CChar>?,
    message _: UnsafePointer<CChar>?,
    userInfo _: UnsafeMutableRawPointer?
) {}
