import mongoc

/// An operation corresponding to a "drop" command on a MongoDatabase.
internal struct DropDatabaseOperation: Operation {
    private let database: MongoDatabase

    internal init(database: MongoDatabase) {
        self.database = database
    }

    internal func execute() throws {
        var error = bson_error_t()
        guard mongoc_database_drop(self.database._database, &error) else {
            throw parseMongocError(error)
        }
    }
}
