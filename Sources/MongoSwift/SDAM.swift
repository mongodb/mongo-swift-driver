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
        self.host = withUnsafeBytes(of: &hostData.host) { (rawPtr) -> String in
            let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
            return String(cString: ptr)
        }
        self.port = hostData.port
    }

    /// Initializes a ConnectionId, using the default localhost:27017 if a host/port is not provided.
    internal init(_ hostAndPort: String = "localhost:27017") {
        let parts = hostAndPort.split(separator: ":")
        self.host = String(parts[0])
        self.port = UInt16(parts[1])!
    }

    /// ConnectionIds are equal if their hosts and ports match.
    public static func == (lhs: ConnectionId, rhs: ConnectionId) -> Bool {
        return lhs.host == rhs.host && rhs.port == lhs.port
    }
}

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

/// A struct describing a mongod or mongos process.
public struct ServerDescription {
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
    public var lastUpdateTime: Date?

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

    /// An internal function used to determine if a given server matches a tag set.
    internal func matchesTagSet(_ tagSet: Document) -> Bool {
        for kvp in tagSet {
            if !self.tags.keys.contains(kvp.key) || !bsonEquals(self.tags[kvp.key], kvp.value) {
                return false
            }
        }
        return true
    }

    /// An internal initializer to create a `ServerDescription` for testing purposes. This is defined here instead of
    /// in an extension in the test files due to restrictions introduced in SE-0189.
    internal init(connectionId: ConnectionId, type: ServerType, isMaster: Document, updateTime: Date?) {
        self.connectionId = connectionId
        self.type = type
        self.parseIsMaster(isMaster)
        self.lastUpdateTime = updateTime // TODO: get lastUpdateTime from mongoc_server_description_t after CDRIVER-2896
    }

    /// An internal initializer to create a `ServerDescription` from an OpaquePointer to a
    /// mongoc_server_description_t.
    internal init(_ description: OpaquePointer, updateTime: Date? = nil) {
        self.lastUpdateTime = updateTime // TODO: get lastUpdateTime from mongoc_server_description_t after CDRIVER-2896
        self.connectionId = ConnectionId(mongoc_server_description_host(description))
        self.roundTripTime = mongoc_server_description_round_trip_time(description)

        let isMaster = Document(fromPointer: mongoc_server_description_ismaster(description)!)
        self.parseIsMaster(isMaster)

        let serverType = String(cString: mongoc_server_description_type(description))
        self.type = ServerType(rawValue: serverType)!
    }
}

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
}

/// A struct describing the state of a MongoDB deployment: its type (standalone, replica set, or sharded),
/// which servers are up, what type of servers they are, which is primary, and so on.
public struct TopologyDescription {
    /// The interval between server checks, can be configured via the URI.
    internal static var heartbeatFrequencyMS: Int = 60000

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
        } else {
            return timeoutValues.map { $0! }.min()
        }
    }

    /// An internal function used to calculate staleness of a given server in a replica set in seconds.
    internal func staleness(for server: ServerDescription) -> TimeInterval? {
        guard [.replicaSetWithPrimary, .replicaSetNoPrimary].contains(self.type) else {
            return nil
        }

        // From spec: Non-secondary servers have zero staleness
        guard server.type == .rsSecondary else {
            return 0.0
        }

        // Can force unwrap lastWriteDate in here since it's always present in the the ismaster output of primaries
        // and secondaries, and we filter out all other types of servers.
        if self.type == .replicaSetWithPrimary {
            let primary = self.servers.filter { server in server.type == .rsPrimary }[0]

            let delta = { (serverDesc: ServerDescription) -> TimeInterval? in
                guard let serverLastUpdate = serverDesc.lastUpdateTime else {
                    return nil
                }
                return (serverLastUpdate - serverDesc.lastWriteDate!)
            }

            guard let clientToServer = delta(server), let clientToPrimary = delta(primary) else {
                return nil
            }

            return clientToServer - clientToPrimary + TimeInterval(TopologyDescription.heartbeatFrequencyMS) / 1000.0
        } else { // ReplicaSetNoPrimary case
            let secondaries = self.servers.filter { $0.type == .rsSecondary }
            guard secondaries.count > 0 else {
                return nil
            }
            let sMax = secondaries.max { $0.lastWriteDate! < $1.lastWriteDate! }!

            return (sMax.lastWriteDate! - server.lastWriteDate!)
                    + TimeInterval(TopologyDescription.heartbeatFrequencyMS) / 1000.0
        }
    }

    /// An internal function used to determine if there are suitable servers to read from in a replica set.
    internal func hasSuitableReadServer(_ readPref: ReadPreference) -> Bool {
        var suitableModes: [ServerType]

        switch readPref.mode {
        case .primary:
            suitableModes = [.rsPrimary]
        case .secondary:
            suitableModes = [.rsSecondary]
        default:
            suitableModes = [.rsSecondary, .rsPrimary]
        }

        var candidates = self.servers.filter { suitableModes.contains($0.type) }

        // If read preference specifies a max staleness, first filter out too stale servers
        if let maxStalenessSeconds = readPref.maxStalenessSeconds, maxStalenessSeconds > 0 {
            candidates = candidates.filter { (candidate) in
                guard let staleness = self.staleness(for: candidate) else {
                    return false
                }

                return staleness <= TimeInterval(maxStalenessSeconds)
            }
        }

        // If the read preference specifies tags, find a server that matches
        if readPref.tagSets.count > 0 {
            for candidate in candidates {
                if candidate.type == .rsPrimary && readPref.mode != .nearest {
                    return true
                }

                for tagSet in readPref.tagSets {
                    if candidate.matchesTagSet(tagSet) {
                        return true
                    }
                }
            }
            return false
        }
        return candidates.count > 0
    }

    /// Returns `true` if the topology has a readable server available, and `false` otherwise.
    public func hasReadableServer(_ readPref: ReadPreference = ReadPreference(.primary)) -> Bool {
        switch self.type {
        case .unknown:
            return false
        case .single, .sharded:
            return true
        case .replicaSetNoPrimary:
            if readPref.mode == .primary {
                return false
            }
            return hasSuitableReadServer(readPref)
        case .replicaSetWithPrimary:
            if readPref.mode == .primary {
                return true
            }
            return hasSuitableReadServer(readPref)
        }
    }

    /// Returns `true` if the topology has a writable server available, and `false` otherwise.
    public func hasWritableServer() -> Bool {
        return [.single, .replicaSetWithPrimary].contains(self.type)
    }

    /// An internal initializer to create a `TopologyDescription` for testing purposes. This is defined here instead of
    /// in an extension in the test files due to restrictions introduced in SE-0189.
    internal init(type: TopologyType, servers: [ServerDescription]) {
        self.type = type
        self.servers = servers
    }

    /// An internal initializer to create a `TopologyDescription` from an OpaquePointer
    /// to a `mongoc_topology_description_t`
    internal init(_ description: OpaquePointer) {
        let updateTime = Date()
        let topologyType = String(cString: mongoc_topology_description_type(description))
        self.type = TopologyType(rawValue: topologyType)!

        var size = size_t()
        let serverData = mongoc_topology_description_get_servers(description, &size)
        let buffer = UnsafeBufferPointer(start: serverData, count: size)
        if size > 0 {
            self.servers = Array(buffer).map { ServerDescription($0!, updateTime: updateTime) }
        }
    }
}
