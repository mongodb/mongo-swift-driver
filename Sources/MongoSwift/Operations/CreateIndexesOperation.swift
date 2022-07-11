import CLibMongoC

/// Options to use when creating a new index on a `MongoCollection`.
public struct CreateIndexOptions: Encodable {
    /// A comment to help trace the operation through the database profiler,
    /// currentOp and logs. Can be any valid BSON type. Only supported on server
    /// versions 4.4 and above.
    /// The default is to not send a value.
    public var comment: BSON?

    /// The maximum amount of time to allow the query to run - enforced server-side.
    public var maxTimeMS: Int?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(
        comment: BSON? = nil,
        maxTimeMS: Int? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.comment = comment
        self.maxTimeMS = maxTimeMS
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to a "createIndexes" command.
internal struct CreateIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let models: [IndexModel]
    private let options: CreateIndexOptions?

    internal init(collection: MongoCollection<T>, models: [IndexModel], options: CreateIndexOptions?) {
        self.collection = collection
        self.models = models
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> [String] {
        var indexData = [BSON]()
        var indexNames = [String]()
        for index in self.models {
            var indexDoc = try self.collection.encoder.encode(index)

            if let indexName = index.options?.name {
                indexNames.append(indexName)
            } else {
                let indexName = try index.getDefaultName()
                indexDoc["name"] = .string(indexName)
                indexNames.append(indexName)
            }

            indexData.append(.document(indexDoc))
        }

        let command: BSONDocument = ["createIndexes": .string(self.collection.name), "indexes": .array(indexData)]

        let opts = try encodeOptions(options: options, session: session)

        try self.collection.withMongocCollection(from: connection) { collPtr in
            try runMongocCommand(command: command, options: opts) { cmdPtr, optsPtr, replyPtr, error in
                mongoc_collection_write_command_with_opts(collPtr, cmdPtr, optsPtr, replyPtr, &error)
            }
        }

        return indexNames
    }
}
