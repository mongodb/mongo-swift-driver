import CLibMongoC
import Foundation

/// A struct representing a network address, consisting of a host and port.
public struct ServerAddress: Equatable {
    /// The hostname or IP address.
    public let host: String

    /// The port number.
    public let port: UInt16

    /// Initializes a ServerAddress from an UnsafePointer to a mongoc_host_list_t.
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

    /// Initializes a ServerAddress, using the default localhost:27017 if a host/port is not provided.
    internal init(_ hostAndPort: String = "localhost:27017") throws {
        let parts = hostAndPort.split(separator: ":")
        self.host = String(parts[0])
        guard let port = UInt16(parts[1]) else {
            throw MongoError.InternalError(message: "couldn't parse address from \(hostAndPort)")
        }
        self.port = port
    }

    internal init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
}

extension ServerAddress: CustomStringConvertible {
    public var description: String {
        "\(self.host):\(self.port)"
    }
}

private struct HelloResponse: Decodable {
    fileprivate struct LastWrite: Decodable {
        public let lastWriteDate: Date?
    }

    fileprivate let lastWrite: LastWrite?
    fileprivate let minWireVersion: Int?
    fileprivate let maxWireVersion: Int?
    fileprivate let me: String?
    fileprivate let setName: String?
    fileprivate let setVersion: Int?
    fileprivate let electionID: BSONObjectID?
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
    public struct ServerType: RawRepresentable, Equatable {
        /// A standalone mongod server.
        public static let standalone = ServerType(.standalone)

        /// A router to a sharded cluster, i.e. a mongos server.
        public static let mongos = ServerType(.mongos)

        /// A replica set member which is not yet checked, but another member thinks it is the primary.
        public static let possiblePrimary = ServerType(.possiblePrimary)

        /// A replica set primary.
        public static let rsPrimary = ServerType(.rsPrimary)

        /// A replica set secondary.
        public static let rsSecondary = ServerType(.rsSecondary)

        /// A replica set arbiter.
        public static let rsArbiter = ServerType(.rsArbiter)

        /// A replica set member that is none of the other types (a passive, for example).
        public static let rsOther = ServerType(.rsOther)

        /// A replica set member that does not report a set name or a hosts list.
        public static let rsGhost = ServerType(.rsGhost)

        /// A server type that is not yet known.
        public static let unknown = ServerType(.unknown)

        /// A load balancer.
        public static let loadBalancer = ServerType(.loadBalancer)

        /// Internal representation of server type. If enums could be marked non-exhaustive in Swift, this would be the
        /// public representation too.
        private enum _ServerType: String, Equatable {
            case standalone = "Standalone"
            case mongos = "Mongos"
            case possiblePrimary = "PossiblePrimary"
            case rsPrimary = "RSPrimary"
            case rsSecondary = "RSSecondary"
            case rsArbiter = "RSArbiter"
            case rsOther = "RSOther"
            case rsGhost = "RSGhost"
            case unknown = "Unknown"
            case loadBalancer = "LoadBalancer"
        }

        private let _serverType: _ServerType

        private init(_ _type: _ServerType) {
            self._serverType = _type
        }

        public var rawValue: String {
            self._serverType.rawValue
        }

        public init?(rawValue: String) {
            guard let _type = _ServerType(rawValue: rawValue) else {
                return nil
            }
            self._serverType = _type
        }
    }

    /// The hostname or IP and the port number that the client connects to. Note that this is not the "me" field in the
    /// server's hello or legacy hello response, in the case that the server reports an address different from the
    /// address the client uses.
    public let address: ServerAddress

    /// Opaque identifier for this server, used for testing only.
    internal let serverId: UInt32

    /// The duration in milliseconds of the server's last "hello" call.
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
    public let me: ServerAddress?

    /// This server's opinion of the replica set's hosts, if any.
    public let hosts: [ServerAddress]

    /// This server's opinion of the replica set's arbiters, if any.
    public let arbiters: [ServerAddress]

    /// "Passives" are priority-zero replica set members that cannot become primary.
    /// The client treats them precisely the same as other members.
    public let passives: [ServerAddress]

    /// Tags for this server.
    public let tags: [String: String]

    /// The replica set name.
    public let setName: String?

    /// The replica set version.
    public let setVersion: Int?

