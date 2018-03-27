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
    /// The command.
    let command: Document

    /// The database name.
    let databaseName: String

    /// The command name.
    let commandName: String

    /// The driver generated request id.
    let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    let operationId: Int64?

    /// The connection id for the command.
    let connectionId: ConnectionId

    /// An internal initializer for creating a CommandStartedEvent from a mongoc_apm_command_started_t
    internal init(_ event: OpaquePointer) {
        let commandData = UnsafeMutablePointer(mutating: mongoc_apm_command_started_get_command(event)!)
        self.command = Document(fromPointer: commandData)
        self.databaseName = String(cString: mongoc_apm_command_started_get_database_name(event))
        self.commandName = String(cString: mongoc_apm_command_started_get_command_name(event))
        self.requestId = mongoc_apm_command_started_get_request_id(event)
        self.operationId = mongoc_apm_command_started_get_operation_id(event)
        self.connectionId = ConnectionId(mongoc_apm_command_started_get_host(event))
    }
}

/// An event published when a command succeeds. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandSucceeded.
public struct CommandSucceededEvent {
    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The command reply.
    let reply: Document

    /// The command name.
    let commandName: String

    /// The driver generated request id.
    let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    let operationId: Int64?

    /// The connection id for the command.
    let connectionId: ConnectionId

    /// An internal initializer for creating a CommandSucceededEvent from a mongoc_apm_command_succeeded_t
    internal init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_command_succeeded_get_duration(event)
        let replyData = UnsafeMutablePointer(mutating: mongoc_apm_command_succeeded_get_reply(event)!)
        self.reply = Document(fromPointer: replyData)
        self.commandName = String(cString: mongoc_apm_command_succeeded_get_command_name(event))
        self.requestId = mongoc_apm_command_succeeded_get_request_id(event)
        self.operationId = mongoc_apm_command_succeeded_get_operation_id(event)
        self.connectionId = ConnectionId(mongoc_apm_command_succeeded_get_host(event))
    }
}

/// An event published when a command fails. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandFailed.
public struct CommandFailedEvent {

    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The command name.
    let commandName: String

    /// The failure, represented as a MongoError.
    let failure: MongoError

    /// The client generated request id.
    let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    let operationId: Int64?

    /// The connection id for the command.
    let connectionId: ConnectionId

    /// An internal initializer for creating a CommandFailedEvent from a mongoc_apm_command_failed_t
    internal init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_command_failed_get_duration(event)
        self.commandName = String(cString: mongoc_apm_command_failed_get_command_name(event))
        var error = bson_error_t()
        mongoc_apm_command_failed_get_error(event, &error)
        self.failure = MongoError.commandError(message: toErrorString(error))
        self.requestId = mongoc_apm_command_failed_get_request_id(event)
        self.operationId = mongoc_apm_command_failed_get_operation_id(event)
        self.connectionId = ConnectionId(mongoc_apm_command_failed_get_host(event))
    }
}

/// An internal callback that will be set for "command started" events if the user
/// enables those notifications. This function generates a new `Notification` and posts
/// it to the NotificationCenter specified when calling `MongoClient.enableCommandMonitoring`.
internal func commandStarted(_event: OpaquePointer?) {
    guard let event = _event else {
        preconditionFailure("Missing event pointer for CommandStartedEvent")
    }
    let eventStruct = CommandStartedEvent(event)
    let notification = Notification(name: .commandStarted, userInfo: ["event": eventStruct])
    guard let context = mongoc_apm_command_started_get_context(event) else {
        preconditionFailure("Missing context for CommandStartedEvent")
    }
    let center = Unmanaged<NotificationCenter>.fromOpaque(context).takeUnretainedValue()
    center.post(notification)
}

/// An internal callback that will be set for "command succeeded" events if the user
/// enables those notifications. This function generates a new `Notification` and posts
/// it to the NotificationCenter specified when calling `MongoClient.enableCommandMonitoring`.
internal func commandSucceeded(_event: OpaquePointer?) {
    guard let event = _event else {
        preconditionFailure("Missing event pointer for CommandSucceededEvent")
    }
    let eventStruct = CommandSucceededEvent(event)
    let notification = Notification(name: .commandSucceeded, userInfo: ["event": eventStruct])
    guard let context = mongoc_apm_command_succeeded_get_context(event) else {
        preconditionFailure("Missing context for CommandSucceededEvent")
    }
    let center = Unmanaged<NotificationCenter>.fromOpaque(context).takeUnretainedValue()
    center.post(notification)
}

/// An internal callback that will be set for "command failed" events if the user
/// enables those notifications. This function generates a new `Notification` and posts
/// it to the NotificationCenter specified when calling `MongoClient.enableCommandMonitoring`.
internal func commandFailed(_event: OpaquePointer?) {
    guard let event = _event else {
        preconditionFailure("Missing event pointer for CommandFailedEvent")
    }
    let eventStruct = CommandFailedEvent(event)
    let notification = Notification(name: .commandFailed, userInfo: ["event": eventStruct])
    guard let context = mongoc_apm_command_failed_get_context(event) else {
        preconditionFailure("Missing context for CommandFailedEvent")
    }
    let center = Unmanaged<NotificationCenter>.fromOpaque(context).takeUnretainedValue()
    center.post(notification)
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
    /*
     *  Enables command monitoring for this client, meaning notifications
     *  about command events will be posted to the supplied NotificationCenter -
     *  or if one is not provided, the default NotificationCenter.
     *  If no specific event types are provided, all events will be posted.
     *  Notifications can only be enabled for a single NotificationCenter at a time.
     *
     *  Calling this function will reset all previously enabled events - i.e.
     *  calling
     *      client.enableNotifications(forEvents: [.commandStarted])
     *      client.enableNotifications(forEvents: [.commandSucceeded])
     *
     *  will result in only posting notifications for .commandSucceeded events.
     */
    public func enableCommandMonitoring(
        forEvents events: [MongoEvent] = [.commandStarted, .commandSucceeded, .commandFailed],
        usingCenter center: NotificationCenter = NotificationCenter.default) {
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
        self.notificationCenter = center
        mongoc_client_set_apm_callbacks(self._client, callbacks, Unmanaged.passUnretained(center).toOpaque())
        mongoc_apm_callbacks_destroy(callbacks)
    }

    /// Disables all notification types for this client.
    public func disableCommandMonitoring() {
        mongoc_client_set_apm_callbacks(self._client, nil, nil)
        self.notificationCenter = nil
    }
}
