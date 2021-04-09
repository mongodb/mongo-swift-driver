import Foundation
@testable import struct MongoSwift.MongoClientOptions
import MongoSwiftSync
import TestsCommon

/// Represents a description of an entity (client, db, etc.).
enum EntityDescription: Decodable {
    case client(Client)
    case database(Database)
    case collection(Coll)
    case session(Session)
    case bucket(Bucket)

    /// Describes a Client entity.
    struct Client: Decodable {
        /// Unique name for this entity.
        let id: String

        /// Additional URI options to apply to the test suite's connection string that is used to create this client.
        let uriOptions: MongoClientOptions?

        /**
         * If true and the topology is a sharded cluster, the test runner MUST assert that this MongoClient connects
         * to multiple mongos hosts (e.g. by inspecting the connection string). If false and the topology is a sharded
         * cluster, the test runner MUST ensure that this MongoClient connects to only a single mongos host (e.g. by
         * modifying the connection string).
         * If this option is not specified and the topology is a sharded cluster, the test runner MUST NOT enforce any
         * limit on the number of mongos hosts in the connection string. This option has no effect for non-sharded
         * topologies.
         */
        let useMultipleMongoses: Bool?

        /// Types of events that can be observed for this client. Unspecified event types MUST be ignored by this
        /// client's event listeners.
        let observeEvents: [CommandEvent.EventType]?

        /// Command names for which the test runner MUST ignore any observed command monitoring events. The command(s)
        /// will be ignored in addition to configureFailPoint and any commands containing sensitive information (per
        /// the Command Monitoring spec).
        let ignoreCommandMonitoringEvents: [String]?

        /// Optional object to declare an API version on the client entity. A `version` string is required, and test
        /// runners MUST fail if the given version string is not supported by the driver.
        let serverAPI: MongoServerAPI?

        enum CodingKeys: String, CodingKey {
            case id, uriOptions, useMultipleMongoses, observeEvents,
                 ignoreCommandMonitoringEvents, serverAPI = "serverApi"
        }
    }

    /// Describes a Database entity.
    struct Database: Decodable {
        /// Unique name for this entity.
        let id: String

        /// Client entity from which this database will be created.
        let client: String

        /// Database name.
        let databaseName: String

        /// Options to use for this database.
        let databaseOptions: MongoDatabaseOptions?
    }

    /// Describes a Collection entity. (named Coll because Collection clashes with the stdlib's Collection protocol.)
    struct Coll: Decodable {
        /// Unique name for this entity.
        let id: String

        /// Database entity from which this collection will be created.
        let database: String

        /// Collection name.
        let collectionName: String

        /// Options to use for this collection.
        let collectionOptions: MongoCollectionOptions?
    }

    /// Describes a ClientSession entity.
    struct Session: Decodable {
        /// Unique name for this entity.
        let id: String

        /// Client entity from which this session will be created.
        let client: String

        /// Options to use for this session.
        let sessionOptions: ClientSessionOptions?
    }

    /// Defines a GridFS bucket entity.
    struct Bucket: Decodable {
        /// Unique name for this entity.
        let id: String

        /// Database entity from which this bucket will be created.
        let database: String

        /// Options to use for this bucket. Eventually this would be GridFSOptions rather than just a document, if we
        /// ever add GridFS support.
        let bucketOptions: BSONDocument?
    }

    /// All of the possible keys. Only one will ever be present.
    private enum CodingKeys: String, CodingKey {
        case client, database, collection, session, bucket
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let client = try container.decodeIfPresent(Client.self, forKey: .client) {
            self = .client(client)
        } else if let db = try container.decodeIfPresent(Database.self, forKey: .database) {
            self = .database(db)
        } else if let coll = try container.decodeIfPresent(Coll.self, forKey: .collection) {
            self = .collection(coll)
        } else if let session = try container.decodeIfPresent(Session.self, forKey: .session) {
            self = .session(session)
        } else {
            let bucket = try container.decode(Bucket.self, forKey: .bucket)
            self = .bucket(bucket)
        }
    }
}

/// Wrapper around a MongoClient used for test runner purposes.
struct UnifiedTestClient {
    let client: MongoClient

    let commandMonitor: UnifiedTestCommandMonitor

    init(_ clientDescription: EntityDescription.Client) throws {
        let connStr = MongoSwiftTestCase.getConnectionString(
            singleMongos: clientDescription.useMultipleMongoses != true
        ).toString()
        var opts = clientDescription.uriOptions ?? MongoClientOptions()
        opts.serverAPI = clientDescription.serverAPI
        // If the test might execute a configureFailPoint command, for each target client the test runner MAY
        // specify a reduced value for heartbeatFrequencyMS (and minHeartbeatFrequencyMS if possible) to speed
        // up SDAM recovery time and server selection after a failure; however, test runners MUST NOT do so for
        // any client that specifies heartbeatFrequencyMS in its uriOptions.
        if opts.heartbeatFrequencyMS == nil {
            opts.minHeartbeatFrequencyMS = 50
            opts.heartbeatFrequencyMS = 50
        }
        self.client = try MongoClient.makeTestClient(connStr, options: opts)
        self.commandMonitor = UnifiedTestCommandMonitor(
            observeEvents: clientDescription.observeEvents,
            ignoreEvents: clientDescription.ignoreCommandMonitoringEvents
        )
        self.client.addCommandEventHandler(self.commandMonitor)
        try self.commandMonitor.enable()
    }

