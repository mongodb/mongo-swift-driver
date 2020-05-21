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
        let command: BSONDocument = ["dropDatabase": 1]
        let opts = try encodeOptions(options: self.options, session: session)

        try runMongocCommand(command: command, options: opts) { cmdPtr, optsPtr, replyPtr, error in
            self.database.withMongocDatabase(from: connection) { dbPtr in
                mongoc_database_write_command_with_opts(dbPtr, cmdPtr, optsPtr, replyPtr, &error)
            }
        }
    }
}
