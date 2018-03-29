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

    internal init(_ hostAndPort: String) {
        print("HOSTANDPORT: \(hostAndPort)")
        let parts = hostAndPort.split(separator: ":")
        self.host = String(parts[0])
        self.port = UInt16(parts[1])!
    }

    /// Initializes a ConnectionId at localhost:27017, the default host/port.
    internal init() {
        self.host = "localhost"
        self.port = 27017
    }
}

/// The possible types for a server. The raw values correspond to the values libmongoc uses. 
/// (We don't use these strings directly because Swift convention is to use lowercase enums.)
public enum ServerType: String {
    case standalone = "Standalone"
    case mongos = "Mongos"
    case possiblePrimary = "PossiblePrimary"
    case rsPrimary = "RSPrimary"
    case rsSecondary = "RSSecondary"
    case rsArbiter = "RSArbiter"
    case rsOther = "RSOther"
    case rsGhost = "RSGhost"
    case unknown = "Unknown"
}

/// A struct describing a mongod or mongos process.
public struct ServerDescription {
    /// The hostname or IP and the port number that the client connects to. Note that this is not the
    /// server's ismaster.me field, in the case that the server reports an address different from the 
    /// address the client uses.
    let connectionId: ConnectionId

    /// The last error related to this server.
    let error: MongoError? = nil // currently we will never set this

    /// The duration of the server's last ismaster call.
    var roundTripTime: Int64?

    /// The "lastWriteDate" from the server's most recent ismaster response.
    var lastWriteDate: Date?

    /// The last opTime reported by the server. Only mongos and shard servers 
    /// record this field when monitoring config servers as replica sets.
    var opTime: ObjectId?

    /// The type of this server.
    var type: ServerType = .unknown

    /// The wire protocol version range supported by the server.
    var minWireVersion: Int32 = 0
    var maxWireVersion: Int32 = 0

    /// The hostname or IP and the port number that this server was configured with in the replica set.
    var me: ConnectionId?

    /// Hosts, arbiters, passives: sets of addresses. This server's opinion of the replica set's members, if any.
    var hosts: [ConnectionId] = []
    var arbiters: [ConnectionId] = []
    /// "Passives" are priority-zero replica set members that cannot become primary. 
    /// The client treats them precisely the same as other members.
    var passives: [ConnectionId] = []

    /// Tags for this server.
    var tags: [String: String] = [:]

    /// The replica set name.
    var setName: String?

    /// The replica set version.
    var setVersion: Int64?

    /// The election ID where this server was elected, if this is a replica set member that believes it is primary.
    var electionId: ObjectId?

    /// This server's opinion of who the primary is. 
    var primary: ConnectionId?

    /// When this server was last checked.
    let lastUpdateTime: Date? = nil // currently, this will never be set

    /// The logicalSessionTimeoutMinutes value for this server.
    var logicalSessionTimeoutMinutes: Int64?

    internal init(connectionId: ConnectionId) {
        self.connectionId = connectionId
    }

    internal init(_ description: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_server_description_host(description))
        self.roundTripTime = mongoc_server_description_round_trip_time(description)

        let isMasterData =  UnsafeMutablePointer(mutating: mongoc_server_description_ismaster(description)!)
        let isMaster = Document(fromPointer: isMasterData)

        if let lastWrite = isMaster["lastWrite"] as? Document {
            self.lastWriteDate = lastWrite["lastWriteDate"] as? Date
            self.opTime = lastWrite["opTime"] as? ObjectId
        }

        let serverType = String(cString: mongoc_server_description_type(description))
        self.type = ServerType(rawValue: serverType)!

        if let minVersion = isMaster["minWireVersion"] as? Int32 {
            self.minWireVersion = minVersion
        }

        if let maxVersion = isMaster["maxWireVersion"] as? Int32 {
            self.maxWireVersion = maxVersion
        }

        if let me = isMaster["me"] as? String {
            self.me = ConnectionId(me)
        }

        if let hosts = isMaster["hosts"] as? [String] {
            self.hosts = hosts.map { ConnectionId($0) }
        }

        if let passives = isMaster["passives"] as? [String] {
            self.passives = passives.map { ConnectionId($0) }
        }

