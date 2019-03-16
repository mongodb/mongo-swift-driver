import bson
import mongoc

internal struct UpdateOneOperation<CollectionType: Codable>: Operation {
    internal var collection: MongoCollection<CollectionType>
    internal var filter: Document
    internal var update: Document
    internal var options: UpdateOptions?

    public init(_ collection: MongoCollection<CollectionType>,
                _ filter: Document,
                _ update: Document,
                _ options: UpdateOptions? = nil) {
        self.collection = collection
        self.filter = filter
        self.update = update
        self.options = options
    }

    public func execute() throws -> UpdateResult? {
        let encoder = BSONEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        let collection = self.collection._collection
        guard mongoc_collection_update_one(
            collection, filter.data, update.data, opts?.data, reply.data, &error) else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }

        guard self.collection.isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try BSONDecoder().internalDecode(
                UpdateResult.self,
                from: reply,
                withError: "Couldn't understand response from the server.")
    }

}
