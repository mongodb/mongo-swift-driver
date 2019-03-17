import bson
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

/// The result of an `insertOne` command on a `MongoCollection`.
public struct InsertOneResult {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BSONValue
}

internal struct InsertOneOperation<CollectionType: Codable>: Operation {
    internal var ns: MongoNamespace
    internal var value: CollectionType
    internal var options: InsertOneOptions?
    internal var collection: MongoCollection<CollectionType>

    public init(ns: MongoNamespace,
                _ collection: MongoCollection<CollectionType>,
                _ value: CollectionType,
                _ options: InsertOneOptions? = nil) {
        self.ns = ns
        self.value = value
        self.options = options
        self.collection = collection
    }

    public func execute(client: OpaquePointer) throws -> InsertOneResult? {
        let encoder = BSONEncoder()
        let document = try encoder.encode(value).withID()
        let opts = try encoder.encode(options)
        var error = bson_error_t()
        let reply = Document()

        let collection = mongoc_client_get_collection(client, self.ns.db, self.ns.collection!)
        guard mongoc_collection_insert_one(collection, document.data, opts?.data, reply.data, &error) else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }

        guard self.collection.isAcknowledged(options?.writeConcern) else {
            return nil
        }

        guard let insertedId = try document.getValue(for: "_id") else {
            // we called `withID()`, so this should be present.
            fatalError("Failed to get value for _id from document")
        }

        return InsertOneResult(insertedId: insertedId)
    }
}
