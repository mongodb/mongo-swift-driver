import mongoc

/// An extension of `MongoCollection` encapsulating read operations.
extension MongoCollection {
    /**
     * Finds the documents in this collection which match the provided filter.
     *
     * - Parameters:
     *   - filter: A `Document` that should match the query
     *   - options: Optional `FindOptions` to use when executing the command
     *
     * - Returns: A `MongoCursor` over the resulting `Document`s
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if the options passed are an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func find(_ filter: Document = [:],
                     options: FindOptions? = nil,
                     session: ClientSession? = nil) throws -> MongoCursor<CollectionType> {
        let opts = try encodeOptions(options: options, session: session)
        let rp = options?.readPreference?._readPreference

        guard let cursor = mongoc_collection_find_with_opts(self._collection, filter._bson, opts?._bson, rp) else {
            fatalError("Couldn't get cursor from the server")
        }
        return try MongoCursor(from: cursor, client: self._client, decoder: self.decoder, session: session)
    }

    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: an `[Document]` containing the pipeline of aggregation operations to perform
     *   - options: Optional `AggregateOptions` to use when executing the command
     *
     * - Returns: A `MongoCursor` over the resulting `Document`s
     *
     * - Throws:
     *   - `UserError.invalidArgumentError` if the options passed are an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func aggregate(_ pipeline: [Document],
                          options: AggregateOptions? = nil,
                          session: ClientSession? = nil) throws -> MongoCursor<Document> {
        let opts = try encodeOptions(options: options, session: session)
        let rp = options?.readPreference?._readPreference
        let pipeline: Document = ["pipeline": pipeline]

        guard let cursor = mongoc_collection_aggregate(
            self._collection, MONGOC_QUERY_NONE, pipeline._bson, opts?._bson, rp) else {
            fatalError("Couldn't get cursor from the server")
        }
        return try MongoCursor(from: cursor, client: self._client, decoder: self.decoder, session: session)
    }

    // TODO SWIFT-133: mark this method deprecated https://jira.mongodb.org/browse/SWIFT-133
    /**
     * Counts the number of documents in this collection matching the provided filter.
     *
     * - Parameters:
     *   - filter: a `Document`, the filter that documents must match in order to be counted
     *   - options: Optional `CountOptions` to use when executing the command
     *
     * - Returns: The count of the documents that matched the filter
     *
     * - Throws:
     *   - `ServerError.commandError` if an error occurs that prevents the command from performing the write.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func count(_ filter: Document = [:],
                      options: CountOptions? = nil,
                      session: ClientSession? = nil) throws -> Int {
        let operation = CountOperation(collection: self, filter: filter, options: options, session: session)
        return try operation.execute()
    }

    /**
     * Counts the number of documents in this collection matching the provided filter.
     *
     * - Parameters:
     *   - filter: a `Document`, the filter that documents must match in order to be counted
     *   - options: Optional `CountDocumentsOptions` to use when executing the command
     *
     * - Returns: The count of the documents that matched the filter
     */
    private func countDocuments(_ filter: Document = [:],
                                options: CountDocumentsOptions? = nil,
                                session: ClientSession? = nil) throws -> Int {
        // TODO SWIFT-133: implement this https://jira.mongodb.org/browse/SWIFT-133
        throw UserError.logicError(message: "Unimplemented command")
    }

    /**
     * Gets an estimate of the count of documents in this collection using collection metadata.
     *
     * - Parameters:
     *   - options: Optional `EstimatedDocumentCountOptions` to use when executing the command
     *
     * - Returns: an estimate of the count of documents in this collection
     */
    private func estimatedDocumentCount(options: EstimatedDocumentCountOptions? = nil,
                                        session: ClientSession? = nil) throws -> Int {
        // TODO SWIFT-133: implement this https://jira.mongodb.org/browse/SWIFT-133
        throw UserError.logicError(message: "Unimplemented command")
    }

