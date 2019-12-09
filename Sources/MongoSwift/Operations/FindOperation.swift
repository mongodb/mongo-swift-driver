import Foundation
import mongoc

/// The possible types of `MongoCursor` or `MongoCursor` an operation can return.
public enum CursorType {
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
     * - SeeAlso: https://docs.mongodb.com/meta-driver/latest/legacy/mongodb-wire-protocol/#op-query
     */
    case tailable

    /**
     * Combines the tailable option with awaitData, as defined below.
     *
     * Use with TailableCursor. If we are at the end of the data, block for a
     * while rather than returning no data. After a timeout period, we do return
     * as normal. The default is true.
     *
     * - SeeAlso: https://docs.mongodb.com/meta-driver/latest/legacy/mongodb-wire-protocol/#op-query
     */
    case tailableAwait

    internal var isTailable: Bool {
        return self != .nonTailable
    }
}

/// Options to use when executing a `find` command on a `MongoCollection`.
public struct FindOptions: Codable {
    /// Get partial results from a mongos if some shards are down (instead of throwing an error).
    public var allowPartialResults: Bool?

    /// If a `CursorType` is provided, indicates whether it is `.tailableAwait`.
    private var awaitData: Bool?

    /// The number of documents to return per batch.
    public var batchSize: Int32?

    /// Specifies a collation.
    public var collation: Document?

    /// Attaches a comment to the query.
    public var comment: String?

    /// Indicates the type of cursor to use. This value includes both the tailable and awaitData options.
    public var cursorType: CursorType? {
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

        set(newCursorType) {
            if newCursorType == nil {
                self.tailable = nil
                self.awaitData = nil
            } else {
                self.tailable = newCursorType == .tailable || newCursorType == .tailableAwait
                self.awaitData = newCursorType == .tailableAwait
            }
        }
    }

    /// A hint for the index to use.
    public var hint: Hint?

    /// The maximum number of documents to return.
    public var limit: Int64?

    /// The exclusive upper bound for a specific index.
    public var max: Document?

    /// The maximum amount of time for the server to wait on new documents to satisfy a tailable cursor
    /// query. This only applies when used with `CursorType.tailableAwait`. Otherwise, this option is ignored.
    public var maxAwaitTimeMS: Int64?

    /// Maximum number of documents or index keys to scan when executing the query.
    public var maxScan: Int64?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// The inclusive lower bound for a specific index.
    public var min: Document?

    /// The server normally times out idle cursors after an inactivity period (10 minutes)
    /// to prevent excess memory use. Set this option to prevent that.
    public var noCursorTimeout: Bool?

    /// Limits the fields to return for all matching documents.
    public var projection: Document?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization

    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil

    /// If true, returns only the index keys in the resulting documents.
    public var returnKey: Bool?

    /// Determines whether to return the record identifier for each document. If true, adds a field $recordId
    /// to the returned documents.
    public var showRecordId: Bool?

    /// The number of documents to skip before returning.
    public var skip: Int64?

    /// The order in which to return matching documents.
    public var sort: Document?

    /// If a `CursorType` is provided, indicates whether it is `.tailable` or .`tailableAwait`.
    private var tailable: Bool?

    // swiftlint:enable redundant_optional_initialization

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        allowPartialResults: Bool? = nil,
        batchSize: Int32? = nil,
        collation: Document? = nil,
        comment: String? = nil,
        cursorType: CursorType? = nil,
        hint: Hint? = nil,
        limit: Int64? = nil,
        max: Document? = nil,
        maxAwaitTimeMS: Int64? = nil,
        maxScan: Int64? = nil,
        maxTimeMS: Int64? = nil,
        min: Document? = nil,
        noCursorTimeout: Bool? = nil,
        projection: Document? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        returnKey: Bool? = nil,
        showRecordId: Bool? = nil,
        skip: Int64? = nil,
        sort: Document? = nil
    ) {
        self.allowPartialResults = allowPartialResults
        self.batchSize = batchSize
        self.collation = collation
        self.comment = comment
        self.cursorType = cursorType
        self.hint = hint
        self.limit = limit
        self.max = max
        self.maxAwaitTimeMS = maxAwaitTimeMS
        self.maxScan = maxScan
        self.maxTimeMS = maxTimeMS
        self.min = min
        self.noCursorTimeout = noCursorTimeout
        self.projection = projection
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.returnKey = returnKey
        self.showRecordId = showRecordId
        self.skip = skip
        self.sort = sort
    }

    internal init(findOneOptions: FindOneOptions) {
        self.allowPartialResults = findOneOptions.allowPartialResults
        self.collation = findOneOptions.collation
        self.comment = findOneOptions.comment
        self.hint = findOneOptions.hint
        self.max = findOneOptions.max
        self.maxScan = findOneOptions.maxScan
        self.maxTimeMS = findOneOptions.maxTimeMS
        self.min = findOneOptions.min
        self.projection = findOneOptions.projection
        self.readConcern = findOneOptions.readConcern
        self.returnKey = findOneOptions.returnKey
        self.showRecordId = findOneOptions.showRecordId
        self.skip = findOneOptions.skip
        self.sort = findOneOptions.sort
    }

    // Encode everything except `self.readPreference`, because this is sent to libmongoc separately
    private enum CodingKeys: String, CodingKey {
        case allowPartialResults, awaitData, batchSize, collation, comment, hint, limit, max, maxAwaitTimeMS,
            maxScan, maxTimeMS, min, noCursorTimeout, projection, readConcern, returnKey, showRecordId, tailable, skip,
            sort
    }
}

