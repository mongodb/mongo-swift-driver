import CLibMongoC

/// An operation corresponding to a "createIndexes" command.
internal struct RenamedCollectionOperation<T: Codable>: Operation {
    private var collection: MongoCollection<T>
    private let to: String
    private let dropTarget: Bool
    private let options: RenamedCollectionOptions?

    internal init(
        collection: MongoCollection<T>,
        to: String,
        dropTarget: Bool,
        options: RenamedCollectionOptions? = nil
    ) {
        self.collection = collection
        self.to = to
        self.dropTarget = dropTarget
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> MongoCollection<T> {
        let opts = try encodeOptions(options: options, session: session)
        var error = bson_error_t()
        return try self.collection.withMongocCollection(from: connection) { collPtr in
            try withOptionalBSONPointer(to: opts) { optsPtr in
                let success = mongoc_collection_rename_with_opts(
                    collPtr,
                    nil,
                    self.to,
                    self.dropTarget,
                    optsPtr,
                    &error
                )

                guard success else {
                    throw extractMongoError(error: error)
                }

                let db = self.collection._client.db(self.collection.namespace.db)
                let opts = self.collection.options
                return MongoCollection(name: self.to, database: db, options: opts)
            }
        }
    }
}
