import mongoc

/// Options to use when executing a `delete` command on a `MongoCollection`.
public struct DeleteOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

     /// Convenience initializer allowing collation to be omitted or optional
    public init(collation: Document? = nil, writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to a `delete` command on a collection.
internal struct DeleteOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let filter: Document
    private let options: DeleteOptions?
    private let type: DeleteType

    internal enum DeleteType {
        case deleteOne, deleteMany
    }

    internal init(collection: MongoCollection<T>,
                  filter: Document,
                  options: DeleteOptions?,
                  type: DeleteType) {
        self.collection = collection
        self.filter = filter
        self.options = options
        self.type = type
    }

    internal func execute() throws -> DeleteResult? {
        let opts = try self.collection.encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()

        var result: Bool!
        switch self.type {
        case .deleteOne:
            result = mongoc_collection_delete_one(
                self.collection._collection, self.filter.data, opts?.data, reply.data, &error)
        case .deleteMany:
            result = mongoc_collection_delete_many(
                self.collection._collection, self.filter.data, opts?.data, reply.data, &error)
        }

        guard result else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }

        guard self.collection.isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try self.collection.decoder.internalDecode(
                DeleteResult.self,
                from: reply,
                withError: "Couldn't understand response from the server.")
    }
}

/// The result of a `delete` command on a `MongoCollection`.
public struct DeleteResult: Decodable {
    /// The number of documents that were deleted.
    public let deletedCount: Int
}
