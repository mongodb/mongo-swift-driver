import CLibMongoC
import Foundation
import Logging

extension mongoc_structured_log_level_t {
    fileprivate var swiftLogLevel: Logger.Level {
        switch self {
        // .critical is the most severe level available in Swift so we must
        // map the more severe levels emergency and alert down to it.
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
            fatalError("Unrecognized libmongoc log level \(self)")
        }
    }
}

private enum LogComponent {
    case command, sdam, serverSelection, connection
}

extension mongoc_structured_log_component_t {
    fileprivate var swiftLogComponent: LogComponent {
        switch self {
        case MONGOC_STRUCTURED_LOG_COMPONENT_COMMAND:
            return .command
        case MONGOC_STRUCTURED_LOG_COMPONENT_SDAM:
            return .sdam
        case MONGOC_STRUCTURED_LOG_COMPONENT_SERVER_SELECTION:
            return .serverSelection
        case MONGOC_STRUCTURED_LOG_COMPONENT_CONNECTION:
            return .connection
        default:
            // maybe should just do nothing instead, since this presumably
            // means its a component we don't support yet?
            fatalError("Unrecognized libmongoc log component \(self)")
        }
    }
}

internal class CommandLogger {
    internal static let global = CommandLogger()

    internal let logger: Logger?

    private init() {
        // how to handle invalid value here? currently just ignore
        // todo: handle if user specifies alert or emergency
        guard let envVarLevel = ProcessInfo.processInfo.environment["MONGODB_LOGGING_COMMAND"]?.lowercased(),
            let level = Logger.Level(rawValue: envVarLevel) else {
            self.logger = nil
            return
        }

        var logger = Logger(label: "MongoSwift.COMMAND")
        logger.logLevel = level
        self.logger = logger
    }
}

internal class ConnectionLogger {
    internal static let global = ConnectionLogger()

    internal let logger: Logger?

    private init() {
        // how to handle invalid value here? currently just ignore
        // todo: handle if user specifies alert or emergency
        guard let envVarLevel = ProcessInfo.processInfo.environment["MONGODB_LOGGING_CONNECTION"]?.lowercased(),
            let level = Logger.Level(rawValue: envVarLevel) else {
            self.logger = nil
            return
        }

        var logger = Logger(label: "MongoSwift.CONNECTION")
        logger.logLevel = level
        self.logger = logger
    }
}

internal func handleMongocStructuredLogMessage(entry: OpaquePointer!, _: UnsafeMutableRawPointer?) {
    let component = mongoc_structured_log_entry_get_component(entry).swiftLogComponent
    let level = mongoc_structured_log_entry_get_level(entry).swiftLogLevel

    let logger: Logger
    switch component {
    case .command:
        guard let commandLogger = CommandLogger.global.logger, level >= commandLogger.logLevel else {
            return
        }
        logger = commandLogger
    case .connection:
        guard let connLogger = ConnectionLogger.global.logger, level >= connLogger.logLevel else {
            return
        }
        logger = connLogger
    default:
        fatalError("unrecognized component \(component)")
    }
    
    let msg = BSONDocument(copying: mongoc_structured_log_entry_get_message(entry))
    logger.log(
        level: level,
        "\(msg["message"]!.stringValue!)",
        metadata: msg.toLoggerMetadata()
    )
}

extension BSONDocument {
    fileprivate func toLoggerMetadata() -> Logger.Metadata {
        var metadata = Logger.Metadata()
        for (k, v) in self where k != "message" {
            metadata[k] = "\(v.bsonValue)"
        }
        return metadata
    }
}

// No-op handler to prevent libmongoc from auto-logging to stderr.
internal func handleMongocLogMessage(
    level _: mongoc_log_level_t,
    domain _: UnsafePointer<CChar>?,
    message _: UnsafePointer<CChar>?,
    userInfo _: UnsafeMutableRawPointer?
) {}
