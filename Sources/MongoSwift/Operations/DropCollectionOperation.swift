import CLibMongoC

/// An operation corresponding to a "drop" command on a collection.
internal struct DropCollectionOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let options: DropCollectionOptions?

    internal init(collection: MongoCollection<T>, options: DropCollectionOptions?) {
        self.collection = collection
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws {
        let command: BSONDocument = ["drop": .string(self.collection.name)]
        let opts = try encodeOptions(options: options, session: session)

        do {
            try self.collection.withMongocCollection(from: connection) { collPtr in
                try runMongocCommand(command: command, options: opts) { cmdPtr, optsPtr, replyPtr, error in
                    mongoc_collection_write_command_with_opts(collPtr, cmdPtr, optsPtr, replyPtr, &error)
                }
            }
        } catch let error as MongoErrorProtocol {
            guard !error.isNsNotFound else {
                return
            }
            throw error
        }
    }
}