    /// The election ID where this server was elected, if this is a replica set member that believes it is primary.
    public let electionID: BSONObjectID?

    /// This server's opinion of who the primary is.
    public let primary: ServerAddress?

    /// When this server was last checked.
    public let lastUpdateTime: Date

    /// The logicalSessionTimeoutMinutes value for this server.
    public let logicalSessionTimeoutMinutes: Int?

    /// An internal initializer to create a `ServerDescription` from an OpaquePointer to a
    /// mongoc_server_description_t.
    internal init(_ description: OpaquePointer) {
        self.address = ServerAddress(mongoc_server_description_host(description))
        self.serverId = mongoc_server_description_id(description)
        self.roundTripTime = Int(mongoc_server_description_round_trip_time(description))
        self.lastUpdateTime = Date(msSinceEpoch: mongoc_server_description_last_update_time(description))
        self.type = ServerType(rawValue: String(cString: mongoc_server_description_type(description))) ?? .unknown

        // initialize the rest of the values from the hello response.
        // we have to copy because libmongoc owns the pointer.
        let helloDoc = BSONDocument(copying: mongoc_server_description_hello_response(description))
        // TODO: SWIFT-349 log errors encountered here
        let hello = try? BSONDecoder().decode(HelloResponse.self, from: helloDoc)

        self.lastWriteDate = hello?.lastWrite?.lastWriteDate
        self.minWireVersion = hello?.minWireVersion ?? 0
        self.maxWireVersion = hello?.maxWireVersion ?? 0
        self.me = try? hello?.me.map(ServerAddress.init) // TODO: SWIFT-349 log error
        self.setName = hello?.setName
        self.setVersion = hello?.setVersion
        self.electionID = hello?.electionID
        self.primary = try? hello?.primary.map(ServerAddress.init) // TODO: SWIFT-349 log error
        self.logicalSessionTimeoutMinutes = hello?.logicalSessionTimeoutMinutes
        self.hosts = hello?.hosts?.compactMap { host in
            try? ServerAddress(host) // TODO: SWIFT-349 log error
        } ?? []
        self.passives = hello?.passives?.compactMap { passive in
            try? ServerAddress(passive) // TODO: SWIFT-349 log error
        } ?? []
        self.arbiters = hello?.arbiters?.compactMap { arbiter in
            try? ServerAddress(arbiter) // TODO: SWIFT-349 log error
        } ?? []
        self.tags = hello?.tags ?? [:]
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
            lhs.electionID == rhs.electionID &&
            lhs.primary == rhs.primary &&
            lhs.logicalSessionTimeoutMinutes == rhs.logicalSessionTimeoutMinutes
    }
}

/// A struct describing the state of a MongoDB deployment: its type (standalone, replica set, or sharded),
/// which servers are up, what type of servers they are, which is primary, and so on.
public struct TopologyDescription: Equatable {
    /// The possible types for a topology.
    public struct TopologyType: RawRepresentable, Equatable {
        /// A single mongod server.
        public static let single = TopologyType(.single)

        /// A replica set with no primary.
        public static let replicaSetNoPrimary = TopologyType(.replicaSetNoPrimary)

        /// A replica set with a primary.
        public static let replicaSetWithPrimary = TopologyType(.replicaSetWithPrimary)

        /// Sharded topology.
        public static let sharded = TopologyType(.sharded)

        /// A topology whose type is not yet known.
        public static let unknown = TopologyType(.unknown)

        /// A topology with a load balancer in front.
        public static let loadBalanced = TopologyType(.loadBalanced)

        /// Internal representation of topology type. If enums could be marked non-exhaustive in Swift, this would be
        /// the public representation too.
        private enum _TopologyType: String, Equatable {
            case single = "Single"
            case replicaSetNoPrimary = "ReplicaSetNoPrimary"
            case replicaSetWithPrimary = "ReplicaSetWithPrimary"
            case sharded = "Sharded"
            case unknown = "Unknown"
            case loadBalanced = "LoadBalanced"
        }

        private let _topologyType: _TopologyType

        private init(_ _type: _TopologyType) {
            self._topologyType = _type
        }

        public var rawValue: String {
            self._topologyType.rawValue
        }

        public init?(rawValue: String) {
            guard let _type = _TopologyType(rawValue: rawValue) else {
                return nil
            }
            self._topologyType = _type
        }
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
