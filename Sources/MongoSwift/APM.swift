import CLibMongoC
import Foundation

/// A protocol for `CommandEvent` handlers to implement.
public protocol CommandEventHandler: AnyObject {
    /// Handle a `CommandEvent`.
    func handleCommandEvent(_ event: CommandEvent)
}

/// A protocol for handlers of events relating to SDAM to implement.
public protocol SDAMEventHandler: AnyObject {
    /// Handle an `SDAMEvent`.
    func handleSDAMEvent(_ event: SDAMEvent)
}

/// A protocol for events that are directly consumable by users to implement.
private protocol Publishable {
    func publish(to client: MongoClient)
}

/// A protocol for monitoring events to implement, indicating that they can be initialized from a libmongoc event
/// and that they can be packaged into a type which can be published.
private protocol MongoSwiftEvent {
    associatedtype MongocEventType: MongocEvent
    associatedtype PublishableEventType: Publishable

    init(mongocEvent: MongocEventType)

    func toPublishable() -> PublishableEventType
}

/// A protocol for libmongoc event wrappers to implement.
private protocol MongocEvent {
    init(_ eventPtr: OpaquePointer)

    var context: UnsafeMutableRawPointer? { get }
}

/// A command monitoring event.
public enum CommandEvent: Publishable {
    /// An event published when a command starts.
    case started(CommandStartedEvent)

    /// An event published when a command succeeds.
    case succeeded(CommandSucceededEvent)

    /// An event published when a command fails.
    case failed(CommandFailedEvent)

    private var event: CommandEventProtocol {
        switch self {
        case let .started(event):
            return event
        case let .succeeded(event):
            return event
        case let .failed(event):
            return event
        }
    }

    fileprivate func publish(to client: MongoClient) {
        client.commandEventHandlers.forEach { handler in
            handler.handleCommandEvent(self)
        }
    }

    /// The name of the command that generated this event.
    public var commandName: String {
        return self.event.commandName
    }

    /// The driver generated request id.
    public var requestId: Int64 {
        return self.event.requestId
    }

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    public var operationId: Int64 {
        return self.event.operationId
    }

    /// The address of the server the command was run against.
    public var serverAddress: Address {
        return self.event.serverAddress
    }
}

/// A protocol for command monitoring events to implement, specifying the command name and other shared fields.
private protocol CommandEventProtocol {
    /// The command name.
    var commandName: String { get }

    /// The driver generated request id.
    var requestId: Int64 { get }

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    var operationId: Int64 { get }

    /// The address of the server the command was run against.
    var serverAddress: Address { get }
}

