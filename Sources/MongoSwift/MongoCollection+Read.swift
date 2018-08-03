import libmongoc

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
     */
    public func find(_ filter: Document = [:], options: FindOptions? = nil) throws -> MongoCursor<CollectionType> {
        let opts = try BsonEncoder().encode(options)
        let rp = options?.readPreference?._readPreference
        guard let cursor = mongoc_collection_find_with_opts(self._collection, filter.data, opts?.data, rp) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: cursor, withClient: client)
    }

    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: an `[Document]` containing the pipeline of aggregation operations to perform
     *   - options: Optional `AggregateOptions` to use when executing the command
     *
     * - Returns: A `MongoCursor` over the resulting `Document`s
     */
    public func aggregate(_ pipeline: [Document], options: AggregateOptions? = nil) throws -> MongoCursor<Document> {
        let opts = try BsonEncoder().encode(options)
        let rp = options?.readPreference?._readPreference
        let pipeline: Document = ["pipeline": pipeline]
        guard let cursor = mongoc_collection_aggregate(
            self._collection, MONGOC_QUERY_NONE, pipeline.data, opts?.data, rp) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: cursor, withClient: client)
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
     */
    public func count(_ filter: Document = [:], options: CountOptions? = nil) throws -> Int {
        let opts = try BsonEncoder().encode(options)
        let rp = options?.readPreference?._readPreference
        var error = bson_error_t()
        // because we already encode skip and limit in the options,
        // pass in 0s so we don't get duplicate parameter errors.
        let count = mongoc_collection_count_with_opts(
            self._collection, MONGOC_QUERY_NONE, filter.data, 0, 0, opts?.data, rp, &error)

        if count == -1 { throw MongoError.commandError(message: toErrorString(error)) }

        return Int(count)
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
    public func countDocuments(_ filter: Document = [:], options: CountDocumentsOptions? = nil) throws -> Int {
        // TODO SWIFT-133: implement this https://jira.mongodb.org/browse/SWIFT-133
        throw MongoError.commandError(message: "Unimplemented command")
    }

    /**
     * Gets an estimate of the count of documents in this collection using collection metadata.
     *
     * - Parameters:
     *   - options: Optional `EstimatedDocumentCountOptions` to use when executing the command
     *
     * - Returns: an estimate of the count of documents in this collection
     */
    public func estimatedDocumentCount(options: EstimatedDocumentCountOptions? = nil) throws -> Int {
        // TODO SWIFT-133: implement this https://jira.mongodb.org/browse/SWIFT-133
        throw MongoError.commandError(message: "Unimplemented command")
    }

    /**
     * Finds the distinct values for a specified field across the collection.
     *
     * - Parameters:
     *   - fieldName: The field for which the distinct values will be found
     *   - filter: a `Document` representing the filter documents must match in order to be considered for the operation
     *   - options: Optional `DistinctOptions` to use when executing the command
     *
     * - Returns: A `[BsonValue?]` containing the distinct values for the specified criteria
     */
    public func distinct(fieldName: String, filter: Document = [:],
                         options: DistinctOptions? = nil) throws -> [BsonValue?] {

        let collName = String(cString: mongoc_collection_get_name(self._collection))
        let command: Document = [
            "distinct": collName,
            "key": fieldName,
            "query": filter
        ]

        let opts = try BsonEncoder().encode(options)
        let rp = options?.readPreference?._readPreference
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_read_command_with_opts(
            self._collection, command.data, rp, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }

        guard let values = reply["values"] as? [BsonValue?] else {
            throw MongoError.commandError(message:
                "expected server reply \(reply) to contain an array of distinct values")
        }

        return values
    }
}

/// An index to "hint" or force MongoDB to use when performing a query.
public enum Hint: Encodable {
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
}

/// Options to use when executing an `aggregate` command on a `MongoCollection`.
public struct AggregateOptions: Encodable {
    /// Enables writing to temporary files. When set to true, aggregation stages
    /// can write data to the _tmp subdirectory in the dbPath directory.
    public let allowDiskUse: Bool?

    /// The number of `Document`s to return per batch.
    public let batchSize: Int32?

    /// If true, allows the write to opt-out of document level validation. This only applies
    /// when the $out stage is specified.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// Enables users to specify an arbitrary string to help trace the operation through
    /// the database profiler, currentOp and logs. The default is to not send a value.
    public let comment: String?

    /// The index hint to use for the aggregation. The hint does not apply to $lookup and $graphLookup stages.
    public let hint: Hint?

    /// A `ReadConcern` to use in read stages of this operation.
    public let readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public let readPreference: ReadPreference?

    /// A `WriteConcern` to use in `$out` stages of this operation.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(allowDiskUse: Bool? = nil, batchSize: Int32? = nil, bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil, comment: String? = nil, hint: Hint? = nil, maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil, readPreference: ReadPreference? = nil,
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

/// Options to use when executing a `count` command on a `MongoCollection`.
public struct CountOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// A hint for the index to use.
    public let hint: Hint?