        if let arbiters = isMaster["arbiters"] as? [String] {
            self.arbiters = arbiters.map { ConnectionId($0) }
        }

        if let tags = isMaster["tags"] as? Document {
            for (k, v) in tags {
                self.tags[k] = v as? String
            }
        }

        self.setName = isMaster["setName"] as? String
        self.setVersion = isMaster["setVersion"] as? Int64
        self.electionId = isMaster["electionId"] as? ObjectId

        if let primary = isMaster["primary"] as? String {
            self.primary = ConnectionId(primary)
        }

        self.logicalSessionTimeoutMinutes = isMaster["logicalSessionTimeoutMinutes"] as? Int64

    }
}

/// The possible types for a topology. The raw values correspond to the values libmongoc uses. 
/// (We don't use these strings directly because Swift convention is to use lowercase for enums.)
public enum TopologyType: String {
    case single = "Single"
    case replicaSetNoPrimary = "ReplicaSetNoPrimary"
    case replicaSetWithPrimary = "ReplicaSetWithPrimary"
    case sharded = "Sharded"
    case unknown = "Unknown"
}

/// A struct describing the state of a MongoDB deployment: its type (standalone, replica set, or sharded), 
/// which servers are up, what type of servers they are, which is primary, and so on.
public struct TopologyDescription {
    /// The type of this topology. 
    let type: TopologyType

    /// The replica set name. 
    var setName: String?

    /// The largest setVersion ever reported by a primary.
    var maxSetVersion: Int64?

    /// The largest electionId ever reported by a primary.
    var maxElectionId: ObjectId?

    /// The servers comprising this topology. By default, a single server at localhost:270107.
    var servers: [ServerDescription] = [ServerDescription(connectionId: ConnectionId())]

    /// For single-threaded clients, indicates whether the topology must be re-scanned.
    let stale: Bool = false // currently, this will never be set

    /// Exists if any server's wire protocol version range is incompatible with the client's.
    let compatibilityError: MongoError? = nil // currently, this will never be set

    /// The logicalSessionTimeoutMinutes value for this topology. This value is the minimum
    /// of the logicalSessionTimeoutMinutes values across all the servers in `servers`, 
    /// or nil if any of them are nil.
    var logicalSessionTimeoutMinutes: Int64?

    /// Determines if the topology has a readable server available.
    // (this function should take in an optional ReadPreference, but we have yet to implement that type.) 
    func hasReadableServer() -> Bool {
        return [.single, .replicaSetWithPrimary, .sharded].contains(self.type)
    }

    /// Determines if the topology has a writable server available.
    func hasWritableServer() -> Bool {
        return [.single, .replicaSetWithPrimary].contains(self.type)
    }

    internal init(_ description: OpaquePointer) {

        let topologyType = String(cString: mongoc_topology_description_type(description))
        self.type = TopologyType(rawValue: topologyType)!

        var size = size_t()
        let serverData = mongoc_topology_description_get_servers(description, &size)
        let buffer = UnsafeBufferPointer(start: serverData, count: size)
        if size > 0 {
            self.servers = Array(buffer).map { ServerDescription($0!) }
        }

        self.setName = self.servers[0].setName

        let timeoutValues = self.servers.map { $0.logicalSessionTimeoutMinutes }
        if timeoutValues.contains (where: { $0 == nil }) {
            self.logicalSessionTimeoutMinutes = nil
        } else {
            self.logicalSessionTimeoutMinutes = timeoutValues.map { $0! }.min()
        }
    }
}

/// A protocol for monitoring events to implement, indicating that they can be initialized from an OpaquePointer
/// to the corresponding libmongoc type.
internal protocol Event {
    init(_ event: OpaquePointer)
}

/// An event published when a command starts. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandStarted.
public struct CommandStartedEvent: Event {
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
    let operationId: Int64

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
public struct CommandSucceededEvent: Event {
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
    let operationId: Int64

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
public struct CommandFailedEvent: Event {

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
    let operationId: Int64

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

/// Published when a server description changes. This does NOT include changes to the server's roundTripTime property.
public struct ServerDescriptionChangedEvent: Event {
    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// The previous server description.
    let previousDescription: ServerDescription