/// An event published when a command starts.
public struct CommandStartedEvent: MongoSwiftEvent, CommandEventProtocol {
    /// Wrapper around a `mongoc_apm_command_started_t`.
    fileprivate struct MongocCommandStartedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_command_started_get_context(self.ptr)
        }
    }

    /// The command.
    public let command: Document

    /// The database name.
    public let databaseName: String

    /// The command name.
    public let commandName: String

    /// The driver generated request id.
    public let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    public let operationId: Int64

    /// The address of the server the command was run against.
    public let serverAddress: Address

    fileprivate init(mongocEvent: MongocCommandStartedEvent) {
        // we have to copy because libmongoc owns the pointer.
        self.command = Document(copying: mongoc_apm_command_started_get_command(mongocEvent.ptr))
        self.databaseName = String(cString: mongoc_apm_command_started_get_database_name(mongocEvent.ptr))
        self.commandName = String(cString: mongoc_apm_command_started_get_command_name(mongocEvent.ptr))
        self.requestId = mongoc_apm_command_started_get_request_id(mongocEvent.ptr)
        self.operationId = mongoc_apm_command_started_get_operation_id(mongocEvent.ptr)
        self.serverAddress = Address(mongoc_apm_command_started_get_host(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> CommandEvent {
        return .started(self)
    }
}

/// An event published when a command succeeds.
public struct CommandSucceededEvent: MongoSwiftEvent, CommandEventProtocol {
    /// Wrapper around a `mongoc_apm_command_succeeded_t`.
    fileprivate struct MongocCommandSucceededEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_command_succeeded_get_context(self.ptr)
        }
    }

    /// The execution time of the event, in microseconds.
    public let duration: Int64

    /// The command reply.
    public let reply: Document

    /// The command name.
    public let commandName: String

    /// The driver generated request id.
    public let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    public let operationId: Int64

    /// The address of the server the command was run against.
    public let serverAddress: Address

    fileprivate init(mongocEvent: MongocCommandSucceededEvent) {
        self.duration = mongoc_apm_command_succeeded_get_duration(mongocEvent.ptr)
        // we have to copy because libmongoc owns the pointer.
        self.reply = Document(copying: mongoc_apm_command_succeeded_get_reply(mongocEvent.ptr))
        self.commandName = String(cString: mongoc_apm_command_succeeded_get_command_name(mongocEvent.ptr))
        self.requestId = mongoc_apm_command_succeeded_get_request_id(mongocEvent.ptr)
        self.operationId = mongoc_apm_command_succeeded_get_operation_id(mongocEvent.ptr)
        self.serverAddress = Address(mongoc_apm_command_succeeded_get_host(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> CommandEvent {
        return .succeeded(self)
    }
}

/// An event published when a command fails.
public struct CommandFailedEvent: MongoSwiftEvent, CommandEventProtocol {
    /// Wrapper around a `mongoc_apm_command_failed_t`.
    fileprivate struct MongocCommandFailedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_command_failed_get_context(self.ptr)
        }
    }

    /// The execution time of the event, in microseconds.
    public let duration: Int64

    /// The command name.
    public let commandName: String

    /// The failure, represented as a MongoError.
    public let failure: MongoError

    /// The client generated request id.
    public let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    public let operationId: Int64

    /// The connection id for the command.
    public let serverAddress: Address

    fileprivate init(mongocEvent: MongocCommandFailedEvent) {
        self.duration = mongoc_apm_command_failed_get_duration(mongocEvent.ptr)
        self.commandName = String(cString: mongoc_apm_command_failed_get_command_name(mongocEvent.ptr))
        var error = bson_error_t()
        mongoc_apm_command_failed_get_error(mongocEvent.ptr, &error)
        let reply = Document(copying: mongoc_apm_command_failed_get_reply(mongocEvent.ptr))
        self.failure = extractMongoError(error: error, reply: reply) // should always return a CommandError
        self.requestId = mongoc_apm_command_failed_get_request_id(mongocEvent.ptr)
        self.operationId = mongoc_apm_command_failed_get_operation_id(mongocEvent.ptr)
        self.serverAddress = Address(mongoc_apm_command_failed_get_host(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> CommandEvent {
        return .failed(self)
    }
}

/// An SDAM monitoring event related to topology updates.
public enum SDAMEvent: Publishable {
    /// Published when a topology description changes.
    case topologyDescriptionChanged(TopologyDescriptionChangedEvent)

    /// Published when a topology is initialized.
    case topologyOpening(TopologyOpeningEvent)

    /// Published when a topology is shut down.
    case topologyClosed(TopologyClosedEvent)

    /// Published when a topology's information about a server changes.
    case serverDescriptionChanged(ServerDescriptionChangedEvent)

    /// Published when information about a new server is discovered.
    case serverOpening(ServerOpeningEvent)

    /// Published when a server is removed from a topology and no longer monitored.
    case serverClosed(ServerClosedEvent)

    /// Published when the server monitor’s ismaster command is started - immediately before
    /// the ismaster command is serialized into raw BSON and written to the socket.
    case serverHeartbeatStarted(ServerHeartbeatStartedEvent)

    /// Published when the server monitor’s ismaster succeeds.
    case serverHeartbeatSucceeded(ServerHeartbeatSucceededEvent)

    /// Published when the server monitor’s ismaster fails, either with an “ok: 0” or a socket exception.
    case serverHeartbeatFailed(ServerHeartbeatFailedEvent)

    fileprivate func publish(to client: MongoClient) {
        client.sdamEventHandlers.forEach { handler in
            handler.handleSDAMEvent(self)
        }
    }
}

/// Published when a server description changes. This does NOT include changes to the server's roundTripTime property.
public struct ServerDescriptionChangedEvent: MongoSwiftEvent {
    /// Wrapper around a `mongoc_apm_server_changed_t`.
    fileprivate struct MongocServerChangedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_server_changed_get_context(self.ptr)
        }
    }

    /// The connection ID (host/port pair) of the server.
    public let serverAddress: Address

    /// A unique identifier for the topology.
    public let topologyId: ObjectId

    /// The previous server description.
    public let previousDescription: ServerDescription

    /// The new server description.
    public let newDescription: ServerDescription

    fileprivate init(mongocEvent: MongocServerChangedEvent) {
        self.serverAddress = Address(mongoc_apm_server_changed_get_host(mongocEvent.ptr))
        var oid = bson_oid_t()
        withUnsafeMutablePointer(to: &oid) { oidPtr in
            mongoc_apm_server_changed_get_topology_id(mongocEvent.ptr, oidPtr)
        }
        self.topologyId = ObjectId(bsonOid: oid)
        self.previousDescription =
            ServerDescription(mongoc_apm_server_changed_get_previous_description(mongocEvent.ptr))
        self.newDescription = ServerDescription(mongoc_apm_server_changed_get_new_description(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .serverDescriptionChanged(self)
    }
}

/// Published when a server is initialized.
public struct ServerOpeningEvent: MongoSwiftEvent {
    /// Wrapper around a `mongoc_apm_server_opening_t`.
    fileprivate struct MongocServerOpeningEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_server_opening_get_context(self.ptr)
        }
    }

    /// The connection ID (host/port pair) of the server.
    public let serverAddress: Address

    /// A unique identifier for the topology.
    public let topologyId: ObjectId

    fileprivate init(mongocEvent: MongocServerOpeningEvent) {
        self.serverAddress = Address(mongoc_apm_server_opening_get_host(mongocEvent.ptr))
        var oid = bson_oid_t()
        withUnsafeMutablePointer(to: &oid) { oidPtr in
            mongoc_apm_server_opening_get_topology_id(mongocEvent.ptr, oidPtr)
        }
        self.topologyId = ObjectId(bsonOid: oid)
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .serverOpening(self)
    }
}

/// Published when a server is closed.
public struct ServerClosedEvent: MongoSwiftEvent {
    /// Wrapper around a `mongoc_apm_server_closed_t`.
    fileprivate struct MongocServerClosedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_server_closed_get_context(self.ptr)
        }
    }

    /// The connection ID (host/port pair) of the server.
    public let serverAddress: Address

    /// A unique identifier for the topology.
    public let topologyId: ObjectId

    fileprivate init(mongocEvent: MongocServerClosedEvent) {
        self.serverAddress = Address(mongoc_apm_server_closed_get_host(mongocEvent.ptr))
        var oid = bson_oid_t()
        withUnsafeMutablePointer(to: &oid) { oidPtr in
            mongoc_apm_server_closed_get_topology_id(mongocEvent.ptr, oidPtr)
        }
        self.topologyId = ObjectId(bsonOid: oid)
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .serverClosed(self)
    }
}

