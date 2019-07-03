import mongoc

/// Options to use when listing available databases.
internal struct ListDatabasesOptions: Encodable {
    /// Optional `Document` specifying a filter that the listed databases must pass.
    internal var filter: Document?

    /// Optionally indicate whether only names should be returned.
    /// This is internal and only used for implementation purposes. Users should use `listDatabaseNames` if they want
    /// only names.
    internal var nameOnly: Bool?

    /// Convenience constructor for basic construction
    internal init(filter: Document?, nameOnly: Bool?) {
        self.filter = filter
        self.nameOnly = nameOnly
    }
}

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
    private let session: ClientSession?
    private let client: MongoClient
    private let options: ListDatabasesOptions?

    internal init(client: MongoClient,
                  options: ListDatabasesOptions?,
                  session: ClientSession?) {
        self.client = client
        self.options = options
        self.session = session
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ListDatabasesResults {
        // spec requires that this command be run against the primary.
        let readPref = ReadPreference(.primary)
        let cmd: Document = ["listDatabases": 1]
        let opts = try encodeOptions(options: self.options, session: self.session)
        var reply = Document()
        var error = bson_error_t()

        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_client_read_command_with_opts(self.client._client,
                                                 "admin",
                                                 cmd._bson,
                                                 readPref._readPreference,
                                                 opts?._bson,
                                                 replyPtr,
                                                 &error)
        }

        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }

        guard let databases = reply["databases"] as? [Document] else {
            throw RuntimeError.internalError(message: "Invalid server response: \(reply)")
        }

        if self.options?.nameOnly ?? false {
            return .names(databases.map { $0["name"] as? String ?? "" })
        }

        return try .specs(databases.map { try self.client.decoder.decode(DatabaseSpecification.self, from: $0) })
    }
}
