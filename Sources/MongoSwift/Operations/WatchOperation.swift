import mongoc

/// The entity on which to start a change stream.
internal enum ChangeStreamTarget: String, Decodable {
    /// Indicates the change stream will be opened to watch a `MongoClient`.
    case client

    /// Indicates the change stream will be opened to watch a `MongoDatabase`.
    case database

    /// Indicates the change stream will be opened to watch a `MongoCollection`.
    case collection
}

internal struct WatchOperation<T: Codable>: Operation {
    private let target: ChangeStreamTarget
    private let pipeline: [Document]
    private let options: ChangeStreamOptions?
    private let client: MongoClient
    private let database: String?
    private let collection: String?

    internal init(target: ChangeStreamTarget,
                  pipeline: [Document] = [],
                  options: ChangeStreamOptions? = nil,
                  client: MongoClient,
                  database: String? = nil,
                  collection: String? = nil
                  ) throws {
        self.target = target
        self.pipeline = pipeline
        self.options = options
        self.client = client
        self.database = database
        self.collection = collection
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ChangeStream<T> {
        let pipeline: Document = ["pipeline": self.pipeline]
        let opts = try encodeOptions(options: self.options, session: session)

        switch self.target {
        case .client:
            return try ChangeStream<T>(options: self.options,
                                       client: self.client,
                                       decoder: self.client.decoder,
                                       session: session) { conn in
                mongoc_client_watch(conn.clientHandle, pipeline._bson, opts?._bson)
            }
        case .database:
            guard let database = self.database else {
                throw RuntimeError.internalError(message: "Watch operation missing db string")
            }
            return try ChangeStream<T>(options: self.options,
                                       client: self.client,
                                       decoder: self.client.decoder,
                                       session: session) { conn in
                self.client.db(database).withMongocDatabase(from: conn) { dbPtr in
                    mongoc_database_watch(dbPtr, pipeline._bson, opts?._bson)
                }
            }
        case .collection:
            guard let collection = self.collection, let database = self.database else {
                throw RuntimeError.internalError(message: "Watch operation missing collection or db string")
            }
            return try ChangeStream<T>(options: self.options,
                                       client: self.client,
                                       decoder: self.client.decoder,
                                       session: session) { conn in
                self.client.db(database).collection(collection).withMongocCollection(from: conn) { collPtr in
                    mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
                }
            }
        }
    }
}
