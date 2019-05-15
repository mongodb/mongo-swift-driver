import Foundation
import mongoc

/// A struct representing a server connection, consisting of a host and port.
public struct ConnectionId: Equatable {
    /// A string representing the host for this connection.
    public let host: String
    /// The port number for this connection.
    public let port: UInt16

    /// Initializes a ConnectionId from an UnsafePointer to a mongoc_host_list_t.
    internal init(_ hostList: UnsafePointer<mongoc_host_list_t>) {
        var hostData = hostList.pointee
        self.host = withUnsafeBytes(of: &hostData.host) { rawPtr -> String in
            // if baseAddress is nil, the buffer is empty.
            guard let baseAddress = rawPtr.baseAddress else {
                return ""
            }
            return String(cString: baseAddress.assumingMemoryBound(to: CChar.self))
        }
        self.port = hostData.port
    }

    /// Initializes a ConnectionId, using the default localhost:27017 if a host/port is not provided.
    internal init(_ hostAndPort: String = "localhost:27017") {
        let parts = hostAndPort.split(separator: ":")
        self.host = String(parts[0])
        // swiftlint:disable:next force_unwrapping
        self.port = UInt16(parts[1])! // should be valid UInt16 unless server response malformed.
    }
}

/// A struct describing a mongod or mongos process.
public struct ServerDescription {
    /// The possible types for a server.
    public enum ServerType: String {
        /// A standalone mongod server.
        case standalone = "Standalone"
        /// A router to a sharded cluster, i.e. a mongos server.
        case mongos = "Mongos"
        /// A replica set member which is not yet checked, but another member thinks it is the primary.
        case possiblePrimary = "PossiblePrimary"
        /// A replica set primary.
        case rsPrimary = "RSPrimary"
        /// A replica set secondary.
        case rsSecondary = "RSSecondary"
        /// A replica set arbiter.
        case rsArbiter = "RSArbiter"
        /// A replica set member that is none of the other types (a passive, for example).
        case rsOther = "RSOther"
        /// A replica set member that does not report a set name or a hosts list.
        case rsGhost = "RSGhost"
        /// A server type that is not yet known.
        case unknown = "Unknown"
    }

    /// The hostname or IP and the port number that the client connects to. Note that this is not the
    /// server's ismaster.me field, in the case that the server reports an address different from the
    /// address the client uses.
    public let connectionId: ConnectionId

    /// The last error related to this server.
    public let error: MongoError? = nil // currently we will never set this

    /// The duration of the server's last ismaster call.
    public var roundTripTime: Int64?

    /// The "lastWriteDate" from the server's most recent ismaster response.
    public var lastWriteDate: Date?

    /// The last opTime reported by the server. Only mongos and shard servers
    /// record this field when monitoring config servers as replica sets.
    public var opTime: ObjectId?

    /// The type of this server.
    public var type: ServerType = .unknown

    /// The minimum wire protocol version supported by the server.
    public var minWireVersion: Int32 = 0

    /// The maximum wire protocol version supported by the server.
    public var maxWireVersion: Int32 = 0

    /// The hostname or IP and the port number that this server was configured with in the replica set.
    public var me: ConnectionId?

    /// This server's opinion of the replica set's hosts, if any.
    public var hosts: [ConnectionId] = []
    /// This server's opinion of the replica set's arbiters, if any.
    public var arbiters: [ConnectionId] = []
    /// "Passives" are priority-zero replica set members that cannot become primary.
    /// The client treats them precisely the same as other members.
    public var passives: [ConnectionId] = []

    /// Tags for this server.
    public var tags: [String: String] = [:]

    /// The replica set name.
    public var setName: String?

    /// The replica set version.
    public var setVersion: Int64?

    /// The election ID where this server was elected, if this is a replica set member that believes it is primary.
    public var electionId: ObjectId?

    /// This server's opinion of who the primary is.
    public var primary: ConnectionId?

    /// When this server was last checked.
    public let lastUpdateTime: Date? = nil // currently, this will never be set

    /// The logicalSessionTimeoutMinutes value for this server.
    public var logicalSessionTimeoutMinutes: Int64?

    /// An internal initializer to create a `ServerDescription` with just a ConnectionId.
    internal init(connectionId: ConnectionId) {
        self.connectionId = connectionId
    }

