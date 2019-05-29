import mongoc

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
    public init(readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil,
                writeConcern: WriteConcern? = nil) {
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
    private let command: Document
    private let options: RunCommandOptions?
    private let session: ClientSession?

    internal init(database: MongoDatabase, command: Document, options: RunCommandOptions?, session: ClientSession?) {
        self.database = database
        self.command = command
        self.options = options
        self.session = session
    }

    internal func execute() throws -> Document {
        let rp = self.options?.readPreference?._readPreference
        let opts = try encodeOptions(options: self.options, session: self.session)
        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_database_command_with_opts(
                self.database._database, self.command._bson, rp, opts?._bson, replyPtr, &error)
        }
        guard success else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }
        return reply
    }
}
