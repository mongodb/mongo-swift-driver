import Foundation
import libmongoc

/// A struct representing a server connection, consisting of a host and port.
public struct ConnectionId: Equatable {
    let host: String
    let port: UInt16

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

    /// An internal initializer to create a `ServerDescription` from an OpaquePointer to a
    /// mongoc_server_description_t.
    internal init(_ description: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_server_description_host(description))
        self.roundTripTime = mongoc_server_description_round_trip_time(description)

        let isMasterData =  UnsafeMutablePointer(mutating: mongoc_server_description_ismaster(description)!)
        let isMaster = Document(fromPointer: isMasterData)
        self.parseIsMaster(isMaster)

        let serverType = String(cString: mongoc_server_description_type(description))
        self.type = ServerType(rawValue: serverType)!
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
    var setName: String? { return self.servers[0].setName }

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
    var logicalSessionTimeoutMinutes: Int64? {
        let timeoutValues = self.servers.map { $0.logicalSessionTimeoutMinutes }
        if timeoutValues.contains (where: { $0 == nil }) {
            return nil
        } else {
            return timeoutValues.map { $0! }.min()
        }
    }

    /// Determines if the topology has a readable server available.
    // (this function should take in an optional ReadPreference, but we have yet to implement that type.) 
    func hasReadableServer() -> Bool {
        return [.single, .replicaSetWithPrimary, .sharded].contains(self.type)
    }

    /// Determines if the topology has a writable server available.
    func hasWritableServer() -> Bool {
        return [.single, .replicaSetWithPrimary].contains(self.type)
    }

    /// An internal initializer to create a `TopologyDescription` from an OpaquePointer
    /// to a mongoc_server_description_t
    internal init(_ description: OpaquePointer) {

        let topologyType = String(cString: mongoc_topology_description_type(description))
        self.type = TopologyType(rawValue: topologyType)!

        var size = size_t()
        let serverData = mongoc_topology_description_get_servers(description, &size)
        let buffer = UnsafeBufferPointer(start: serverData, count: size)
        if size > 0 {
            self.servers = Array(buffer).map { ServerDescription($0!) }
        }
    }
}
