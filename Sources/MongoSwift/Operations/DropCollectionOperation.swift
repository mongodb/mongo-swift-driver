import mongoc

/// An operation corresponding to a "drop" command on a MongoCollection.
internal struct DropCollectionOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let options: DropCollectionOptions?

    internal init(collection: MongoCollection<T>, options: DropCollectionOptions?) {
        self.collection = collection
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws {
        let command: Document = ["drop": self.collection.name]
        let opts = try encodeOptions(options: options, session: session)

        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_collection_write_command_with_opts(
                    self.collection._collection, command._bson, opts?._bson, replyPtr, &error)
        }
        guard success else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }
    }
}
