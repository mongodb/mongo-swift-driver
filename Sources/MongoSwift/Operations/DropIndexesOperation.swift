import mongoc

/// Options to use when dropping an index from a `MongoCollection`.
public struct DropIndexOptions: Encodable {
    /// An optional `WriteConcern` to use for the command
    public let writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(writeConcern: WriteConcern? = nil) {
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to a "dropIndexes" command.
internal struct DropIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let index: BSONValue
    private let options: DropIndexOptions?

    internal init(collection: MongoCollection<T>,
                  index: BSONValue,
                  options: DropIndexOptions?) {
        self.collection = collection
        self.index = index
        self.options = options
    }

    internal func execute() throws -> Document {
        let collName = String(cString: mongoc_collection_get_name(self.collection._collection))
        let command: Document = ["dropIndexes": collName, "index": self.index]
        let opts = try self.collection.encoder.encode(self.options)
        let reply = Document()
        var error = bson_error_t()
        guard mongoc_collection_write_command_with_opts(
            self.collection._collection, command.data, opts?.data, reply.data, &error) else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }
        return reply
    }
}
