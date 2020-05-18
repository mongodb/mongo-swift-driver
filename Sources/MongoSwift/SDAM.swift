import CLibMongoC
import Foundation

/// A struct representing a network address, consisting of a host and port.
public struct Address: Equatable {
    /// The hostname or IP address.
    public let host: String

    /// The port number.
    public let port: UInt16

    /// Initializes a Address from an UnsafePointer to a mongoc_host_list_t.
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

    /// Initializes a Address, using the default localhost:27017 if a host/port is not provided.
    internal init(_ hostAndPort: String = "localhost:27017") throws {
        let parts = hostAndPort.split(separator: ":")
        self.host = String(parts[0])
        guard let port = UInt16(parts[1]) else {
            throw InternalError(message: "couldn't parse address from \(hostAndPort)")
        }
        self.port = port
    }

    internal init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
}

extension Address: CustomStringConvertible {
    public var description: String {
        "\(self.host):\(self.port)"
    }
}

private struct IsMasterResponse: Decodable {
    fileprivate struct LastWrite: Decodable {
        public let lastWriteDate: Date?
    }

    fileprivate let lastWrite: LastWrite?
    fileprivate let minWireVersion: Int?
    fileprivate let maxWireVersion: Int?
    fileprivate let me: String?
    fileprivate let setName: String?
    fileprivate let setVersion: Int?
    fileprivate let electionId: ObjectId?
    fileprivate let primary: String?
    fileprivate let logicalSessionTimeoutMinutes: Int?
    fileprivate let hosts: [String]?
    fileprivate let passives: [String]?
    fileprivate let arbiters: [String]?
    fileprivate let tags: [String: String]?
}

/// A struct describing a mongod or mongos process.
public struct ServerDescription {
    /// The possible types for a server.
    public enum ServerType: String, Equatable {
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
    public let address: Address

    /// The duration in milliseconds of the server's last ismaster call.
    public let roundTripTime: Int?

    /// The date of the most recent write operation seen by this server.
    public var lastWriteDate: Date?

    /// The type of this server.
    public let type: ServerType

    /// The minimum wire protocol version supported by the server.
    public let minWireVersion: Int

    /// The maximum wire protocol version supported by the server.
    public let maxWireVersion: Int

    /// The hostname or IP and the port number that this server was configured with in the replica set.
    public let me: Address?

    /// This server's opinion of the replica set's hosts, if any.
    public let hosts: [Address]

    /// This server's opinion of the replica set's arbiters, if any.
    public let arbiters: [Address]

    /// "Passives" are priority-zero replica set members that cannot become primary.
    /// The client treats them precisely the same as other members.
    public let passives: [Address]

    /// Tags for this server.
    public let tags: [String: String]

    /// The replica set name.
    public let setName: String?

    /// The replica set version.
    public let setVersion: Int?

    /// The election ID where this server was elected, if this is a replica set member that believes it is primary.
    public let electionId: ObjectId?

    /// This server's opinion of who the primary is.
    public let primary: Address?

    /// When this server was last checked.
    public let lastUpdateTime: Date

    /// The logicalSessionTimeoutMinutes value for this server.
    public let logicalSessionTimeoutMinutes: Int?

