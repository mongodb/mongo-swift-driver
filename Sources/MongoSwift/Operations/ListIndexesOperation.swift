import CLibMongoC

/// An operation corresponding to a listIndexes command on a collection.
internal struct ListIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>

    internal init(collection: MongoCollection<T>) {
        self.collection = collection
    }

    internal func execute(
        using connection: Connection,
        session: ClientSession?
    ) throws -> MongoCursor<IndexModel> {
        let opts = try encodeOptions(options: nil as Document?, session: session)

        let cursor: OpaquePointer = self.collection.withMongocCollection(from: connection) { collPtr in
            guard let indexes = mongoc_collection_find_indexes_with_opts(collPtr, opts?._bson) else {
                fatalError(failedToRetrieveCursorMessage)
            }
            return indexes
        }

        return try MongoCursor(
            stealing: cursor,
            connection: connection,
            client: self.collection._client,
            decoder: self.collection.decoder,
            session: session
        )
    }
}
