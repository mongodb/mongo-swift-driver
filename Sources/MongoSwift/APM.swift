import Foundation
import libmongoc

/// A struct representing a server connection, consisting of a host and port.
public struct ConnectionId {
    let host: String
    let port: UInt16

    internal init(_ hostList: UnsafePointer<mongoc_host_list_t>) {
        var hostData = hostList.pointee
        self.host = withUnsafeBytes(of: &hostData.host) { (rawPtr) -> String in
            let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
            return String(cString: ptr)
        }
        self.port = hostData.port
    }
}

/// An event published when a command starts. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandStarted.
public struct CommandStartedEvent {
    /// An internal opaque pointer to a mongoc_apm_command_started_t 
    internal let _event: OpaquePointer

    /// An internal initializer for a CommandStartedEvent
    internal init(_ event: OpaquePointer) {
        self._event = event
    }

    /// The command.
    var command: Document {
        let commandData = UnsafeMutablePointer(mutating: mongoc_apm_command_started_get_command(self._event)!)
        return Document(fromPointer: commandData)
    }

    /// The database name.
    var databaseName: String { return String(cString: mongoc_apm_command_started_get_database_name(self._event)) }

    /// The command name.
    var commandName: String { return String(cString: mongoc_apm_command_started_get_command_name(self._event)) }

    /// The driver generated request id.
    var requestId: Int64 { return mongoc_apm_command_started_get_request_id(self._event) }

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    var operationId: Int64? { return mongoc_apm_command_started_get_operation_id(self._event) }

    /// The connection id for the command.
    var connectionId: ConnectionId { return ConnectionId(mongoc_apm_command_started_get_host(self._event)) }
}

/// An event published when a command succeed. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandSucceeded.
public struct CommandSucceededEvent {
    /// An internal opaque pointer to a mongoc_apm_command_succeeded_t 
    internal let _event: OpaquePointer

    /// An internal initializer for a CommandSucceededEvent
    internal init(_ event: OpaquePointer) {
        self._event = event
    }

    /// The execution time of the event, in microseconds.
    var duration: Int64 { return mongoc_apm_command_succeeded_get_duration(self._event) }

    /// The command reply.
    var reply: Document {
        let replyData = UnsafeMutablePointer(mutating: mongoc_apm_command_succeeded_get_reply(self._event)!)
        return Document(fromPointer: replyData)
    }

    /// The command name.
    var commandName: String { return String(cString: mongoc_apm_command_succeeded_get_command_name(self._event)) }

    /// The driver generated request id.
    var requestId: Int64 { return mongoc_apm_command_succeeded_get_request_id(self._event) }

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    var operationId: Int64? { return mongoc_apm_command_succeeded_get_operation_id(self._event) }

    /// The connection id for the command.
    var connectionId: ConnectionId { return ConnectionId(mongoc_apm_command_succeeded_get_host(self._event)) }
}

/// An event published when a command fails. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandFailed.
public struct CommandFailedEvent {
    /// An internal opaque pointer to a mongoc_apm_command_failed_t 
    internal let _event: OpaquePointer

    /// An internal initializer for a CommandFailedEvent
    internal init(_ event: OpaquePointer) {
        self._event = event
    }

    /// The execution time of the event, in microseconds.
    var duration: Int64 { return mongoc_apm_command_failed_get_duration(self._event) }

    /// The command name.
    var commandName: String { return String(cString: mongoc_apm_command_failed_get_command_name(self._event)) }

    /// The failure, represented as a MongoError. 
    var failure: MongoError {
        var error = bson_error_t()
        mongoc_apm_command_failed_get_error(self._event, &error)
        return MongoError.commandError(message: toErrorString(error))
    }

    /// The client generated request id.
    var requestId: Int64 { return mongoc_apm_command_failed_get_request_id(self._event) }

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    var operationId: Int64? { return mongoc_apm_command_failed_get_operation_id(self._event) }

    /// The connection id for the command.
    var connectionId: ConnectionId { return ConnectionId(mongoc_apm_command_failed_get_host(self._event)) }
}

/// An internal callback that will be set for "command started" events if the user 
/// enables those notifications. This function generates a new `Notification` and posts 
/// it to the default NotificationCenter for the app. 
internal func commandStarted(_event: OpaquePointer?) {
    guard let event = _event else { return }
    let eventStruct = CommandStartedEvent(event)
    let notification = Notification(name: .commandStarted, userInfo: ["event": eventStruct])
    NotificationCenter.default.post(notification)
}

/// An internal callback that will be set for "command succeeded" events if the user 
/// enables those notifications. This function generates a new `Notification` and posts 
/// it to the default NotificationCenter for the app. 
internal func commandSucceeded(_event: OpaquePointer?) {
    guard let event = _event else { return }
    let eventStruct = CommandSucceededEvent(event)
    let notification = Notification(name: .commandSucceeded, userInfo: ["event": eventStruct])
    NotificationCenter.default.post(notification)
}

/// An internal callback that will be set for "command failed" events if the user 
/// enables those notifications. This function generates a new `Notification` and posts 
/// it to the default NotificationCenter for the app. 
internal func commandFailed(_event: OpaquePointer?) {
    guard let event = _event else { return }
    let eventStruct = CommandFailedEvent(event)
    let notification = Notification(name: .commandFailed, userInfo: ["event": eventStruct])
    NotificationCenter.default.post(notification)
}

/// Extend Notification.Name to have class properties corresponding to each type 
/// of event. This allows creating notifications and observers using the same ".x" names
/// as those passed into `enableNotifications`. 
extension Notification.Name {
    static let commandStarted = Notification.Name(MongoEvent.commandStarted.rawValue)
    static let commandSucceeded = Notification.Name(MongoEvent.commandSucceeded.rawValue)
    static let commandFailed = Notification.Name(MongoEvent.commandFailed.rawValue)
}

/// An enumeration of the events that notifications can be enabled for.
public enum MongoEvent: String {
    case commandStarted
    case commandSucceeded
    case commandFailed
}

/// An extension of MongoClient to add command monitoring and 
/// server discovery and monitoring capabilities. 
extension MongoClient {
    /// Enables notifications for this client, meaning notifications
    /// about command events will be posted to the default NotificationCenter.
    /// If no specific event types are provided, all events will be posted. 
    public func enableNotifications(forEvents events: [MongoEvent] =
        [.commandStarted, .commandSucceeded, .commandFailed]) throws {
        guard let client = self._client else { throw MongoError.invalidClient() }
        let callbacks = mongoc_apm_callbacks_new()
        for event in events {
            switch event {
            case .commandStarted:
                mongoc_apm_set_command_started_cb(callbacks, commandStarted)
            case .commandSucceeded:
                mongoc_apm_set_command_succeeded_cb(callbacks, commandSucceeded)
            case .commandFailed:
                mongoc_apm_set_command_failed_cb(callbacks, commandFailed)
            }
        }
        mongoc_client_set_apm_callbacks(client, callbacks, nil)
        mongoc_apm_callbacks_destroy(callbacks)
    }

    /// Disables all notification types for this client.
    public func disableNotifications() throws {
        guard let client = self._client else { throw MongoError.invalidClient() }
        mongoc_client_set_apm_callbacks(client, nil, nil)
    }
}