/// Published when a topology description changes.
public struct TopologyDescriptionChangedEvent: MongoSwiftEvent {
    /// Wrapper around a mongoc_apm_topology_changed_t.
    fileprivate struct MongocTopologyChangedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_topology_changed_get_context(self.ptr)
        }
    }

    /// A unique identifier for the topology.
    public let topologyId: ObjectId

    /// The old topology description.
    public let previousDescription: TopologyDescription

    /// The new topology description.
    public let newDescription: TopologyDescription

    fileprivate init(mongocEvent: MongocTopologyChangedEvent) {
        var oid = bson_oid_t()
        withUnsafeMutablePointer(to: &oid) { oidPtr in
            mongoc_apm_topology_changed_get_topology_id(mongocEvent.ptr, oidPtr)
        }
        self.topologyId = ObjectId(bsonOid: oid)
        self.previousDescription =
            TopologyDescription(mongoc_apm_topology_changed_get_previous_description(mongocEvent.ptr))
        self.newDescription = TopologyDescription(mongoc_apm_topology_changed_get_new_description(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .topologyDescriptionChanged(self)
    }
}

/// Published when a topology is initialized.
public struct TopologyOpeningEvent: MongoSwiftEvent {
    /// Wrapper around a mongoc_apm_topology_opening_t.
    fileprivate struct MongocTopologyOpeningEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_topology_opening_get_context(self.ptr)
        }
    }

    /// A unique identifier for the topology.
    public let topologyId: ObjectId

    fileprivate init(mongocEvent: MongocTopologyOpeningEvent) {
        var oid = bson_oid_t()
        withUnsafeMutablePointer(to: &oid) { oidPtr in
            mongoc_apm_topology_opening_get_topology_id(mongocEvent.ptr, oidPtr)
        }
        self.topologyId = ObjectId(bsonOid: oid)
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .topologyOpening(self)
    }
}

/// Published when a topology is closed.
public struct TopologyClosedEvent: MongoSwiftEvent {
    /// Wrapper around a mongoc_apm_topology_closed_t.
    fileprivate struct MongocTopologyClosedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_topology_closed_get_context(self.ptr)
        }
    }

    /// A unique identifier for the topology.
    public let topologyId: ObjectId

    fileprivate init(mongocEvent: MongocTopologyClosedEvent) {
        var oid = bson_oid_t()
        withUnsafeMutablePointer(to: &oid) { oidPtr in
            mongoc_apm_topology_closed_get_topology_id(mongocEvent.ptr, oidPtr)
        }
        self.topologyId = ObjectId(bsonOid: oid)
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .topologyClosed(self)
    }
}

