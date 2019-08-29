import mongoc

/// Internal intermediate result of a ListCollections command.
internal enum ListCollectionsResults {
    /// Includes the names and sizes.
    case specs(MongoCursor<CollectionSpecification>)

    /// Only includes the names.
    case names([String])
}

/// An operation corresponding to a "listCollections" command on a database.
internal struct ListCollectionsOperation: Operation {
	private let database: MongoDatabase
	private let options: Document?
	private let nameOnly: Bool?

	internal init(database: MongoDatabase, options: Document?, nameOnly: Bool?) {
		self.database = database
		self.options = options
		self.nameOnly = nameOnly
	}

	internal func execute(using connection: Connection, session: ClientSession?) throws -> ListCollectionsResults {
		let cursor: MongoCursor<CollectionSpecification> = try MongoCursor(client: self.database._client,
																		   decoder: self.database.decoder,
																		   session: session) { conn in
            self.database.withMongocDatabase(from: conn) { dbPtr in
                guard let collections = mongoc_database_find_collections_with_opts(dbPtr, self.options?._bson) else {
                    fatalError(failedToRetrieveCursorMessage)
                }
                return collections
            }
        }
        if self.nameOnly ?? false {
        	var names = [String]()
        	for collection in cursor {
        		names.append(collection.name)
        	}
        	return .names(names)
        }
        return .specs(cursor)
    }
}
