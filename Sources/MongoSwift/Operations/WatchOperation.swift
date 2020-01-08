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
        pipeline: [Document],
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
        let pipeline: Document = ["pipeline": self.pipeline]
        let opts = try encodeOptions(options: self.options, session: session)

        let changeStreamPtr: OpaquePointer
        let client: MongoClient
        let decoder: BSONDecoder

        switch self.target {
        case let .client(c):
            client = c
            decoder = c.decoder
            changeStreamPtr = mongoc_client_watch(connection.clientHandle, pipeline._bson, opts?._bson)
        case let .database(db):
            client = db._client
            decoder = db.decoder
            changeStreamPtr = db.withMongocDatabase(from: connection) { dbPtr in
                mongoc_database_watch(dbPtr, pipeline._bson, opts?._bson)
            }
        case let .collection(coll):
            client = coll._client
            decoder = coll.decoder
            changeStreamPtr = coll.withMongocCollection(from: connection) { collPtr in
                mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            }
        }

        let changeStream = ChangeStream<ChangeStreamType>(
            stealing: changeStreamPtr,
            connection: connection,
            client: client,
            session: session,
            decoder: decoder,
            options: self.options
        )

        if let error = changeStream.getChangeStreamError() {
            try changeStream.close().wait()
            throw error
        }

        return changeStream
    }
}