    /// Disables command monitoring for the client and returns a list of the captured events.
    func stopCapturingEvents() throws -> [CommandEvent] {
        try self.commandMonitor.disable()
    }
}

/// Command observer used to collect a specified subset of events for a client.
class UnifiedTestCommandMonitor: CommandEventHandler {
    private var monitoring: Bool
    var events: [CommandEvent]
    private let observeEvents: [CommandEvent.EventType]
    private let ignoreEvents: [String]

    public init(observeEvents: [CommandEvent.EventType]?, ignoreEvents: [String]?) {
        self.events = []
        self.monitoring = false
        self.observeEvents = observeEvents ?? []
        self.ignoreEvents = (ignoreEvents ?? []) + ["configureFailPoint"]
    }

    public func handleCommandEvent(_ event: CommandEvent) {
        guard self.monitoring else {
            return
        }
        guard self.observeEvents.contains(event.type) else {
            return
        }
        guard !self.ignoreEvents.contains(event.commandName) else {
            return
        }
        self.events.append(event)
    }

    func enable() throws {
        guard !self.monitoring else {
            throw TestError(message: "TestCommandMonitor is already enabled")
        }
        self.monitoring = true
    }

    func disable() throws -> [CommandEvent] {
        guard self.monitoring else {
            throw TestError(message: "TestCommandMonitor is already disabled")
        }
        self.monitoring = false
        defer { self.events.removeAll() }
        return self.events
    }
}

/// Represents an entity created at the start of a test.
enum Entity {
    case client(UnifiedTestClient)
    case database(MongoDatabase)
    case collection(MongoCollection<BSONDocument>)
    case session(ClientSession)
    case changeStream(ChangeStream<BSONDocument>)
    case bson(BSON)

    func asTestClient() throws -> UnifiedTestClient {
        guard case let .client(client) = self else {
            throw TestError(message: "Failed to return entity \(self) as a client")
        }
        return client
    }

    func asDatabase() throws -> MongoDatabase {
        guard case let .database(db) = self else {
            throw TestError(message: "Failed to return entity \(self) as a database")
        }
        return db
    }

    func asCollection() throws -> MongoCollection<BSONDocument> {
        guard case let .collection(coll) = self else {
            throw TestError(message: "Failed to return entity \(self) as a collection")
        }
        return coll
    }

    func asSession() throws -> ClientSession {
        guard case let .session(session) = self else {
            throw TestError(message: "Failed to return entity \(self) as a session")
        }
        return session
    }

    func asChangeStream() throws -> ChangeStream<BSONDocument> {
        guard case let .changeStream(cs) = self else {
            throw TestError(message: "Failed to return entity \(self) as a change stream")
        }
        return cs
    }

    func asBSON() throws -> BSON {
        guard case let .bson(bson) = self else {
            throw TestError(message: "Failed to return entity \(self) as a BSON")
        }
        return bson
    }
}

typealias EntityMap = [String: Entity]

extension Array where Element == EntityDescription {
    /// Converts an array of entity descriptions from a test file into an entity map.
    func toEntityMap() throws -> EntityMap {
        var map = EntityMap()
        for desc in self {
            switch desc {
            case let .client(clientDesc):
                map[clientDesc.id] = try .client(UnifiedTestClient(clientDesc))
            case let .database(dbDesc):
                guard let clientEntity = try map[dbDesc.client]?.asTestClient() else {
                    throw TestError(message: "No client with id \(dbDesc.client) found in entity map")
                }
                map[dbDesc.id] = .database(clientEntity.client.db(
                    dbDesc.databaseName,
                    options: dbDesc.databaseOptions
                ))
            case let .collection(collDesc):
                guard let db = try map[collDesc.database]?.asDatabase() else {
                    throw TestError(message: "No database with id \(collDesc.database) found in entity map")
                }
                map[collDesc.id] = .collection(db.collection(
                    collDesc.collectionName,
                    options: collDesc.collectionOptions
                ))
            case let .session(sessionDesc):
                guard let clientEntity = try map[sessionDesc.client]?.asTestClient() else {
                    throw TestError(message: "No client with id \(sessionDesc.client) found in entity map")
                }
                map[sessionDesc.id] = .session(clientEntity.client.startSession(options: sessionDesc.sessionOptions))
            case .bucket:
                throw TestError(message: "Unsupported entity type bucket")
            }
        }
        return map
    }
}

extension EntityMap {
    func getEntity(from object: UnifiedOperation.Object) throws -> Entity {
        try self.getEntity(id: object.asEntityId())
    }

    func getEntity(id: String) throws -> Entity {
        guard let entity = self[id] else {
            throw TestError(message: "No entity with id \(id) found in entity map")
        }
        return entity
    }

    func resolveSession(id: String?) throws -> ClientSession? {
        guard let id = id else {
            return nil
        }
        return try self.getEntity(id: id).asSession()
    }
}
