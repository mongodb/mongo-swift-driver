import mongoc

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

/// An operation corresponding to a "distinct" command on a collection.
internal struct ListDatabasesOperation {
    private let filter: Document?
    private let session: ClientSession?
    private let client: MongoClient

    internal init(client: MongoClient,
                  filter: Document?,
                  session: ClientSession?) {
        self.filter = filter
        self.session = session
    }

    internal func execute() throws -> ListDatabasesResult {
        let cmd: Document = ["listDatabases": 1]
        var opts: Document?
        if let filter = self.filter {
            opts = ["filter": filter] as Document
        }
        var reply = Document()
        var error = bson_error_t()

        try withMutableBSONPointer(to: &reply) { replyPtr in
            guard mongoc_client_read_command_with_opts(self.client._client,
                                                       "admin",
                                                       cmd._bson,
                                                       nil,
                                                       opts?._bson,
                                                       replyPtr,
                                                       &error) else {
                throw extractMongoError(error: error, reply: reply)
            }
        }

        return self.client.decoder.decode(ListDatabasesResult.self, from: reply)
    }
}