/// Options to use when executing a `findOne` command on a `MongoCollection`.
public struct FindOneOptions: Codable {
    /// Get partial results from a mongos if some shards are down (instead of throwing an error).
    public var allowPartialResults: Bool?

    /// Specifies a collation.
    public var collation: Document?

    /// Attaches a comment to the query.
    public var comment: String?

    /// A hint for the index to use.
    public var hint: Hint?

    /// The exclusive upper bound for a specific index.
    public var max: Document?

    /// Maximum number of documents or index keys to scan when executing the query.
    public var maxScan: Int64?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// The inclusive lower bound for a specific index.
    public var min: Document?

    /// Limits the fields to return for all matching documents.
    public var projection: Document?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference?

    /// If true, returns only the index keys in the resulting documents.
    public var returnKey: Bool?

    /// Determines whether to return the record identifier for each document. If true, adds a field $recordId
    /// to the returned documents.
    public var showRecordId: Bool?

    /// The number of documents to skip before returning.
    public var skip: Int64?

    /// The order in which to return matching documents.
    public var sort: Document?

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        allowPartialResults: Bool? = nil,
        collation: Document? = nil,
        comment: String? = nil,
        hint: Hint? = nil,
        max: Document? = nil,
        maxScan: Int64? = nil,
        maxTimeMS: Int64? = nil,
        min: Document? = nil,
        projection: Document? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        returnKey: Bool? = nil,
        showRecordId: Bool? = nil,
        skip: Int64? = nil,
        sort: Document? = nil
    ) {
        self.allowPartialResults = allowPartialResults
        self.collation = collation
        self.comment = comment
        self.hint = hint
        self.max = max
        self.maxScan = maxScan
        self.maxTimeMS = maxTimeMS
        self.min = min
        self.projection = projection
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.returnKey = returnKey
        self.showRecordId = showRecordId
        self.skip = skip
        self.sort = sort
    }

    // Encode everything except `self.readPreference`, because this is sent to libmongoc separately
    private enum CodingKeys: String, CodingKey {
        case allowPartialResults, collation, comment, hint, max,
            maxScan, maxTimeMS, min, projection, readConcern, returnKey, showRecordId, skip, sort
    }
}

/// An operation corresponding to a "find" command on a collection.
internal struct FindOperation<CollectionType: Codable>: Operation {
    private let collection: MongoCollection<CollectionType>
    private let filter: Document
    private let options: FindOptions?

    internal init(collection: MongoCollection<CollectionType>, filter: Document, options: FindOptions?) {
        self.collection = collection
        self.filter = filter
        self.options = options
    }

    internal func execute(
        using connection: Connection,
        session: ClientSession?
    ) throws -> MongoCursor<CollectionType> {
        let opts = try encodeOptions(options: self.options, session: session)
        let rp = self.options?.readPreference?._readPreference

        let result: OpaquePointer = self.collection.withMongocCollection(from: connection) { collPtr in
            guard let result = mongoc_collection_find_with_opts(collPtr, self.filter._bson, opts?._bson, rp) else {
                fatalError(failedToRetrieveCursorMessage)
            }
            return result
        }

        // since mongoc_collection_find_with_opts doesn't do any I/O, use forceIO to ensure this operation fails if we
        // can not successfully get a cursor from the server.
        return try MongoCursor(
            stealing: result,
            connection: connection,
            client: self.collection._client,
            decoder: self.collection.decoder,
            session: session,
            cursorType: self.options?.cursorType,
            forceIO: true
        )
    }
}
