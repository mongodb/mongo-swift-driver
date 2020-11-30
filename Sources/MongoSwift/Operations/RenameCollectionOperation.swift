import CLibMongoC

/// An operation corresponding to a "createIndexes" command.
internal struct RenameCollectionOperation<T: Codable>: Operation {
    private var collection: MongoCollection<T>
    private let to: String
    private let options: RenameCollectionOptions?

    internal init(
        collection: MongoCollection<T>,
        to: String,
        options: RenameCollectionOptions? = nil
    ) {
        self.collection = collection
        self.to = to
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> MongoCollection<T> {
        let opts = try encodeOptions(options: options, session: session)
        var error = bson_error_t()
        var dropTarget = false
        if let dt = options?.dropTarget {
            dropTarget = dt
        }

        return try self.collection.withMongocCollection(from: connection) { collPtr in
            try withOptionalBSONPointer(to: opts) { optsPtr in
                let success = mongoc_collection_rename_with_opts(
                    collPtr,
                    self.collection.namespace.db,
                    self.to,
                    dropTarget,
                    optsPtr,
                    &error
                )

                guard success else {
                    throw extractMongoError(error: error)
                }

                return MongoCollection(copying: self.collection, name: self.to)
            }
        }
    }
}
