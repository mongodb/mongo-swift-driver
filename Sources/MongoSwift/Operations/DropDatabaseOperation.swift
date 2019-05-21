import mongoc

/// An operation corresponding to a "drop" command on a MongoDatabase.
internal struct DropDatabaseOperation: Operation {
    private let database: MongoDatabase
    private let session: ClientSession?

    internal init(database: MongoDatabase, session: ClientSession?) {
        self.database = database
        self.session = session
    }

    internal func execute() throws {
        let command: Document = ["dropDatabase": 1]
        let opts = try encodeOptions(options: Document(), session: self.session)

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
