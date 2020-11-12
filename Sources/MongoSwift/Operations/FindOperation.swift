import CLibMongoC
import Foundation

/// The possible types of `MongoCursor` or `MongoCursor` an operation can return.
public enum MongoCursorType {
    /**
     * The default value. A vast majority of cursors will be of this type.
     */
    case nonTailable

    /**
     * Tailable means the cursor is not closed when the last data is retrieved.
     * Rather, the cursor marks the final object’s position. You can resume
     * using the cursor later, from where it was located, if more data were
     * received. Like any “latent cursor”, the cursor may become invalid at
     * some point (CursorNotFound) – for example if the final object it
     * references were deleted.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/core/tailable-cursors/
     */
    case tailable

    /**
     * A tailable cursor that will wait for more data for a configurable amount of time before returning an empty batch.
     */
    case tailableAwait

    internal var isTailable: Bool {
        self != .nonTailable
    }
}

/// Options to use when executing a `find` command on a `MongoCollection`.
public struct FindOptions: Codable {
    /// Enables the server to write to temporary files. When set to true, the find operation
    /// can write data to the _tmp subdirectory in the dbPath directory. This helps prevent
    /// out-of-memory failures server side when working with large result sets.
    ///
    /// - Note:
    ///    This option is only supported in MongoDB 4.4+. Specifying it against earlier versions of the server
    ///    will result in an error.
    public var allowDiskUse: Bool?

    /// Get partial results from a mongos if some shards are down (instead of throwing an error).
    public var allowPartialResults: Bool?

    /// If a `MongoCursorType` is provided, indicates whether it is `.tailableAwait`.
    private var awaitData: Bool?

    /// The number of documents to return per batch.
    public var batchSize: Int?

    /// Specifies a collation.
    public var collation: BSONDocument?

    /// Attaches a comment to the query.
    public var comment: String?

    /// Indicates the type of cursor to use. This value includes both the tailable and awaitData options.
    public var cursorType: MongoCursorType? {
        get {
            if self.tailable == nil && self.awaitData == nil {
                return nil
            }

            if self.tailable == true && self.awaitData == true {
                return .tailableAwait
            }

            if self.tailable == true {
                return .tailable
            }

            return .nonTailable
        }

        set(newMongoCursorType) {
            if newMongoCursorType == nil {
                self.tailable = nil
                self.awaitData = nil
            } else {
                self.tailable = newMongoCursorType == .tailable || newMongoCursorType == .tailableAwait
                self.awaitData = newMongoCursorType == .tailableAwait
            }
        }
    }

    /// A hint for the index to use.
    public var hint: IndexHint?

    /// The maximum number of documents to return.
    public var limit: Int?

    /// The exclusive upper bound for a specific index.
    public var max: BSONDocument?

    /// The maximum amount of time, in milliseconds, for the server to wait on new documents to satisfy a tailable
    /// cursor query. This only applies when used with `MongoCursorType.tailableAwait`. Otherwise, this option is
    /// ignored.
    public var maxAwaitTimeMS: Int?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int?

    /// The inclusive lower bound for a specific index.
    public var min: BSONDocument?

    /// The server normally times out idle cursors after an inactivity period (10 minutes)
    /// to prevent excess memory use. Set this option to prevent that.
    public var noCursorTimeout: Bool?

    /// Limits the fields to return for all matching documents.
    public var projection: BSONDocument?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization

    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil

    /// If true, returns only the index keys in the resulting documents.
    public var returnKey: Bool?

    /// Determines whether to return the record identifier for each document. If true, adds a field $recordId
    /// to the returned documents.
    public var showRecordID: Bool?

    /// The number of documents to skip before returning.
    public var skip: Int?

    /// The order in which to return matching documents.
    public var sort: BSONDocument?

    /// If a `MongoCursorType` is provided, indicates whether it is `.tailable` or .`tailableAwait`.
    private var tailable: Bool?