/// Published when the server monitor’s ismaster command is started - immediately before
/// the ismaster command is serialized into raw BSON and written to the socket.
public struct ServerHeartbeatStartedEvent: MongoSwiftEvent {
    /// Wrapper around a `mongoc_apm_server_heartbeat_started_t`.
    fileprivate struct MongocServerHeartbeatStartedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_server_heartbeat_started_get_context(self.ptr)
        }
    }

    /// The address of the server.
    public let serverAddress: Address

    fileprivate init(mongocEvent: MongocServerHeartbeatStartedEvent) {
        self.serverAddress = Address(mongoc_apm_server_heartbeat_started_get_host(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .serverHeartbeatStarted(self)
    }
}

/// Published when the server monitor’s ismaster succeeds.
public struct ServerHeartbeatSucceededEvent: MongoSwiftEvent {
    /// Wrapper around a `mongoc_apm_server_heartbeat_succeeded_t`.
    fileprivate struct MongocServerHeartbeatSucceededEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_server_heartbeat_succeeded_get_context(self.ptr)
        }
    }

    /// The execution time of the event, in microseconds.
    public let duration: Int64

    /// The command reply.
    public let reply: Document

    /// The address of the server.
    public let serverAddress: Address

    fileprivate init(mongocEvent: MongocServerHeartbeatSucceededEvent) {
        self.duration = mongoc_apm_server_heartbeat_succeeded_get_duration(mongocEvent.ptr)
        // we have to copy because libmongoc owns the pointer.
        self.reply = Document(copying: mongoc_apm_server_heartbeat_succeeded_get_reply(mongocEvent.ptr))
        self.serverAddress = Address(mongoc_apm_server_heartbeat_succeeded_get_host(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .serverHeartbeatSucceeded(self)
    }
}

/// Published when the server monitor’s ismaster fails, either with an “ok: 0” or a socket exception.
public struct ServerHeartbeatFailedEvent: MongoSwiftEvent {
    /// Wrapper around a `mongoc_apm_server_heartbeat_failed_t`.
    fileprivate struct MongocServerHeartbeatFailedEvent: MongocEvent {
        fileprivate let ptr: OpaquePointer

        fileprivate init(_ eventPtr: OpaquePointer) {
            self.ptr = eventPtr
        }

        fileprivate var context: UnsafeMutableRawPointer? {
            return mongoc_apm_server_heartbeat_failed_get_context(self.ptr)
        }
    }

    /// The execution time of the event, in microseconds.
    public let duration: Int64

    /// The failure.
    public let failure: MongoError

    /// The address of the server.
    public let serverAddress: Address

    fileprivate init(mongocEvent: MongocServerHeartbeatFailedEvent) {
        self.duration = mongoc_apm_server_heartbeat_failed_get_duration(mongocEvent.ptr)
        var error = bson_error_t()
        mongoc_apm_server_heartbeat_failed_get_error(mongocEvent.ptr, &error)
        self.failure = extractMongoError(error: error)
        self.serverAddress = Address(mongoc_apm_server_heartbeat_failed_get_host(mongocEvent.ptr))
    }

    fileprivate func toPublishable() -> SDAMEvent {
        return .serverHeartbeatFailed(self)
    }
}

/// Callbacks that will be set for events with the corresponding names if the user enables
/// monitoring for those events. These functions will parse the libmongoc events and publish the results
/// to the user-specified event handler.

/// A callback that will be set for "command started" events if the user enables command monitoring.
private func commandStarted(_ eventPtr: OpaquePointer?) {
    publishEvent(type: CommandStartedEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "command succeeded" events if the user enables command monitoring.
private func commandSucceeded(_ eventPtr: OpaquePointer?) {
    publishEvent(type: CommandSucceededEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "command failed" events if the user enables command monitoring.
private func commandFailed(_ eventPtr: OpaquePointer?) {
    publishEvent(type: CommandFailedEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "server description changed" events if the user enables server monitoring.
private func serverDescriptionChanged(_ eventPtr: OpaquePointer?) {
    publishEvent(type: ServerDescriptionChangedEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "server opening" events if the user enables server monitoring.
private func serverOpening(_ eventPtr: OpaquePointer?) {
    publishEvent(type: ServerOpeningEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "server closed" events if the user enables server monitoring.
private func serverClosed(_ eventPtr: OpaquePointer?) {
    publishEvent(type: ServerClosedEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "topology description changed" events if the user enables server monitoring.
private func topologyDescriptionChanged(_ eventPtr: OpaquePointer?) {
    publishEvent(type: TopologyDescriptionChangedEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "topology opening" events if the user enables server monitoring.
private func topologyOpening(_ eventPtr: OpaquePointer?) {
    publishEvent(type: TopologyOpeningEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "topology closed" events if the user enables server monitoring.
private func topologyClosed(_ eventPtr: OpaquePointer?) {
    publishEvent(type: TopologyClosedEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "server heartbeat started" events if the user enables server monitoring.
private func serverHeartbeatStarted(_ eventPtr: OpaquePointer?) {
    publishEvent(type: ServerHeartbeatStartedEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "server heartbeat succeeded" events if the user enables server monitoring.
private func serverHeartbeatSucceeded(_ eventPtr: OpaquePointer?) {
    publishEvent(type: ServerHeartbeatSucceededEvent.self, eventPtr: eventPtr)
}

/// A callback that will be set for "server heartbeat failed" events if the user enables server monitoring.
private func serverHeartbeatFailed(_ eventPtr: OpaquePointer?) {
    publishEvent(type: ServerHeartbeatFailedEvent.self, eventPtr: eventPtr)
}

/// Publish an event to the client responsible for this event.
private func publishEvent<T: MongoSwiftEvent>(type: T.Type, eventPtr: OpaquePointer?) {
    guard let eventPtr = eventPtr else {
        fatalError("Missing event pointer for \(type)")
    }
    // The underlying pointer is only valid within the registered callback, so this event should not escape this scope.
    let mongocEvent = type.MongocEventType(eventPtr)

    guard let context = mongocEvent.context else {
        fatalError("Missing context for \(type)")
    }
    let client = Unmanaged<MongoClient>.fromOpaque(context).takeUnretainedValue()

    let event = type.init(mongocEvent: mongocEvent)

    // TODO: SWIFT-524: remove workaround for CDRIVER-3256
    if let tdChanged = event as? TopologyDescriptionChangedEvent,
        tdChanged.previousDescription == tdChanged.newDescription {
        return
    }

    if let sdChanged = event as? ServerDescriptionChangedEvent,
        sdChanged.previousDescription == sdChanged.newDescription {
        return
    }

    event.toPublishable().publish(to: client)
}

/// An extension of `ConnectionPool` to add monitoring capability for commands and server discovery and monitoring.
extension ConnectionPool {
    /// Internal function to install monitoring callbacks for this pool.
    internal func initializeMonitoring(client: MongoClient) {
        guard let callbacks = mongoc_apm_callbacks_new() else {
            fatalError("failed to initialize new mongoc_apm_callbacks_t")
        }
        defer { mongoc_apm_callbacks_destroy(callbacks) }

        mongoc_apm_set_command_started_cb(callbacks, commandStarted)
        mongoc_apm_set_command_succeeded_cb(callbacks, commandSucceeded)
        mongoc_apm_set_command_failed_cb(callbacks, commandFailed)

        mongoc_apm_set_server_changed_cb(callbacks, serverDescriptionChanged)
        mongoc_apm_set_server_opening_cb(callbacks, serverOpening)
        mongoc_apm_set_server_closed_cb(callbacks, serverClosed)
        mongoc_apm_set_topology_changed_cb(callbacks, topologyDescriptionChanged)
        mongoc_apm_set_topology_opening_cb(callbacks, topologyOpening)
        mongoc_apm_set_topology_closed_cb(callbacks, topologyClosed)
        mongoc_apm_set_server_heartbeat_started_cb(callbacks, serverHeartbeatStarted)
        mongoc_apm_set_server_heartbeat_succeeded_cb(callbacks, serverHeartbeatSucceeded)
        mongoc_apm_set_server_heartbeat_failed_cb(callbacks, serverHeartbeatFailed)

        // we can pass the MongoClient as unretained because the callbacks are stored on clientHandle, so if the
        // callback is being executed, this pool and therefore its parent `MongoClient` must still be valid.
        switch self.state {
        case let .open(pool):
            mongoc_client_pool_set_apm_callbacks(pool, callbacks, Unmanaged.passUnretained(client).toOpaque())
        case .closed:
            fatalError("ConnectionPool was already closed")
        }
    }
}
