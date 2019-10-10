import mongoc

/// An operation corresponding to a listIndexes command on a collection.
internal struct ListIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>

    internal init(collection: MongoCollection<T>) {
        self.collection = collection
    }

    internal func execute(using _: Connection, session: ClientSession?) throws -> MongoCursor<IndexModel> {
        let opts = try encodeOptions(options: nil as Document?, session: session)

        return try MongoCursor(
            client: self.collection._client,
            decoder: self.collection.decoder,
            session: session
        ) { conn in
            self.collection.withMongocCollection(from: conn) { collPtr in
                guard let indexes = mongoc_collection_find_indexes_with_opts(collPtr, opts?._bson) else {
                    fatalError(failedToRetrieveCursorMessage)
                }
                return indexes
            }
        }
    }
}
