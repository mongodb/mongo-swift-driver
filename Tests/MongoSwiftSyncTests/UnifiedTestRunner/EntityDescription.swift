import Foundation
import MongoSwiftSync

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
        let observeEvents: [String]?

        /// Command names for which the test runner MUST ignore any observed command monitoring events. The command(s)
        /// will be ignored in addition to configureFailPoint and any commands containing sensitive information (per
        /// the Command Monitoring spec).
        let ignoreCommandMonitoringEvents: [String]?
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
        let options: MongoDatabaseOptions?
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
        let options: MongoCollectionOptions?
    }

    /// Describes a ClientSession entity.
    struct Session: Decodable {
        /// Unique name for this entity.
        let id: String

        /// Client entity from which this session will be created.
        let client: String

        /// Options to use for this session.
        let options: ClientSessionOptions?
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