    /// The new server description.
    let newDescription: ServerDescription

    internal init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_changed_get_host(event))
        var oid = bson_oid_t()
        mongoc_apm_server_changed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(from: oid)
        self.previousDescription = ServerDescription(mongoc_apm_server_changed_get_previous_description(event))
        self.newDescription = ServerDescription(mongoc_apm_server_changed_get_new_description(event))
    }
}

/// Published when a server is initialized.
public struct ServerOpeningEvent: Event {
    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    internal init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_opening_get_host(event))
        var oid = bson_oid_t()
        mongoc_apm_server_opening_get_topology_id(event, &oid)
        self.topologyId = ObjectId(from: oid)
    }
}

/// Published when a server is closed.
public struct ServerClosedEvent: Event {
    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    internal init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_closed_get_host(event))
        var oid = bson_oid_t()
        mongoc_apm_server_closed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(from: oid)
    }
}

/// Published when a topology description changes.
public struct TopologyDescriptionChangedEvent: Event {
    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// The old topology description.
    let previousDescription: TopologyDescription

    /// The new topology description.
    let newDescription: TopologyDescription

    internal init(_ event: OpaquePointer) {
        var oid = bson_oid_t()
        mongoc_apm_topology_changed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(from: oid)
        self.previousDescription = TopologyDescription(mongoc_apm_topology_changed_get_previous_description(event))
        self.newDescription = TopologyDescription(mongoc_apm_topology_changed_get_new_description(event))
    }
}

/// Published when a topology is initialized.
public struct TopologyOpeningEvent: Event {
    /// A unique identifier for the topology.
    let topologyId: ObjectId

    internal init(_ event: OpaquePointer) {
        var oid = bson_oid_t()
        mongoc_apm_topology_opening_get_topology_id(event, &oid)
        self.topologyId = ObjectId(from: oid)
    }
}

/// Published when a topology is closed.
public struct TopologyClosedEvent: Event {
    /// A unique identifier for the topology.
    let topologyId: ObjectId

    internal init(_ event: OpaquePointer) {
        var oid = bson_oid_t()
        mongoc_apm_topology_closed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(from: oid)
    }
}

/// Published when the server monitor’s ismaster command is started - immediately before
/// the ismaster command is serialized into raw BSON and written to the socket.
public struct ServerHeartbeatStartedEvent: Event {
    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    internal init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_heartbeat_started_get_host(event))
    }
}

/// Published when the server monitor’s ismaster succeeds.
public struct ServerHeartbeatSucceededEvent: Event {
    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The command reply.
    let reply: Document

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    internal init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_server_heartbeat_succeeded_get_duration(event)
        let replyData = UnsafeMutablePointer(mutating: mongoc_apm_server_heartbeat_succeeded_get_reply(event)!)
        self.reply = Document(fromPointer: replyData)
        self.connectionId = ConnectionId(mongoc_apm_server_heartbeat_succeeded_get_host(event))
    }
}

/// Published when the server monitor’s ismaster fails, either with an “ok: 0” or a socket exception.
public struct ServerHeartbeatFailedEvent: Event {
    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The failure. 
    let failure: MongoError

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    internal init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_server_heartbeat_failed_get_duration(event)
        var error = bson_error_t()
        mongoc_apm_server_heartbeat_failed_get_error(event, &error)
        self.failure = MongoError.commandError(message: toErrorString(error))
        self.connectionId = ConnectionId(mongoc_apm_server_heartbeat_failed_get_host(event))
    }
}

/// Callbacks that will be set for events with the corresponding names if the user enables 
/// notifications for those events. These functions generate new `Notification`s and post 
/// them to the `NotificationCenter` that was specified when calling `MongoClient.enableMonitoring`
/// (or `NotificationCenter.default` if none was specified.)

/// An internal callback that will be set for "command started" events if the user enables notifications for them.
internal func commandStarted(_event: OpaquePointer?) {
    postNotification(type: CommandStartedEvent.self, name: .commandStarted,
                    _event: _event, contextFunc: mongoc_apm_command_started_get_context)
}

