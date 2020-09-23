import CLibMongoC

/// Options to use when running a command against a `MongoDatabase`.
public struct RunCommandOptions: Encodable {
    /// An optional `ReadConcern` to use for this operation. This option should only be used when executing a command
    /// that reads.
    public var readConcern: ReadConcern?

    /// An optional `ReadPreference` to use for this operation. This option should only be used when executing a
    /// command that reads.
    public var readPreference: ReadPreference?

    /// An optional `WriteConcern` to use for this operation. This option should only be used when executing a command
    /// that writes.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.writeConcern = writeConcern
    }

    private enum CodingKeys: String, CodingKey {
        case readConcern, writeConcern
    }
}

/// An operation corresponding to a `runCommand` call.
internal struct RunCommandOperation: Operation {
    private let database: MongoDatabase
    private let command: BSONDocument
    private let options: RunCommandOptions?
    private let serverAddress: ServerAddress?

    internal init(
        database: MongoDatabase,
        command: BSONDocument,
        options: RunCommandOptions?,
        serverAddress: ServerAddress? = nil
    ) {
        self.database = database
        self.command = command
        self.options = options
        self.serverAddress = serverAddress
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> BSONDocument {
        let serverId: UInt32? = try self.serverAddress.map { address in
            let id: UInt32? = connection.withMongocConnection { connection in
                var numServers = 0
                let sds = mongoc_client_get_server_descriptions(connection, &numServers)
                defer { mongoc_server_descriptions_destroy_all(sds, numServers) }

                guard numServers > 0 else {
                    return nil
                }

                let buffer = UnsafeBufferPointer(start: sds, count: numServers)
                // the buffer is documented as always containing non-nil pointers (if non-empty).
                // swiftlint:disable:next force_unwrapping
                let servers = Array(buffer).map { ServerDescription($0!) }
                return servers.first { $0.address == address }?.serverId
            }

            guard let out = id else {
                throw MongoError.ServerSelectionError(message: "No known host with address \(address)")
            }

            return out
        }

        var opts = try encodeOptions(options: self.options, session: session)
        if let id = serverId {
            opts = opts ?? [:]
            opts?["serverId"] = .int64(Int64(id))
        }

        return try self.database.withMongocDatabase(from: connection) { dbPtr in
            try ReadPreference.withOptionalMongocReadPreference(from: self.options?.readPreference) { rpPtr in
                try runMongocCommandWithReply(
                    command: self.command,
                    options: opts
                ) { cmdPtr, optsPtr, replyPtr, error in
                    mongoc_database_command_with_opts(dbPtr, cmdPtr, rpPtr, optsPtr, replyPtr, &error)
                }
            }
        }
    }
}
