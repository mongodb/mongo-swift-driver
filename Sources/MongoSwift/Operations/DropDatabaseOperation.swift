import mongoc

/// An operation corresponding to a "drop" command on a MongoDatabase.
internal struct DropDatabaseOperation: Operation {
    private let database: MongoDatabase
    private let options: DropDatabaseOptions?

    internal init(database: MongoDatabase, options: DropDatabaseOptions?) {
        self.database = database
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws {
        let command: Document = ["dropDatabase": 1]
        let opts = try encodeOptions(options: self.options, session: session)

        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_database_write_command_with_opts(
                    self.database._database, command._bson, opts?._bson, replyPtr, &error)
        }
        guard success else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }
    }
}