/// An internal callback that will be set for "command succeeded" events if the user enables notifications for them.
internal func commandSucceeded(_event: OpaquePointer?) {
    postNotification(type: CommandSucceededEvent.self, name: .commandSucceeded,
                    _event: _event, contextFunc: mongoc_apm_command_succeeded_get_context)
}

/// An internal callback that will be set for "command failed" events if the user enables notifications for them.
internal func commandFailed(_event: OpaquePointer?) {
    postNotification(type: CommandFailedEvent.self, name: .commandFailed,
                    _event: _event, contextFunc: mongoc_apm_command_failed_get_context)
}

/// An internal callback that will be set for "server description changed" events if the user enables notifications
/// for them.
internal func serverDescriptionChanged(_event: OpaquePointer?) {
    postNotification(type: ServerDescriptionChangedEvent.self, name: .serverDescriptionChanged,
                    _event: _event, contextFunc: mongoc_apm_server_changed_get_context)
}

/// An internal callback that will be set for "server opening" events if the user enables notifications for them.
internal func serverOpening(_event: OpaquePointer?) {
    postNotification(type: ServerOpeningEvent.self, name: .serverOpening,
                    _event: _event, contextFunc: mongoc_apm_server_opening_get_context)
}

/// An internal callback that will be set for "server closed" events if the user enables notifications for them.
internal func serverClosed(_event: OpaquePointer?) {
    postNotification(type: ServerClosedEvent.self, name: .serverClosed,
                    _event: _event, contextFunc: mongoc_apm_server_closed_get_context)
}

/// An internal callback that will be set for "topology description changed" events if the user enables notifications
/// for them.
internal func topologyDescriptionChanged(_event: OpaquePointer?) {
    postNotification(type: TopologyDescriptionChangedEvent.self, name: .topologyDescriptionChanged,
                    _event: _event, contextFunc: mongoc_apm_topology_changed_get_context)
}

/// An internal callback that will be set for "topology opening" events if the user enables notifications for them.
internal func topologyOpening(_event: OpaquePointer?) {
    postNotification(type: TopologyOpeningEvent.self, name: .topologyOpening,
                _event: _event, contextFunc: mongoc_apm_topology_opening_get_context)
}

/// An internal callback that will be set for "topology closed" events if the user enables notifications for them.
internal func topologyClosed(_event: OpaquePointer?) {
    postNotification(type: TopologyClosedEvent.self, name: .topologyClosed,
                    _event: _event, contextFunc: mongoc_apm_topology_closed_get_context)
}

/// An internal callback that will be set for "server heartbeat started" events if the user enables notifications
/// for them.
internal func serverHeartbeatStarted(_event: OpaquePointer?) {
    postNotification(type: ServerHeartbeatStartedEvent.self, name: .serverHeartbeatStarted,
                    _event: _event, contextFunc: mongoc_apm_server_heartbeat_started_get_context)
}

/// An internal callback that will be set for "server heartbeat succeeded" events if the user enables notifications
/// for them.
internal func serverHeartbeatSucceeded(_event: OpaquePointer?) {
    postNotification(type: ServerHeartbeatSucceededEvent.self, name: .serverHeartbeatSucceeded,
                    _event: _event, contextFunc: mongoc_apm_server_heartbeat_succeeded_get_context)
}

/// An internal callback that will be set for "server heartbeat failed" events if the user enables notifications 
/// for them.
internal func serverHeartbeatFailed(_event: OpaquePointer?) {
    postNotification(type: ServerHeartbeatFailedEvent.self, name: .serverHeartbeatFailed,
                    _event: _event, contextFunc: mongoc_apm_server_heartbeat_failed_get_context)
}

