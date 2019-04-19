import mongoc

/// Options to use when executing an `insertOne` command on a `MongoCollection`.
public struct InsertOneOptions: Encodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// An optional WriteConcern to use for the command.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing bypassDocumentValidation to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to an "insertOne" command on a collection.
internal struct InsertOneOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let value: T
    private let options: InsertOneOptions?

    internal init(collection: MongoCollection<T>,
                  value: T,
                  options: InsertOneOptions?) {
        self.collection = collection
        self.value = value
        self.options = options
    }

    internal func execute() throws -> InsertOneResult? {
        let document = try self.collection.encoder.encode(self.value).withID()
        let opts = try self.collection.encoder.encode(self.options)
        var error = bson_error_t()
        let reply = Document()
        guard mongoc_collection_insert_one(
            self.collection._collection, document.data, opts?.data, reply.data, &error) else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }

        guard self.collection.isAcknowledged(self.options?.writeConcern) else {
            return nil
        }

        guard let insertedId = try document.getValue(for: "_id") else {
            // we called `withID()`, so this should be present.
            fatalError("Failed to get value for _id from document")
        }

        return InsertOneResult(insertedId: insertedId)
    }
}

/// The result of an `insertOne` command on a `MongoCollection`.
public struct InsertOneResult {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BSONValue
}