    /// The maximum number of documents to count.
    public let limit: Int64?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// The number of documents to skip before counting.
    public let skip: Int64?

    /// A ReadConcern to use for this operation. 
    public let readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public let readPreference: ReadPreference?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil, hint: Hint? = nil, limit: Int64? = nil, maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil, readPreference: ReadPreference? = nil, skip: Int64? = nil) {
        self.collation = collation
        self.hint = hint
        self.limit = limit
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.skip = skip
    }

    private enum CodingKeys: String, CodingKey {
        case collation, hint, limit, maxTimeMS, readConcern, skip
    }
}

/// The `countDocuments` command takes the same options as the deprecated `count`. 
public typealias CountDocumentsOptions = CountOptions

/// Options to use when executing an `estimatedDocumentCount` command on a `MongoCollection`.
public struct EstimatedDocumentCountOptions {
    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?
}

/// Options to use when executing a `distinct` command on a `MongoCollection`.
public struct DistinctOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// A ReadConcern to use for this operation. 
    public let readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public let readPreference: ReadPreference?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil, maxTimeMS: Int64? = nil, readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil) {
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
    }

    private enum CodingKeys: String, CodingKey {
        case collation, maxTimeMS, readConcern
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
public struct FindOptions: Encodable {
    /// Get partial results from a mongos if some shards are down (instead of throwing an error).
    public let allowPartialResults: Bool?

    /// The number of documents to return per batch.
    public let batchSize: Int32?

    /// Specifies a collation.
    public let collation: Document?

    /// Attaches a comment to the query.
    public let comment: String?

    /// Indicates the type of cursor to use. This value includes both the tailable and awaitData options.
    public let cursorType: CursorType?

    /// If a `CursorType` is provided, indicates whether it is `.tailable` or .`tailableAwait`.
    private let tailable: Bool?

    /// If a `CursorType` is provided, indicates whether it is `.tailableAwait`.
    private let awaitData: Bool?

    /// A hint for the index to use.
    public let hint: Hint?

    /// The maximum number of documents to return.
    public let limit: Int64?

    /// The exclusive upper bound for a specific index.
    public let max: Document?

    /// The maximum amount of time for the server to wait on new documents to satisfy a tailable cursor
    /// query. This only applies when used with `CursorType.tailableAwait`. Otherwise, this option is ignored.
    public let maxAwaitTimeMS: Int64?

    /// Maximum number of documents or index keys to scan when executing the query.
    public let maxScan: Int64?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// The inclusive lower bound for a specific index.
    public let min: Document?

    /// The server normally times out idle cursors after an inactivity period (10 minutes)
    /// to prevent excess memory use. Set this option to prevent that.
    public let noCursorTimeout: Bool?

    /// Limits the fields to return for all matching documents.
    public let projection: Document?

    /// If true, returns only the index keys in the resulting documents.
    public let returnKey: Bool?

    /// Determines whether to return the record identifier for each document. If true, adds a field $recordId
    /// to the returned documents.
    public let showRecordId: Bool?

    /// The number of documents to skip before returning.
    public let skip: Int64?

    /// The order in which to return matching documents.
    public let sort: Document?

    /// A ReadConcern to use for this operation. 
    public let readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public let readPreference: ReadPreference?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(allowPartialResults: Bool? = nil, batchSize: Int32? = nil, collation: Document? = nil,
                comment: String? = nil, cursorType: CursorType? = nil, hint: Hint? = nil, limit: Int64? = nil,
                max: Document? = nil, maxAwaitTimeMS: Int64? = nil, maxScan: Int64? = nil, maxTimeMS: Int64? = nil,
                min: Document? = nil, noCursorTimeout: Bool? = nil, projection: Document? = nil,
                readConcern: ReadConcern? = nil, readPreference: ReadPreference? = nil, returnKey: Bool? = nil,
                showRecordId: Bool? = nil, skip: Int64? = nil, sort: Document? = nil) {
        self.allowPartialResults = allowPartialResults
        self.batchSize = batchSize
        self.collation = collation
        self.comment = comment
        // although this does not get encoded, we store it for debugging purposes
        self.cursorType = cursorType
        self.tailable = cursorType == .tailable || cursorType == .tailableAwait
        self.awaitData = cursorType == .tailableAwait
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

    // Encode everything except `self.cursorType`, as we only store it for debugging purposes 
    private enum CodingKeys: String, CodingKey {
        case allowPartialResults, awaitData, batchSize, collation, comment, hint, limit, max, maxAwaitTimeMS,
            maxScan, maxTimeMS, min, noCursorTimeout, projection, readConcern, returnKey, showRecordId, tailable, skip,
            sort
    }
}
