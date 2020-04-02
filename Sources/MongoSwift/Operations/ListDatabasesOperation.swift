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
    public let shards: Document?
}

/// Internal intermediate result of a ListDatabases command.
internal enum ListDatabasesResults {
    /// Includes the names and sizes.
    case specs([DatabaseSpecification])

    /// Only includes the names.
    case names([String])
}

/// An operation corresponding to a "listDatabases" command on a collection.
internal struct ListDatabasesOperation: Operation {
    private let client: MongoClient
    private let filter: Document?
    private let nameOnly: Bool?

    internal init(
        client: MongoClient,
        filter: Document?,
        nameOnly: Bool?
    ) {
        self.client = client
        self.filter = filter
        self.nameOnly = nameOnly
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ListDatabasesResults {
        // spec requires that this command be run against the primary.
        let readPref = ReadPreference(.primary)
        var cmd: Document = ["listDatabases": 1]
        if let filter = self.filter {
            cmd["filter"] = .document(filter)
        }
        if let nameOnly = self.nameOnly {
            cmd["nameOnly"] = .bool(nameOnly)
        }

        let opts = try encodeOptions(options: nil as Document?, session: session)
        var reply = Document()
        var error = bson_error_t()

        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_client_read_command_with_opts(
                connection.clientHandle,
                "admin",
                cmd._bson,
                readPref.pointer,
                opts?._bson,
                replyPtr,
                &error
            )
        }

        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }

        guard let databases = reply["databases"]?.arrayValue?.asArrayOf(Document.self) else {
            throw InternalError(message: "Invalid server response: \(reply)")
        }

        if self.nameOnly ?? false {
            let names: [String] = try databases.map {
                guard let name = $0["name"]?.stringValue else {
                    throw InternalError(message: "Server response missing names: \(reply)")
                }
                return name
            }
            return .names(names)
        }

        return try .specs(databases.map { try self.client.decoder.decode(DatabaseSpecification.self, from: $0) })
    }
}
