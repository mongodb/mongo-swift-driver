import mongoc

/// Options to use when creating a new index on a `MongoCollection` or a `SyncMongoCollection`.
public struct CreateIndexOptions: Encodable {
    /// The maximum amount of time to allow the query to run - enforced server-side.
    public var maxTimeMS: Int64?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(maxTimeMS: Int64? = nil, writeConcern: WriteConcern? = nil) {
        self.maxTimeMS = maxTimeMS
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to a "createIndexes" command.
internal struct CreateIndexesOperation<T: Codable>: Operation {
    private let collection: SyncMongoCollection<T>
    private let models: [IndexModel]
    private let options: CreateIndexOptions?

    internal init(collection: SyncMongoCollection<T>, models: [IndexModel], options: CreateIndexOptions?) {
        self.collection = collection
        self.models = models
        self.options = options
    }

    internal func execute(using connection: Connection, session: SyncClientSession?) throws -> [String] {
        var indexData = [BSON]()
        for index in self.models {
            var indexDoc = try self.collection.encoder.encode(index)
            if indexDoc["name"] == nil {
                indexDoc["name"] = .string(index.defaultName)
            }
            indexData.append(.document(indexDoc))
        }

        let command: Document = ["createIndexes": .string(self.collection.name), "indexes": .array(indexData)]

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
        return self.models.map { $0.options?.name ?? $0.defaultName }
    }
}
