import CLibMongoC
import Foundation

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
        case let .other(v):
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

/// Options to use when executing a `listCollections` command on a `MongoDatabase`.
public struct ListCollectionsOptions: Codable {
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
    private let nameOnly: Bool
    private let filter: BSONDocument?
    private let options: ListCollectionsOptions?

    internal init(database: MongoDatabase, nameOnly: Bool, filter: BSONDocument?, options: ListCollectionsOptions?) {
        self.database = database
        self.nameOnly = nameOnly
        self.filter = filter
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> ListCollectionsResults {
        // Drivers MUST run listCollections on the primary node when in a replica set topology, unless directly
        // connected to a secondary node in Single topology.
        let readPref = ReadPreference.primary

        var cmd: BSONDocument = ["listCollections": 1, "nameOnly": .bool(self.nameOnly)]
        if let filterDoc = self.filter {
            cmd["filter"] = .document(filterDoc)

            // If `listCollectionNames` is called with a non-name filter key, change server-side nameOnly flag to false.
            // per spec: drivers MUST NOT set nameOnly if a filter specifies any keys other than name.
            if self.nameOnly && filterDoc.keys.contains(where: { $0 != "name" }) {
                cmd["nameOnly"] = false
            }
        }

        var cursorOpts: BSONDocument = [:]

        if let batchSize = options?.batchSize {
            guard let i32 = Int32(exactly: batchSize) else {
                throw MongoError.InvalidArgumentError(
                    message: "batchSize option must be representable as an Int32. Got: \(batchSize)"
                )
            }
            cursorOpts = ["batchSize": .int32(i32)]
        }

        let commandOpts = try encodeOptions(options: nil as BSONDocument?, session: session) ?? BSONDocument()
        cursorOpts = try encodeOptions(options: cursorOpts, session: session) ?? BSONDocument()
        cmd["cursor"] = .document(cursorOpts)

        var reply = try self.database.withMongocDatabase(from: connection) { dbPtr in
            try readPref.withMongocReadPreference { rpPtr in
                try runMongocCommandWithCReply(
                    command: cmd,
                    options: commandOpts
                ) { cmdPtr, optsPtr, replyPtr, error in
                    mongoc_database_read_command_with_opts(dbPtr, cmdPtr, rpPtr, optsPtr, replyPtr, &error)
                }
            }
        }

        let collections = connection.withMongocConnection { connPtr in
            withUnsafeMutablePointer(to: &reply) { replyPtr -> OpaquePointer in
                withOptionalBSONPointer(to: cursorOpts) { cursorOptsPtr in
                    guard let result = mongoc_cursor_new_from_command_reply_with_opts(
                        connPtr,
                        replyPtr,
                        cursorOptsPtr
                    ) else {
                        fatalError(failedToRetrieveCursorMessage)
                    }
                    return result
                }
            }
        }

        if self.nameOnly {
            // operate directly on the internal cursor type rather than going through the public `MongoCursor` type.
            // this allows us to use only a single of the executor's threads instead of tying up one per iteration.
            let cursor = try Cursor(
                mongocCursor: MongocCursor(referencing: collections),
                connection: connection,
                session: session,
                type: .nonTailable
            )
            defer { cursor.kill() }

            var names: [String] = []
            while let nextDoc = try cursor.tryNext() {
                guard let name = nextDoc["name"]?.stringValue else {
                    throw MongoError.InternalError(message: "Invalid server response: collection has no name")
                }
                names.append(name)
            }
            return .names(names)
        }
        let cursor: MongoCursor<CollectionSpecification> = try MongoCursor(
            stealing: collections,
            connection: connection,
            client: self.database._client,
            decoder: self.database.decoder,
            eventLoop: self.database.eventLoop,
            session: session
        )
        return .specs(cursor)
    }
}
