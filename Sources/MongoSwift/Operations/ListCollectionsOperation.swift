import mongoc

/// Describes the type of data store returned when executing `listCollections`.
public enum CollectionType: RawRepresentable, Codable {
    /// Specifies that the data store returned is a collection.
    case collection
    /// Specifies that the data store returned is a view.
    case view
    /// For an unknown value. For forwards compatibility, no error will be thrown when an unknown value is provided.
    case other(String)

    public var rawValue: String {
        switch self {
        case .collection:
            return "collection"
        case .view:
            return "view"
        case .other(let v):
            return v
        }
    }

    public init(rawValue: String) {
        switch rawValue {
        case "collection":
            self = .collection
        case "view":
            self = .view
        default:
            self = .other(rawValue)
        }
    }
}

/// Specifications of a collection returned when executing `listCollections`.
public struct CollectionSpecification: Codable {
    /// The name of the collection.
    public let name: String

    /// The type of data store returned.
    public let type: CollectionType

    /// Options that were used when creating this collection.
    public let options: CreateCollectionOptions?
}

/// Options to use when executing a `listCollections` command on a `MongoDatabase`.
public struct ListCollectionsOptions: Encodable {
    /// The batchSize for the returned cursor.
    public var batchSize: Int?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(batchSize: Int? = nil) {
        self.batchSize = batchSize
    }
}

/// Internal intermediate result of a ListCollections command.
internal enum ListCollectionsResults {
    /// Includes the name, type, and creation options of each collection.
    case specs(MongoCursor<CollectionSpecification>)

    /// Only includes the names.
    case names([String])
}

/// An operation corresponding to a "listCollections" command on a database.
internal struct ListCollectionsOperation: Operation {
    private let database: MongoDatabase
    private let filter: Document?
    private let options: ListCollectionsOptions?
    private let nameOnly: Bool?

    internal init(database: MongoDatabase, filter: Document?, options: ListCollectionsOptions?, nameOnly: Bool?) {
        self.database = database
        self.filter = filter
        self.options = options
        self.nameOnly = nameOnly
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ListCollectionsResults {
        var opts = try encodeOptions(options: self.options, session: session)
        if let filterDoc = self.filter {
            opts = opts ?? Document()
            // swiftlint:disable:next force_unwrapping
            opts!["filter"] = filterDoc // guaranteed safe because of nil coalescing default.
        }

        let initializer = { (conn: Connection) -> OpaquePointer in
            self.database.withMongocDatabase(from: conn) { dbPtr in
                guard let collections = mongoc_database_find_collections_with_opts(dbPtr, opts?._bson) else {
                    fatalError(failedToRetrieveCursorMessage)
                }
                return collections
            }
        }
        if self.nameOnly ?? false {
            let cursor: MongoCursor<Document> = try MongoCursor(client: self.database._client,
                                                                decoder: self.database.decoder,
                                                                session: session,
                                                                initializer: initializer)
            return try .names(cursor.map { guard let name = $0["name"] as? String else {
                    throw RuntimeError.internalError(message: "Invalid server response: collection has no name")
                }
                return name
            })
        }
        let cursor: MongoCursor<CollectionSpecification> = try MongoCursor(client: self.database._client,
                                                                           decoder: self.database.decoder,
                                                                           session: session,
                                                                           initializer: initializer)
        return .specs(cursor)
    }
}
