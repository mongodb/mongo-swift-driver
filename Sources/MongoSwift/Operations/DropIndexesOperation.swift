import CLibMongoC

/// Options to use when dropping an index from a `MongoCollection`.
public struct DropIndexOptions: Encodable {
    /// The maximum amount of time to allow the query to run - enforced server-side.
    public var maxTimeMS: Int?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(maxTimeMS: Int? = nil, writeConcern: WriteConcern? = nil) {
        self.maxTimeMS = maxTimeMS
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to a "dropIndexes" command.
internal struct DropIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let index: BSON
    private let options: DropIndexOptions?

    internal init(collection: MongoCollection<T>, index: BSON, options: DropIndexOptions?) {
        self.collection = collection
        self.index = index
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws {
        let command: BSONDocument = ["dropIndexes": .string(self.collection.name), "index": self.index]
        let opts = try encodeOptions(options: self.options, session: session)

        do {
            try self.collection.withMongocCollection(from: connection) { collPtr in
                try runMongocCommand(command: command, options: opts) { cmdPtr, optsPtr, replyPtr, error in
                    mongoc_collection_write_command_with_opts(collPtr, cmdPtr, optsPtr, replyPtr, &error)
                }
            }
        } catch let error as MongoErrorProtocol {
            guard !error.isNsNotFound else {
                return
            }
            throw error
        }
    }
}
