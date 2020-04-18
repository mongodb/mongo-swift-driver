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
        let command: Document = ["drop": .string(self.collection.name)]
        let opts = try encodeOptions(options: options, session: session)

        var reply = Document()
        var error = bson_error_t()
        let success = self.collection.withMongocCollection(from: connection) { collPtr in
            command.withBSONPointer { cmdPtr in
                withOptionalBSONPointer(to: opts) { optsPtr in
                    reply.withMutableBSONPointer { replyPtr in
                        mongoc_collection_write_command_with_opts(collPtr, cmdPtr, optsPtr, replyPtr, &error)
                    }
                }
            }
        }
        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }
    }
}
