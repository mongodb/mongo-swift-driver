import CLibMongoC

/// Options to use when dropping an index from a `MongoCollection`.
public struct DropIndexOptions: Encodable {
    /// A comment to help trace the index through the database profiler,
    /// currentOp and logs. Can be any valid BSON type for server versions
    /// 4.4 and above but older server versions only support string comments
    /// (non-string types cause server-side errors). The default is to not send a value.
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