    /// An internal function to handle parsing isMaster and setting ServerDescription attributes appropriately.
    internal mutating func parseIsMaster(_ isMaster: Document) {
        if let lastWrite = isMaster["lastWrite"] as? Document {
            self.lastWriteDate = lastWrite["lastWriteDate"] as? Date
            self.opTime = lastWrite["opTime"] as? ObjectId
        }

        if let minVersion = (isMaster["minWireVersion"] as? BSONNumber)?.int32Value {
            self.minWireVersion = minVersion
        }

        if let maxVersion = (isMaster["maxWireVersion"] as? BSONNumber)?.int32Value {
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
        self.setVersion = (isMaster["setVersion"] as? BSONNumber)?.int64Value
        self.electionId = isMaster["electionId"] as? ObjectId

        if let primary = isMaster["primary"] as? String {
            self.primary = ConnectionId(primary)
        }

        self.logicalSessionTimeoutMinutes = (isMaster["logicalSessionTimeoutMinutes"] as? BSONNumber)?.int64Value
    }

    /// An internal initializer to create a `ServerDescription` from an OpaquePointer to a
    /// mongoc_server_description_t.
    internal init(_ description: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_server_description_host(description))
        self.roundTripTime = mongoc_server_description_round_trip_time(description)
        // we have to copy because libmongoc owns the pointer.
        let isMaster = Document(copying: mongoc_server_description_ismaster(description))
        self.parseIsMaster(isMaster)

        let serverType = String(cString: mongoc_server_description_type(description))
        // swiftlint:disable:next force_unwrapping
        self.type = ServerType(rawValue: serverType)! // libmongoc will always give us a valid raw value.
    }
}

/// A struct describing the state of a MongoDB deployment: its type (standalone, replica set, or sharded),
/// which servers are up, what type of servers they are, which is primary, and so on.
public struct TopologyDescription {
    /// The possible types for a topology.
    public enum TopologyType: String {
        /// A single mongod server.
        case single = "Single"
        /// A replica set with no primary.
        case replicaSetNoPrimary = "ReplicaSetNoPrimary"
        /// A replica set with a primary.
        case replicaSetWithPrimary = "ReplicaSetWithPrimary"
        /// Sharded topology.
        case sharded = "Sharded"
        /// A topology whose type is not yet known.
        case unknown = "Unknown"

        /// Internal initializer used for translating evergreen config and spec test topologies to a `TopologyType`
        internal init(from str: String) {
            switch str {
            case "sharded", "sharded_cluster":
                self = .sharded
            case "replicaset", "replica_set":
                self = .replicaSetWithPrimary
            default:
                self = .single
            }
        }
    }

    /// The type of this topology.
    public let type: TopologyType

    /// The replica set name.
    public var setName: String? { return self.servers[0].setName }

    /// The largest setVersion ever reported by a primary.
    public var maxSetVersion: Int64?

    /// The largest electionId ever reported by a primary.
    public var maxElectionId: ObjectId?

    /// The servers comprising this topology. By default, no servers.
    public var servers: [ServerDescription] = []

    /// For single-threaded clients, indicates whether the topology must be re-scanned.
    public let stale: Bool = false // currently, this will never be set

    /// Exists if any server's wire protocol version range is incompatible with the client's.
    public let compatibilityError: MongoError? = nil // currently, this will never be set

    /// The logicalSessionTimeoutMinutes value for this topology. This value is the minimum
    /// of the `logicalSessionTimeoutMinutes` values across all the servers in `servers`,
    /// or `nil` if any of them are `nil`.
    public var logicalSessionTimeoutMinutes: Int64? {
        let timeoutValues = self.servers.map { $0.logicalSessionTimeoutMinutes }
        if timeoutValues.contains (where: { $0 == nil }) {
            return nil
        }
        return timeoutValues.compactMap { $0 }.min()
    }

    /// Returns `true` if the topology has a readable server available, and `false` otherwise.
    public func hasReadableServer() -> Bool {
        // (this function should take in an optional ReadPreference, but we have yet to implement that type.)
        return [.single, .replicaSetWithPrimary, .sharded].contains(self.type)
    }

    /// Returns `true` if the topology has a writable server available, and `false` otherwise.
    public func hasWritableServer() -> Bool {
        return [.single, .replicaSetWithPrimary].contains(self.type)
    }

    /// An internal initializer to create a `TopologyDescription` from an OpaquePointer
    /// to a `mongoc_server_description_t`
    internal init(_ description: OpaquePointer) {
        let topologyType = String(cString: mongoc_topology_description_type(description))
        // swiftlint:disable:next force_unwrapping
        self.type = TopologyType(rawValue: topologyType)! // libmongoc will only give us back valid raw values.

        var size = size_t()
        let serverData = mongoc_topology_description_get_servers(description, &size)
        defer { mongoc_server_descriptions_destroy_all(serverData, size) }

        let buffer = UnsafeBufferPointer(start: serverData, count: size)
        if size > 0 {
            // swiftlint:disable:next force_unwrapping
            self.servers = Array(buffer).map { ServerDescription($0!) } // documented as always returning a value.
        }
    }
}
