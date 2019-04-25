import mongoc

/// An operation corresponding to a "drop" command on a MongoCollection.
internal struct DropCollectionOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>

    internal init(collection: MongoCollection<T>) {
        self.collection = collection
    }

    internal func execute() throws {
        var error = bson_error_t()
        guard mongoc_collection_drop(self.collection._collection, &error) else {
            throw parseMongocError(error)
        }
    }
}
