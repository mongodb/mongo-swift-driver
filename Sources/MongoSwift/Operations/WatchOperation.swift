import mongoc

/// The entity on which to start a change stream.
internal enum ChangeStreamTarget<CollectionType: Codable> {
    /// Indicates the change stream will be opened to watch a `MongoClient`.
    case client(MongoClient)

    /// Indicates the change stream will be opened to watch a `MongoDatabase`.
    case database(MongoDatabase)

    /// Indicates the change stream will be opened to watch a `MongoCollection`.
    case collection(MongoCollection<CollectionType>)
}

/// An operation corresponding to a "watch" command on either a MongoClient, MongoDatabase, or MongoCollection.
internal struct WatchOperation<CollectionType: Codable, ChangeStreamType: Codable>: Operation {
    private let target: ChangeStreamTarget<CollectionType>
    private let pipeline: [Document]
    private let options: ChangeStreamOptions?

    internal var connectionUsage: ConnectionUsage { return .steals }

    internal init(target: ChangeStreamTarget<CollectionType>,
                  pipeline: [Document],
                  options: ChangeStreamOptions?) throws {
        self.target = target
        self.pipeline = pipeline
        self.options = options
    }

    internal func execute(using connection: Connection,
                          session: ClientSession?) throws -> ChangeStream<ChangeStreamType> {
        let pipeline: Document = ["pipeline": self.pipeline]
        let opts = try encodeOptions(options: self.options, session: session)

        let changeStream: OpaquePointer
        let client: MongoClient
        let decoder: BSONDecoder

        switch self.target {
        case let .client(c):
            client = c
            decoder = c.decoder
            changeStream = mongoc_client_watch(connection.clientHandle, pipeline._bson, opts?._bson)
        case let .database(db):
            client = db._client
            decoder = db.decoder
            changeStream = db.withMongocDatabase(from: connection) { dbPtr in
                mongoc_database_watch(dbPtr, pipeline._bson, opts?._bson)
            }
        case let .collection(coll):
            client = coll._client
            decoder = coll.decoder
            changeStream = coll.withMongocCollection(from: connection) { collPtr in
                mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            }
        }

        return try ChangeStream<ChangeStreamType>(changeStream: changeStream,
                                                  connection: connection,
                                                  client: client,
                                                  session: session,
                                                  decoder: decoder,
                                                  options: self.options)
    }
}
