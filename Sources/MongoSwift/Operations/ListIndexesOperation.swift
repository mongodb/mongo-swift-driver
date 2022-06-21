import CLibMongoC

/// Internal intermediate result of a ListIndexes command.
internal enum ListIndexesResults {
    /// Includes the name, keys, and creation options of each index.
    case models(MongoCursor<IndexModel>)

    /// Only includes the names.
    case names([String])
}

/// Options to use when creating listing indexes on a `MongoCollection`.
public struct ListIndexOptions: Encodable {
    /// Enables users to specify an arbitrary BSON type to help trace the operation through
    /// the database profiler, currentOp and logs. The default is to not send a value.
    public var comment: BSON?

    /// Initializer allowing any/all parameters to be omitted.
    public init(comment: BSON? = nil) {
        self.comment = comment
    }
}

/// An operation corresponding to a "listIndexes" command on a collection.
internal struct ListIndexesOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let nameOnly: Bool
    private let options: ListIndexOptions?

    internal init(collection: MongoCollection<T>, nameOnly: Bool, options: ListIndexOptions?) {
        self.collection = collection
        self.nameOnly = nameOnly
        self.options = options
    }

    internal func execute(
        using connection: Connection,
        session: ClientSession?
    ) throws -> ListIndexesResults {
        let opts = try encodeOptions(options: options, session: session)

        let indexes: OpaquePointer = self.collection.withMongocCollection(from: connection) { collPtr in
            withOptionalBSONPointer(to: opts) { optsPtr in
                guard let indexes = mongoc_collection_find_indexes_with_opts(collPtr, optsPtr) else {
                    fatalError(failedToRetrieveCursorMessage)
                }
                return indexes
            }
        }

        if self.nameOnly {
            let cursor = try Cursor(
                mongocCursor: MongocCursor(referencing: indexes),
                connection: connection,
                session: session,
                type: .nonTailable
            )
            defer { cursor.kill() }

            var names: [String] = []
            while let nextDoc = try cursor.tryNext() {
                guard let name = nextDoc["name"]?.stringValue else {
                    throw MongoError.InternalError(message: "Invalid server response: index has no name")
                }
                names.append(name)
            }
            return .names(names)
        }
        let cursor: MongoCursor<IndexModel> = try MongoCursor(
            stealing: indexes,
            connection: connection,
            client: self.collection._client,
            decoder: self.collection.decoder,
            eventLoop: self.collection.eventLoop,
            session: session
        )
        return .models(cursor)
    }
}
