import CLibMongoC

/// The entity on which to start a change stream.
internal enum ChangeStreamTarget<CollectionType: Codable> {
    /// Indicates the change stream will be opened to watch a client.
    case client(MongoClient)

    /// Indicates the change stream will be opened to watch a database.
    case database(MongoDatabase)

    /// Indicates the change stream will be opened to watch a collection.
    case collection(MongoCollection<CollectionType>)
}

/// An operation corresponding to a "watch" command on either a client, database, or collection.
internal struct WatchOperation<CollectionType: Codable, ChangeStreamType: Codable>: Operation {
    private let target: ChangeStreamTarget<CollectionType>
    private let pipeline: BSON
    private let options: ChangeStreamOptions?

    internal init(
        target: ChangeStreamTarget<CollectionType>,
        pipeline: [BSONDocument],
        options: ChangeStreamOptions?
    ) {
        self.target = target
        self.pipeline = .array(pipeline.map { .document($0) })
        self.options = options
    }

    internal func execute(
        using connection: Connection,
        session: ClientSession?
    ) throws -> ChangeStream<ChangeStreamType> {
        let pipeline: BSONDocument = ["pipeline": self.pipeline]
        let opts = try encodeOptions(options: self.options, session: session)

        return try pipeline.withBSONPointer { pipelinePtr in
            try withOptionalBSONPointer(to: opts) { optsPtr in
                let changeStreamPtr: OpaquePointer
                let client: MongoClient
                let decoder: BSONDecoder
                let namespace: MongoNamespace

                switch self.target {
                case let .client(c):
                    client = c
                    decoder = c.decoder
                    // workaround for the need for a namespace as described in SWIFT-981.
                    namespace = MongoNamespace(db: "", collection: nil)
                    changeStreamPtr = connection.withMongocConnection { connPtr in
                        mongoc_client_watch(connPtr, pipelinePtr, optsPtr)
                    }

                case let .database(db):
                    client = db._client
                    decoder = db.decoder
                    namespace = db.namespace
                    changeStreamPtr = db.withMongocDatabase(from: connection) { dbPtr in
                        mongoc_database_watch(dbPtr, pipelinePtr, optsPtr)
                    }
                case let .collection(coll):
                    client = coll._client
                    decoder = coll.decoder
                    namespace = coll.namespace
                    changeStreamPtr = coll.withMongocCollection(from: connection) { collPtr in
                        mongoc_collection_watch(collPtr, pipelinePtr, optsPtr)
                    }
                }

                return try ChangeStream<ChangeStreamType>(
                    stealing: changeStreamPtr,
                    connection: connection,
                    client: client,
                    namespace: namespace,
                    session: session,
                    decoder: decoder,
                    options: self.options
                )
            }
        }
    }
}
