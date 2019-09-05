import mongoc

/// Internal intermediate result of a ListIndexes command.
internal enum ListIndexesResults {
    /// Includes the name, namespace, version, keys, and options of each index.
    case specs(MongoCursor<IndexModel>)

    /// Only includes the names.
    case names([String])
}

/// An operation corresponding to a listIndex command on a collection.
internal struct ListIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let nameOnly: Bool

    internal init(collection: MongoCollection<T>, nameOnly: Bool) {
        self.collection = collection
        self.nameOnly = nameOnly
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ListIndexesResults {
        let opts = try encodeOptions(options: Document(), session: session)

        let initializer = { (conn: Connection) -> OpaquePointer in
            self.collection.withMongocCollection(from: conn) { collPtr in
                guard let indexes = mongoc_collection_find_indexes_with_opts(collPtr, opts?._bson) else {
                    fatalError(failedToRetrieveCursorMessage)
                }
                return indexes
            }
        }
        let toPrint: MongoCursor<Document> = try MongoCursor(client: self.collection._client,
                                                                decoder: self.collection.decoder,
                                                                session: session,
                                                                initializer: initializer)
        print("here is the original document:")
        toPrint.map { print($0) }

        if self.nameOnly {
            let cursor: MongoCursor<Document> = try MongoCursor(client: self.collection._client,
                                                                decoder: self.collection.decoder,
                                                                session: session,
                                                                initializer: initializer)
            return .names(cursor.map { $0["name"] as? String ?? "" })
        }
        let cursor: MongoCursor<IndexModel> = try MongoCursor(client: self.collection._client,
                                                              decoder: self.collection.decoder,
                                                              session: session,
                                                              initializer: initializer)
        return .specs(cursor)
    }
}