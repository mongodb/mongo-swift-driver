import mongoc

/// An operation corresponding to a "drop" command on a collection.
internal struct DropCollectionOperation<T: Codable>: Operation {
    private let collection: SyncMongoCollection<T>
    private let options: DropCollectionOptions?

    internal init(collection: SyncMongoCollection<T>, options: DropCollectionOptions?) {
        self.collection = collection
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws {
        let command: Document = ["drop": .string(self.collection.name)]
        let opts = try encodeOptions(options: options, session: session)

        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            self.collection.withMongocCollection(from: connection) { collPtr in
                mongoc_collection_write_command_with_opts(collPtr, command._bson, opts?._bson, replyPtr, &error)
            }
        }
        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }
    }
}
