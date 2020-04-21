import CLibMongoC

/// An operation corresponding to a "drop" command on a database.
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
        let success = self.database.withMongocDatabase(from: connection) { dbPtr in
            command.withBSONPointer { cmdPtr in
                withOptionalBSONPointer(to: opts) { optsPtr in
                    reply.withMutableBSONPointer { replyPtr in
                        mongoc_database_write_command_with_opts(dbPtr, cmdPtr, optsPtr, replyPtr, &error)
                    }
                }
            }
        }
        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }
    }
}
