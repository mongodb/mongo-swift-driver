import mongoc

/// An operation corresponding to a "drop" command on a MongoCollection.
internal struct DropCollectionOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let session: ClientSession?
    private let options: DropCollectionOptions?

    internal init(collection: MongoCollection<T>, options: DropCollectionOptions?, session: ClientSession?) {
        self.collection = collection
        self.options = options
        self.session = session
    }

    internal func execute() throws {
        let command: Document = ["drop": self.collection.name]
        let opts = try encodeOptions(options: options, session: self.session)

        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_collection_write_command_with_opts(
                    self.collection._collection, command._bson, opts?._bson, replyPtr, &error)
        }
        guard success else {
            throw getMongoError(error: error)
        }
    }
}
