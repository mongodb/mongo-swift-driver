import mongoc

/// The entity on which to start a change stream.
internal enum ChangeStreamTarget: String, Decodable {
    /// Indicates the change stream will be opened to watch a `MongoClient`.
    case client

    /// Indicates the change stream will be opened to watch a `MongoDatabase`.
    case database

    /// Indicates the change stream will be opened to watch a `MongoCollection`.
    case collection

    // public var rawValue: String {
    //     switch self {
    //     case .client:
    //         return "client"
    //     case .database:
    //         return "database"
    //     case .collection:
    //         return "collection"
    //     }
    // }

    // public init?(rawValue: String) {
    //     switch rawValue {
    //     case "client":
    //         self = .client
    //     case "database":
    //         self = .database
    //     case "collection":
    //         self = .collection
    //     }
    // }
}

internal struct WatchOperation<T: Codable>: Operation {
    private let target: ChangeStreamTarget
    private let pipeline: [Document]
    private let options: ChangeStreamOptions?
    private let session: ClientSession?
    private let client: MongoClient
    // private let withMongocHelper: ((Connection, (OpaquePointer) throws -> T) rethrows -> T)?


    internal init(target: ChangeStreamTarget,
                  pipeline: [Document] = [],
                  options: ChangeStreamOptions? = nil,
                  session: ClientSession? = nil,
                  withEventType: T.Type,
                  client: MongoClient
                  // withMongocHelper: ((Connection, (OpaquePointer) throws -> T) rethrows -> T)? = nil
                  ) {
        self.target = target
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ChangeStream<T> {
        let pipeline: Document = ["pipeline": self.pipeline]
        let opts = try encodeOptions(options: options, session: session)

        switch self.target {
        case .client:
            return try ChangeStream<T>(options: options, client: self.client, decoder: self.client.decoder, session: session) { conn in
                mongoc_client_watch(conn.clientHandle, pipeline._bson, opts?._bson)
            }
        case .database:
            print("not done yet")
            // return try ChangeStream<T>(options: options,
            //                            client: self._client,
            //                            decoder: self.decoder,
            //                            session: session) { conn in
            //     self.withMongocHelper(from: conn) { dbPtr in
            //         mongoc_database_watch(dbPtr, pipeline._bson, opts?._bson)
            //     }
            // }
        case .collection:
            print("not done yet")

            // return try ChangeStream<T>(options: options,
            //                            client: self._client,
            //                            decoder: self.decoder,
            //                            session: session) { conn in
            //     self.withMongocHelper(from: conn) { collPtr in
            //         mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            //     }
            // }
        }
        

        
    }
}
