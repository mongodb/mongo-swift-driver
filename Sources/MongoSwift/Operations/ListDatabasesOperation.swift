import CLibMongoC

/// A struct modeling the information returned from the `listDatabases` command about a single database.
public struct DatabaseSpecification: Codable {
    /// The name of the database.
    public let name: String

    /// The amount of disk space consumed by this database.
    public let sizeOnDisk: Int

    /// Whether or not this database is empty.
    public let empty: Bool

    /// For sharded clusters, this field includes a document which maps each shard to the size in bytes of the database
    /// on disk on that shard. For non sharded environments, this field is nil.
    public let shards: BSONDocument?
}

/// Internal intermediate result of a ListDatabases command.
internal enum ListDatabasesResults {
    /// Includes the names and sizes.
    case specs([DatabaseSpecification])

    /// Only includes the names.
    case names([String])
}

/// Options for "listDatabases" operations.
public struct ListDatabasesOptions {
    /// Specifies whether to only return databases for which the user has privileges.
    public var authorizedDatabases: Bool?

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(authorizedDatabases: Bool? = nil) {
        self.authorizedDatabases = authorizedDatabases
    }
}

/// An operation corresponding to a "listDatabases" command on a collection.
internal struct ListDatabasesOperation: Operation {
    private let client: MongoClient
    private let filter: BSONDocument?
    private let nameOnly: Bool?
    private let options: ListDatabasesOptions?

    internal init(
        client: MongoClient,
        filter: BSONDocument?,
        nameOnly: Bool?,
        options: ListDatabasesOptions?
    ) {
        self.client = client
        self.filter = filter
        self.nameOnly = nameOnly
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ListDatabasesResults {
        // spec requires that this command be run against the primary.
        let readPref = ReadPreference.primary
        var cmd: BSONDocument = ["listDatabases": 1]
        if let filter = self.filter {
            cmd["filter"] = .document(filter)
        }
        if let nameOnly = self.nameOnly {
            cmd["nameOnly"] = .bool(nameOnly)
        }
        if let authorizedDatabases = self.options?.authorizedDatabases {
            cmd["authorizedDatabases"] = .bool(authorizedDatabases)
        }

        let opts = try encodeOptions(options: nil as BSONDocument?, session: session)

        let reply = try connection.withMongocConnection { connPtr in
            try readPref.withMongocReadPreference { rpPtr in
                try runMongocCommandWithReply(command: cmd, options: opts) { cmdPtr, optsPtr, replyPtr, error in
                    mongoc_client_read_command_with_opts(connPtr, "admin", cmdPtr, rpPtr, optsPtr, replyPtr, &error)
                }
            }
        }

        guard let databases = reply["databases"]?.arrayValue?.compactMap({ $0.documentValue }) else {
            throw MongoError.InternalError(message: "Invalid server response: \(reply)")
        }

        if self.nameOnly ?? false {
            let names: [String] = try databases.map {
                guard let name = $0["name"]?.stringValue else {
                    throw MongoError.InternalError(message: "Server response missing names: \(reply)")
                }
                return name
            }
            return .names(names)
        }

        return try .specs(databases.map { try self.client.decoder.decode(DatabaseSpecification.self, from: $0) })
    }
}
