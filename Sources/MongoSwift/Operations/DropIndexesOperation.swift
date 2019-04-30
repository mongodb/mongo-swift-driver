import mongoc

/// Options to use when dropping an index from a `MongoCollection`.
public struct DropIndexOptions: Encodable {
    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(writeConcern: WriteConcern? = nil) {
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to a "dropIndexes" command.
internal struct DropIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let session: ClientSession?
    private let index: BSONValue
    private let options: DropIndexOptions?

    internal init(collection: MongoCollection<T>,
                  index: BSONValue,
                  options: DropIndexOptions?,
                  session: ClientSession?) {
        self.collection = collection
        self.index = index
        self.options = options
        self.session = session
    }

    internal func execute() throws -> Document {
        let command: Document = ["dropIndexes": self.collection.name, "index": self.index]
        let opts = try encodeOptions(options: self.options, session: self.session, using: self.collection.encoder)

        let reply = Document()
        var error = bson_error_t()
        guard mongoc_collection_write_command_with_opts(
            self.collection._collection, command.data, opts?.data, reply.data, &error) else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }
        return reply
    }
}
