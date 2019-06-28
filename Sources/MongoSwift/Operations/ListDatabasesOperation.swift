import mongoc

/// Options to use when listing available databases.
public struct ListDatabasesOptions: Encodable {
    /// Optionally indicate whether only names should be returned.
    /// This is internal and only used for implementation purposes. Users should use `listDatabaseNames` if they want
    /// only names.
    internal var nameOnly: Bool?

    /// Convenience constructor for basic construction
    public init(nameOnly: Bool? = nil) {
        self.nameOnly = nameOnly
    }
}

/// A struct modeling a response to the `listDatabases` command.
public struct ListDatabasesResult: Codable {
    /// The list of database information returned.
    public let databases: [DatabaseSpecification]

    /// The total size in bytes of all the matching databases.
    public let totalSize: Int64
}

/// A struct modeling the information returned from the `listDatabases` command about a single database.
public struct DatabaseSpecification: Codable {
    /// The name of the database.
    public let name: String

    /// The amount of disk space consumed by this database.
    public let sizeOnDisk: Int

    /// Whether or not this database is empty.
    public let empty: Bool
}

/// Internal intermediate result of a ListDatabases command.
internal enum ListDatabasesResults {
    /// Includes the names and sizes.
    case full(ListDatabasesResult)

    /// Only includes the names.
    case names([String])
}

/// An operation corresponding to a "distinct" command on a collection.
internal struct ListDatabasesOperation {
    private let filter: Document?
    private let session: ClientSession?
    private let client: MongoClient
    private let options: ListDatabasesOptions?

    internal init(client: MongoClient,
                  filter: Document?,
                  options: ListDatabasesOptions?,
                  session: ClientSession?) {
        self.client = client
        self.filter = filter
        self.options = options
        self.session = session
    }

    internal func execute() throws -> ListDatabasesResults {
        let cmd: Document = ["listDatabases": 1]
        var opts = try self.client.encoder.encode(self.options)
        if let filter = self.filter {
            if opts == nil {
                opts = Document()
            }
            opts = ["filter": filter] as Document
        }
        opts = try encodeOptions(options: opts, session: self.session)
        var reply = Document()
        var error = bson_error_t()

        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_client_read_command_with_opts(self.client._client,
                                                 "admin",
                                                 cmd._bson,
                                                 nil,
                                                 opts?._bson,
                                                 replyPtr,
                                                 &error)
        }

        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }

        if self.options?.nameOnly ?? false {
            guard let databases = reply["databases"] as? [Document] else {
                throw RuntimeError.internalError(message: "Invalid server response: \(reply)")
            }
            return .names(databases.map { $0["name"] as? String ?? "" })
        }
        return .full(try self.client.decoder.decode(ListDatabasesResult.self, from: reply))
    }
}