    /**
     * Finds the distinct values for a specified field across the collection.
     *
     * - Parameters:
     *   - fieldName: The field for which the distinct values will be found
     *   - filter: a `Document` representing the filter documents must match in order to be considered for the operation
     *   - options: Optional `DistinctOptions` to use when executing the command
     *
     * - Returns: A `[BSONValue]` containing the distinct values for the specified criteria
     *
     * - Throws:
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func distinct(fieldName: String,
                         filter: Document = [:],
                         options: DistinctOptions? = nil,
                         session: ClientSession? = nil) throws -> [BSONValue] {
        let operation = DistinctOperation(collection: self,
                                          fieldName: fieldName,
                                          filter: filter,
                                          options: options,
                                          session: session)
        return try operation.execute()
    }
}

/// An index to "hint" or force MongoDB to use when performing a query.
public enum Hint: Codable {
    /// Specifies an index to use by its name.
    case indexName(String)
    /// Specifies an index to use by a specification `Document` containing the index key(s).
    case indexSpec(Document)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .indexName(name):
            try container.encode(name)
        case let .indexSpec(doc):
            try container.encode(doc)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .indexName(str)
        } else {
            self = .indexSpec(try container.decode(Document.self))
        }
    }
}

/// Options to use when executing an `aggregate` command on a `MongoCollection`.
public struct AggregateOptions: Codable {
    /// Enables writing to temporary files. When set to true, aggregation stages
    /// can write data to the _tmp subdirectory in the dbPath directory.
    public var allowDiskUse: Bool?

    /// The number of `Document`s to return per batch.
    public var batchSize: Int32?

    /// If true, allows the write to opt-out of document level validation. This only applies
    /// when the $out stage is specified.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public var collation: Document?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// Enables users to specify an arbitrary string to help trace the operation through
    /// the database profiler, currentOp and logs. The default is to not send a value.
    public var comment: String?

    /// The index hint to use for the aggregation. The hint does not apply to $lookup and $graphLookup stages.
    public var hint: Hint?

    /// A `ReadConcern` to use in read stages of this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization
    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil
    // swiftlint:enable redundant_optional_initialization

    /// A `WriteConcern` to use in `$out` stages of this operation.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(allowDiskUse: Bool? = nil,
                batchSize: Int32? = nil,
                bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil,
                comment: String? = nil,
                hint: Hint? = nil,
                maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil,
                writeConcern: WriteConcern? = nil) {
        self.allowDiskUse = allowDiskUse
        self.batchSize = batchSize
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.comment = comment
        self.hint = hint
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.writeConcern = writeConcern
    }

    private enum CodingKeys: String, CodingKey {
        case allowDiskUse, batchSize, bypassDocumentValidation, collation, maxTimeMS, comment, hint, readConcern,
            writeConcern
    }
}

/// The `countDocuments` command takes the same options as the deprecated `count`.
private typealias CountDocumentsOptions = CountOptions

/// Options to use when executing an `estimatedDocumentCount` command on a `MongoCollection`.
private struct EstimatedDocumentCountOptions {
    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// Initializer allowing any/all parameters to be omitted or optional.
    public init(maxTimeMS: Int64? = nil) {
        self.maxTimeMS = maxTimeMS
    }
}

/// The possible types of `MongoCursor` an operation can return.
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
}

/// Options to use when executing a `find` command on a `MongoCollection`.
public struct FindOptions: Codable {
    /// Get partial results from a mongos if some shards are down (instead of throwing an error).
    public var allowPartialResults: Bool?

    /// The number of documents to return per batch.
    public var batchSize: Int32?

    /// Specifies a collation.
    public var collation: Document?

    /// Attaches a comment to the query.
    public var comment: String?

    /// If a `CursorType` is provided, indicates whether it is `.tailable` or .`tailableAwait`.
    private var tailable: Bool?

    /// If a `CursorType` is provided, indicates whether it is `.tailableAwait`.
    private var awaitData: Bool?

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

    /// If true, returns only the index keys in the resulting documents.
    public var returnKey: Bool?

    /// Determines whether to return the record identifier for each document. If true, adds a field $recordId
    /// to the returned documents.
    public var showRecordId: Bool?

    /// The number of documents to skip before returning.
    public var skip: Int64?

    /// The order in which to return matching documents.
    public var sort: Document?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization

    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil

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

    // swiftlint:enable redundant_optional_initialization

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(allowPartialResults: Bool? = nil,
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
                sort: Document? = nil) {
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

    // Encode everything except `self.readPreference`, because this is sent to libmongoc separately
    private enum CodingKeys: String, CodingKey {
        case allowPartialResults, awaitData, batchSize, collation, comment, hint, limit, max, maxAwaitTimeMS,
            maxScan, maxTimeMS, min, noCursorTimeout, projection, readConcern, returnKey, showRecordId, tailable, skip,
            sort
    }
}