    /// An internal initializer to create a `ServerDescription` from an OpaquePointer to a
    /// mongoc_server_description_t.
    internal init(_ description: OpaquePointer) {
        self.address = Address(mongoc_server_description_host(description))
        self.roundTripTime = Int(mongoc_server_description_round_trip_time(description))
        self.lastUpdateTime = Date(msSinceEpoch: mongoc_server_description_last_update_time(description))
        self.type = ServerType(rawValue: String(cString: mongoc_server_description_type(description))) ?? .unknown

        // initialize the rest of the values from the isMaster response.
        // we have to copy because libmongoc owns the pointer.
        let isMasterDoc = Document(copying: mongoc_server_description_ismaster(description))
        // TODO: SWIFT-349 log errors encountered here
        let isMaster = try? BSONDecoder().decode(IsMasterResponse.self, from: isMasterDoc)

        self.lastWriteDate = isMaster?.lastWrite?.lastWriteDate
        self.minWireVersion = isMaster?.minWireVersion ?? 0
        self.maxWireVersion = isMaster?.maxWireVersion ?? 0
        self.me = try? isMaster?.me.map(Address.init) // TODO: SWIFT-349 log error
        self.setName = isMaster?.setName
        self.setVersion = isMaster?.setVersion
        self.electionId = isMaster?.electionId
        self.primary = try? isMaster?.primary.map(Address.init) // TODO: SWIFT-349 log error
        self.logicalSessionTimeoutMinutes = isMaster?.logicalSessionTimeoutMinutes
        self.hosts = isMaster?.hosts?.compactMap { host in
            try? Address(host) // TODO: SWIFT-349 log error
        } ?? []
        self.passives = isMaster?.passives?.compactMap { passive in
            try? Address(passive) // TODO: SWIFT-349 log error
        } ?? []
        self.arbiters = isMaster?.arbiters?.compactMap { arbiter in
            try? Address(arbiter) // TODO: SWIFT-349 log error
        } ?? []
        self.tags = isMaster?.tags ?? [:]
    }
}

extension ServerDescription: Equatable {
    public static func == (lhs: ServerDescription, rhs: ServerDescription) -> Bool {
        // As per the SDAM spec, only some fields are necessary to compare for equality.
        lhs.address == rhs.address &&
            lhs.type == rhs.type &&
            lhs.minWireVersion == rhs.minWireVersion &&
            lhs.maxWireVersion == rhs.maxWireVersion &&
            lhs.me == rhs.me &&
            lhs.hosts == rhs.hosts &&
            lhs.arbiters == rhs.arbiters &&
            lhs.passives == rhs.passives &&
            lhs.tags == rhs.tags &&
            lhs.setName == rhs.setName &&
            lhs.setVersion == rhs.setVersion &&
            lhs.electionId == rhs.electionId &&
            lhs.primary == rhs.primary &&
            lhs.logicalSessionTimeoutMinutes == rhs.logicalSessionTimeoutMinutes
    }
}

/// A struct describing the state of a MongoDB deployment: its type (standalone, replica set, or sharded),
/// which servers are up, what type of servers they are, which is primary, and so on.
public struct TopologyDescription: Equatable {
    /// The possible types for a topology.
    public enum TopologyType: String, Equatable {
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

    /// The type of this topology.
    public let type: TopologyType

    /// The replica set name.
    public var setName: String? {
        guard !self.servers.isEmpty else {
            return nil
        }
        return self.servers[0].setName
    }

    /// The servers comprising this topology.
    public let servers: [ServerDescription]

    /// The logicalSessionTimeoutMinutes value for this topology. This value is the minimum
    /// of the `logicalSessionTimeoutMinutes` values across all the servers in `servers`,
    /// or `nil` if any of them are `nil`.
    public var logicalSessionTimeoutMinutes: Int? {
        let timeoutValues = self.servers.map { $0.logicalSessionTimeoutMinutes }
        if timeoutValues.contains(where: { $0 == nil }) {
            return nil
        }
        return timeoutValues.compactMap { $0 }.min()
    }

    /// Returns `true` if the topology has a readable server available, and `false` otherwise.
    public func hasReadableServer() -> Bool {
        // TODO: SWIFT-244: amend this method to take in a read preference.
        [.single, .replicaSetWithPrimary, .sharded].contains(self.type)
    }

    /// Returns `true` if the topology has a writable server available, and `false` otherwise.
    public func hasWritableServer() -> Bool {
        [.single, .replicaSetWithPrimary].contains(self.type)
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
        // swiftlint:disable:next force_unwrapping
        self.servers = size > 0 ? Array(buffer).map { ServerDescription($0!) } : []
        // the buffer is documented as always containing non-nil pointers (if non-empty).
    }
}