    // swiftlint:enable redundant_optional_initialization

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        allowDiskUse: Bool? = nil,
        allowPartialResults: Bool? = nil,
        batchSize: Int? = nil,
        collation: BSONDocument? = nil,
        comment: String? = nil,
        cursorType: MongoCursorType? = nil,
        hint: IndexHint? = nil,
        limit: Int? = nil,
        max: BSONDocument? = nil,
        maxAwaitTimeMS: Int? = nil,
        maxTimeMS: Int? = nil,
        min: BSONDocument? = nil,
        noCursorTimeout: Bool? = nil,
        projection: BSONDocument? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        returnKey: Bool? = nil,
        showRecordID: Bool? = nil,
        skip: Int? = nil,
        sort: BSONDocument? = nil
    ) {
        self.allowDiskUse = allowDiskUse
        self.allowPartialResults = allowPartialResults
        self.batchSize = batchSize
        self.collation = collation
        self.comment = comment
        self.cursorType = cursorType
        self.hint = hint
        self.limit = limit
        self.max = max
        self.maxAwaitTimeMS = maxAwaitTimeMS
        self.maxTimeMS = maxTimeMS
        self.min = min
        self.noCursorTimeout = noCursorTimeout
        self.projection = projection
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.returnKey = returnKey
        self.showRecordID = showRecordID
        self.skip = skip
        self.sort = sort
    }

    internal init(from findOneOptions: FindOneOptions) {
        self.allowPartialResults = findOneOptions.allowPartialResults
        self.collation = findOneOptions.collation
        self.comment = findOneOptions.comment
        self.hint = findOneOptions.hint
        self.max = findOneOptions.max
        self.maxTimeMS = findOneOptions.maxTimeMS
        self.min = findOneOptions.min
        self.projection = findOneOptions.projection
        self.readConcern = findOneOptions.readConcern
        self.readPreference = findOneOptions.readPreference
        self.returnKey = findOneOptions.returnKey
        self.showRecordID = findOneOptions.showRecordID
        self.skip = findOneOptions.skip
        self.sort = findOneOptions.sort
        self.limit = 1
    }

    // Encode everything except `self.readPreference`, because this is sent to libmongoc separately
    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case allowDiskUse, allowPartialResults, awaitData, batchSize, collation, comment, hint, limit, max,
             maxAwaitTimeMS, maxTimeMS, min, noCursorTimeout, projection, readConcern, returnKey,
             showRecordID = "showRecordId", tailable, skip, sort
    }
}

/// Options to use when executing a `findOne` command on a `MongoCollection`.
public struct FindOneOptions: Codable {
    /// Get partial results from a mongos if some shards are down (instead of throwing an error).
    public var allowPartialResults: Bool?

    /// Specifies a collation.
    public var collation: BSONDocument?

    /// Attaches a comment to the query.
    public var comment: String?

    /// A hint for the index to use.
    public var hint: IndexHint?

    /// The exclusive upper bound for a specific index.
    public var max: BSONDocument?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int?

    /// The inclusive lower bound for a specific index.
    public var min: BSONDocument?

    /// Limits the fields to return for all matching documents.
    public var projection: BSONDocument?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference?

    /// If true, returns only the index keys in the resulting documents.
    public var returnKey: Bool?

    /// Determines whether to return the record identifier for each document. If true, adds a field $recordId
    /// to the returned documents.
    public var showRecordID: Bool?

    /// The number of documents to skip before returning.
    public var skip: Int?

    /// The order in which to return matching documents.
    public var sort: BSONDocument?

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        allowPartialResults: Bool? = nil,
        collation: BSONDocument? = nil,
        comment: String? = nil,
        hint: IndexHint? = nil,
        max: BSONDocument? = nil,
        maxTimeMS: Int? = nil,
        min: BSONDocument? = nil,
        projection: BSONDocument? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        returnKey: Bool? = nil,
        showRecordID: Bool? = nil,
        skip: Int? = nil,
        sort: BSONDocument? = nil
    ) {
        self.allowPartialResults = allowPartialResults
        self.collation = collation
        self.comment = comment
        self.hint = hint
        self.max = max
        self.maxTimeMS = maxTimeMS
        self.min = min
        self.projection = projection
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.returnKey = returnKey
        self.showRecordID = showRecordID
        self.skip = skip
        self.sort = sort
    }

    // Encode everything except `self.readPreference`, because this is sent to libmongoc separately
    private enum CodingKeys: String, CodingKey {
        case allowPartialResults, collation, comment, hint, max, maxTimeMS, min, projection, readConcern, returnKey,
             showRecordID = "showRecordId", skip, sort
    }
}

/// An operation corresponding to a "find" command on a collection.
internal struct FindOperation<CollectionType: Codable>: Operation {
    private let collection: MongoCollection<CollectionType>
    private let filter: BSONDocument
    private let options: FindOptions?

    internal init(collection: MongoCollection<CollectionType>, filter: BSONDocument, options: FindOptions?) {
        self.collection = collection
        self.filter = filter
        self.options = options
    }

    internal func execute(
        using connection: Connection,
        session: ClientSession?
    ) throws -> MongoCursor<CollectionType> {
        let opts = try encodeOptions(options: self.options, session: session)

        let result: OpaquePointer = self.collection.withMongocCollection(from: connection) { collPtr in
            self.filter.withBSONPointer { filterPtr in
                withOptionalBSONPointer(to: opts) { optsPtr in
                    ReadPreference.withOptionalMongocReadPreference(from: self.options?.readPreference) { rpPtr in
                        guard let result = mongoc_collection_find_with_opts(collPtr, filterPtr, optsPtr, rpPtr) else {
                            fatalError(failedToRetrieveCursorMessage)
                        }
                        return result
                    }
                }
            }
        }

        // since mongoc_collection_find_with_opts doesn't do any I/O, use forceIO to ensure this operation fails if we
        // can not successfully get a cursor from the server.
        return try MongoCursor(
            stealing: result,
            connection: connection,
            client: self.collection._client,
            decoder: self.collection.decoder,
            session: session,
            cursorType: self.options?.cursorType
        )
    }
}