/// Posts a Notification with the specified name, containing an event of type T generated using the provided _event 
/// and context function.
internal func postNotification<T: Event>(type: T.Type, name: Notification.Name, _event: OpaquePointer?,
                                         contextFunc: (OpaquePointer) -> UnsafeMutableRawPointer!) {
    guard let event = _event else {
        preconditionFailure("Missing event pointer for \(type)")
    }
    let eventStruct = type.init(event)
    let notification = Notification(name: name, userInfo: ["event": eventStruct])
    print("EVENT: \(eventStruct)")
    guard let context = contextFunc(event) else {
        preconditionFailure("Missing context for \(type)")
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
    static let serverDescriptionChanged = Notification.Name(MongoEvent.serverDescriptionChanged.rawValue)
    static let serverOpening = Notification.Name(MongoEvent.serverOpening.rawValue)
    static let serverClosed = Notification.Name(MongoEvent.serverClosed.rawValue)
    static let topologyDescriptionChanged = Notification.Name(MongoEvent.topologyDescriptionChanged.rawValue)
    static let topologyOpening = Notification.Name(MongoEvent.topologyOpening.rawValue)
    static let topologyClosed = Notification.Name(MongoEvent.topologyClosed.rawValue)
    static let serverHeartbeatStarted = Notification.Name(MongoEvent.serverHeartbeatStarted.rawValue)
    static let serverHeartbeatSucceeded = Notification.Name(MongoEvent.serverHeartbeatSucceeded.rawValue)
    static let serverHeartbeatFailed = Notification.Name(MongoEvent.serverHeartbeatFailed.rawValue)
}

/// An enumeration of the events that notifications can be enabled for.
public enum MongoEvent: String {
    case commandStarted
    case commandSucceeded
    case commandFailed
    case serverDescriptionChanged
    case serverOpening
    case serverClosed
    case topologyDescriptionChanged
    case topologyOpening
    case topologyClosed
    case serverHeartbeatStarted
    case serverHeartbeatSucceeded
    case serverHeartbeatFailed
}

/// An extension of MongoClient to add monitoring capability for commands and server discovery and monitoring.
extension MongoClient {
    /*
     *  Enables monitoring for this client, meaning notifications about command and 
     *  server discovering and monitoring events will be posted to the supplied
     *  NotificationCenter - or if one is not provided, the default NotificationCenter.
     *  If no specific event types are provided, all events will be posted.
     *  Notifications can only be enabled for a single NotificationCenter at a time.
     *
     *  Calling this function will reset all previously enabled events - i.e.
     *  calling
     *      client.enableMonitoring(forEvents: [.commandStarted])
     *      client.enableMonitoring(forEvents: [.commandSucceeded])
     *
     *  will result in only posting notifications for .commandSucceeded events.
     */
    // swiftlint:disable:next cyclomatic_complexity
    public func enableMonitoring(
        forEvents events: [MongoEvent] = [.commandStarted, .commandSucceeded, .commandFailed,
        .serverDescriptionChanged, .serverOpening, .serverClosed, .topologyDescriptionChanged,
        .topologyOpening, .topologyClosed, .serverHeartbeatStarted, .serverHeartbeatSucceeded,
        .serverHeartbeatFailed],
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
            case .serverDescriptionChanged:
                mongoc_apm_set_server_changed_cb(callbacks, serverDescriptionChanged)
            case .serverOpening:
                mongoc_apm_set_server_opening_cb(callbacks, serverOpening)
            case .serverClosed:
                mongoc_apm_set_server_closed_cb(callbacks, serverClosed)
            case .topologyDescriptionChanged:
                mongoc_apm_set_topology_changed_cb(callbacks, topologyDescriptionChanged)
            case .topologyOpening:
                mongoc_apm_set_topology_opening_cb(callbacks, topologyOpening)
            case .topologyClosed:
                mongoc_apm_set_topology_closed_cb(callbacks, topologyClosed)
            case .serverHeartbeatStarted:
                mongoc_apm_set_server_heartbeat_started_cb(callbacks, serverHeartbeatStarted)
            case .serverHeartbeatSucceeded:
                mongoc_apm_set_server_heartbeat_succeeded_cb(callbacks, serverHeartbeatSucceeded)
            case .serverHeartbeatFailed:
                mongoc_apm_set_server_heartbeat_failed_cb(callbacks, serverHeartbeatFailed)
            }
        }
        self.notificationCenter = center
        mongoc_client_set_apm_callbacks(self._client, callbacks, Unmanaged.passUnretained(center).toOpaque())
        mongoc_apm_callbacks_destroy(callbacks)
    }

    /// Disables all notification types for this client.
    public func disableMonitoring() {
        print("disabling monitoring")
        mongoc_client_set_apm_callbacks(self._client, nil, nil)
        self.notificationCenter = nil
    }
}
