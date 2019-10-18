import mongoc

/// The entity on which to start a change stream.
internal enum ChangeStreamTarget<CollectionType: Codable> {
    /// Indicates the change stream will be opened to watch a client.
    case client(SyncMongoClient)

    /// Indicates the change stream will be opened to watch a database.
    case database(SyncMongoDatabase)

    /// Indicates the change stream will be opened to watch a collection.
    case collection(SyncMongoCollection<CollectionType>)
}

/// An operation corresponding to a "watch" command on either a client, database, or collection.
internal struct WatchOperation<CollectionType: Codable, ChangeStreamType: Codable>: Operation {
    private let target: ChangeStreamTarget<CollectionType>
    private let pipeline: BSON
    private let options: ChangeStreamOptions?
    internal let connectionStrategy: ConnectionStrategy

    internal init(target: ChangeStreamTarget<CollectionType>,
                  pipeline: [Document],
                  options: ChangeStreamOptions?,
                  stealing connection: Connection) throws {
        self.target = target
        self.pipeline = .array(pipeline.map { .document($0) })
        self.options = options
        self.connectionStrategy = .bound(to: connection)
    }

    internal func execute(using connection: Connection,
                          session: SyncClientSession?) throws -> SyncChangeStream<ChangeStreamType> {
        let pipeline: Document = ["pipeline": self.pipeline]
        let opts = try encodeOptions(options: self.options, session: session)

        let changeStream: OpaquePointer
        let client: SyncMongoClient
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

        return try SyncChangeStream<ChangeStreamType>(stealing: changeStream,
                                                      connection: connection,
                                                      client: client,
                                                      session: session,
                                                      decoder: decoder,
                                                      options: self.options)
    }
}
