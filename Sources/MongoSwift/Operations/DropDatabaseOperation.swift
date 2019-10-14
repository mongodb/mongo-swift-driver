import mongoc

/// An operation corresponding to a "drop" command on a database.
internal struct DropDatabaseOperation: Operation {
    private let database: SyncMongoDatabase
    private let options: DropDatabaseOptions?

    internal init(database: SyncMongoDatabase, options: DropDatabaseOptions?) {
        self.database = database
        self.options = options
    }

    internal func execute(using connection: Connection, session: SyncClientSession?) throws {
        let command: Document = ["dropDatabase": 1]
        let opts = try encodeOptions(options: self.options, session: session)

        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            self.database.withMongocDatabase(from: connection) { dbPtr in
                mongoc_database_write_command_with_opts(dbPtr, command._bson, opts?._bson, replyPtr, &error)
            }
        }
        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }
    }
}
