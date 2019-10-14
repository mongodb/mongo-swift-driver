import Foundation
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

/**
 * Info about the collection that is returned with a `listCollections` call.
 *
 * - SeeAlso:
 *   - https://docs.mongodb.com/manual/reference/command/listCollections/#listCollections.cursor
 */
public struct CollectionSpecificationInfo: Codable {
    /// Indicates whether or not the data store is read-only.
    public let readOnly: Bool

    /// The collection's UUID - once established, this does not change and remains the same across replica
    /// set members and shards in a sharded cluster. If the data store is a view, this field is nil.
    public let uuid: UUID?
}
/**
 * Specifications of a collection returned when executing `listCollections`.
 *
 * - SeeAlso:
 *   - https://docs.mongodb.com/manual/reference/command/listCollections/#listCollections.cursor
 */
public struct CollectionSpecification: Codable {
    /// The name of the collection.
    public let name: String

    /// The type of data store returned.
    public let type: CollectionType

    /// Options that were used when creating this collection.
    public let options: CreateCollectionOptions?

    /// Contains info pertaining to the collection.
    public let info: CollectionSpecificationInfo

    /// Provides info on the _id index of the collection. `nil` when this data store is of type view.
    public let idIndex: IndexModel?
}

/// Options to use when executing a `listCollections` command on a `MongoDatabase` or a `SyncMongoDatabase`.
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
    case specs(SyncMongoCursor<CollectionSpecification>)

    /// Only includes the names.
    case names([String])
}

/// An operation corresponding to a "listCollections" command on a database.
internal struct ListCollectionsOperation: Operation {
    private let database: SyncMongoDatabase
    private let nameOnly: Bool
    private let filter: Document?
    private let options: ListCollectionsOptions?

    internal init(database: SyncMongoDatabase, nameOnly: Bool, filter: Document?, options: ListCollectionsOptions?) {
        self.database = database
        self.nameOnly = nameOnly
        self.filter = filter
        self.options = options
    }

    internal func execute(using connection: Connection, session: SyncClientSession?) throws -> ListCollectionsResults {
        var opts = try encodeOptions(options: self.options, session: session) ?? Document()
        opts["nameOnly"] = self.nameOnly
        if let filterDoc = self.filter {
            opts["filter"] = filterDoc

            // If `listCollectionNames` is called with a non-name filter key, change server-side nameOnly flag to false.
            if self.nameOnly && filterDoc.keys.contains { $0 != "name" } {
                opts["nameOnly"] = false
            }
        }

        let initializer = { (conn: Connection) -> OpaquePointer in
            self.database.withMongocDatabase(from: conn) { dbPtr in
                guard let collections = mongoc_database_find_collections_with_opts(dbPtr, opts._bson) else {
                    fatalError(failedToRetrieveCursorMessage)
                }
                return collections
            }
        }
        if self.nameOnly {
            let cursor: SyncMongoCursor<Document> = try SyncMongoCursor(client: self.database._client,
                                                                decoder: self.database.decoder,
                                                                session: session,
                                                                initializer: initializer)
            return try .names(cursor.map {
                guard let name = $0["name"] as? String else {
                    throw RuntimeError.internalError(message: "Invalid server response: collection has no name")
                }
                return name
            })
        }
        let cursor: SyncMongoCursor<CollectionSpecification> = try SyncMongoCursor(client: self.database._client,
                                                                           decoder: self.database.decoder,
                                                                           session: session,
                                                                           initializer: initializer)
        return .specs(cursor)
    }
}
