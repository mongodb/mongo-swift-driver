import libmongoc

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

    /// The index to use for the aggregation. The hint does not apply to $lookup and $graphLookup stages.
    // let hint: Optional<(String | Document)>

    /// A `ReadConcern` to use in read stages of this operation.
    public let readConcern: ReadConcern?

    /// A `WriteConcern` to use in `$out` stages of this operation.
    let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(allowDiskUse: Bool? = nil, batchSize: Int32? = nil, bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil, comment: String? = nil, maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil, writeConcern: WriteConcern? = nil) {
        self.allowDiskUse = allowDiskUse
        self.batchSize = batchSize
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.comment = comment
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `count` command on a `MongoCollection`.
public struct CountOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// The index to use.
    // let hint: Optional<(String | Document)>

    /// The maximum number of documents to count.
    public let limit: Int64?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// The number of documents to skip before counting.
    public let skip: Int64?

    /// A ReadConcern to use for this operation. 
    public let readConcern: ReadConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil, limit: Int64? = nil, maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil, skip: Int64? = nil) {
        self.collation = collation
        self.limit = limit
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.skip = skip
    }
}

/// Options to use when executing a `distinct` command on a `MongoCollection`.
public struct DistinctOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// A ReadConcern to use for this operation. 
    public let readConcern: ReadConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil, maxTimeMS: Int64? = nil, readConcern: ReadConcern? = nil) {
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
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
    // commenting this out until we decide how to encode cursorType.
    // let cursorType: CursorType?

    /// The index to use.
    // let hint: Optional<(String | Document)>

    /// The maximum number of documents to return.
    public let limit: Int64?

    /// The exclusive upper bound for a specific index.
    public let max: Document?

    /// The maximum amount of time for the server to wait on new documents to satisfy a tailable cursor
    /// query. This only applies to a TAILABLE_AWAIT cursor. When the cursor is not a TAILABLE_AWAIT cursor,
    /// this option is ignored.
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

    /// Convenience initializer allowing any/all parameters to be optional
    public init(allowPartialResults: Bool? = nil, batchSize: Int32? = nil, collation: Document? = nil,
                comment: String? = nil, limit: Int64? = nil, max: Document? = nil, maxAwaitTimeMS: Int64? = nil,
                maxScan: Int64? = nil, maxTimeMS: Int64? = nil, min: Document? = nil, noCursorTimeout: Bool? = nil,
                projection: Document? = nil, readConcern: ReadConcern? = nil, returnKey: Bool? = nil,
                showRecordId: Bool? = nil, skip: Int64? = nil, sort: Document? = nil) {
        self.allowPartialResults = allowPartialResults
        self.batchSize = batchSize
        self.collation = collation
        self.comment = comment
        self.limit = limit
        self.max = max
        self.maxAwaitTimeMS = maxAwaitTimeMS
        self.maxScan = maxScan
        self.maxTimeMS = maxTimeMS
        self.min = min
        self.noCursorTimeout = noCursorTimeout
        self.projection = projection
        self.readConcern = readConcern
        self.returnKey = returnKey
        self.showRecordId = showRecordId
        self.skip = skip
        self.sort = sort
    }
}

/// Options to use when executing an `insertOne` command on a `MongoCollection`.
public struct InsertOneOptions: Encodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// An optional WriteConcern to use for the command.
    let writeConcern: WriteConcern?

    /// Convenience initializer allowing bypassDocumentValidation to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.writeConcern = writeConcern
    }

    // Encode everything except writeConcern
    private enum CodingKeys: String, CodingKey {
        case bypassDocumentValidation
    }
}

/// Options to use when executing an `insertMany` command on a `MongoCollection`. 
public struct InsertManyOptions: Encodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// If true, when an insert fails, return without performing the remaining
    /// writes. If false, when a write fails, continue with the remaining writes, if any.
    /// Defaults to true.
    public var ordered: Bool = true

    /// An optional WriteConcern to use for the command.
    let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, ordered: Bool? = true, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        if let o = ordered { self.ordered = o }
        self.writeConcern = writeConcern
    }

    // Encode everything except writeConcern
    private enum CodingKeys: String, CodingKey {
        case bypassDocumentValidation, ordered
    }
}

/// Options to use when executing an `update` command on a `MongoCollection`. 
public struct UpdateOptions: Encodable {
    /// A set of filters specifying to which array elements an update should apply.
    public let arrayFilters: [Document]?

    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional WriteConcern to use for the command.
    let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(arrayFilters: [Document]? = nil, bypassDocumentValidation: Bool? = nil, collation: Document? = nil,
                upsert: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.arrayFilters = arrayFilters
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }

    // Encode everything except writeConcern
    private enum CodingKeys: String, CodingKey {
        case arrayFilters, bypassDocumentValidation, collation, upsert
    }
}

/// Options to use when executing a `replace` command on a `MongoCollection`. 
public struct ReplaceOptions: Encodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional WriteConcern to use for the command.
    let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(bypassDocumentValidation: Bool? = nil, collation: Document? = nil, upsert: Bool? = nil,
                writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }

    // Encode everything except writeConcern
    private enum CodingKeys: String, CodingKey {
        case bypassDocumentValidation, collation, upsert
    }
}

/// Options to use when executing a `delete` command on a `MongoCollection`. 
public struct DeleteOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// An optional WriteConcern to use for the command.
    let writeConcern: WriteConcern?

     /// Convenience initializer allowing collation to be omitted or optional
    public init(collation: Document? = nil, writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.writeConcern = writeConcern
    }

    // Encode everything except writeConcern
    private enum CodingKeys: String, CodingKey {
        case collation
    }
}

/// The result of an `insertOne` command on a `MongoCollection`. 
public struct InsertOneResult {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BsonValue
}

/// The result of an `insertMany` command on a `MongoCollection`. 
public struct InsertManyResult {
    /// Map of the index of the inserted document to the id of the inserted document.
    public let insertedIds: [Int64: BsonValue]

    /// Given an ordered array of insertedIds, creates a corresponding InsertManyResult.
    internal init(fromArray arr: [BsonValue]) {
        var inserted = [Int64: BsonValue]()
        for (i, id) in arr.enumerated() {
            let index = Int64(i)
            inserted[index] = id
        }
        self.insertedIds = inserted
    }
}

/// The result of a `delete` command on a `MongoCollection`. 
public struct DeleteResult {
    /// The number of documents that were deleted.
    public let deletedCount: Int

    /// Given a server response to a delete command, creates a corresponding
    /// `DeleteResult`. If the `from` Document does not have a `deletedCount`
    /// field, the initialization will fail.
    internal init?(from: Document) {
        guard let deletedCount = from["deletedCount"] as? Int else { return nil }
        self.deletedCount = deletedCount
    }
}

/// The result of an `update` operation a `MongoCollection`.
public struct UpdateResult {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents that were modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: BsonValue?

    /// Given a server response to an update command, creates a corresponding
    /// `UpdateResult`. If the `from` Document does not have `matchedCount` and
    /// `modifiedCount` fields, the initialization will fail. The document may
    /// optionally have an `upsertedId` field.
    internal init?(from: Document) {
         guard let matched = from["matchedCount"] as? Int, let modified = from["modifiedCount"] as? Int else {
            return nil
         }
         self.matchedCount = matched
         self.modifiedCount = modified
         self.upsertedId = from["upsertedId"]
    }
}

/// A struct representing an index on a `MongoCollection`.
public struct IndexModel: Encodable {
    /// Contains the required keys for the index.
    public let keys: Document

    /// Contains the options for the index.
    public let options: IndexOptions?

    /// Convenience initializer providing a default `options` value
    public init(keys: Document, options: IndexOptions? = nil) {
        self.keys = keys
        self.options = options
    }

    /// Gets the default name for this index.
    internal var defaultName: String {
        return String(cString: mongoc_collection_keys_to_index_string(self.keys.data))
    }

    // Encode own data as well as nested options data
    private enum CodingKeys: String, CodingKey {
        case key, name
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keys, forKey: .key)
        try container.encode(self.options?.name ?? self.defaultName, forKey: .name)
    }

}

/// Options to use when creating an index for a collection.
public struct IndexOptions: Encodable {
    /// Optionally tells the server to build the index in the background and not block
    /// other tasks.
    public let background: Bool?

    /// Optionally specifies the length in time, in seconds, for documents to remain in
    /// a collection.
    public let expireAfter: Int32?

    /**
     * Optionally specify a specific name for the index outside of the default generated
     * name. If none is provided then the name is generated in the format "[field]_[direction]".
     *
     * Note that if an index is created for the same key pattern with different collations,
     * a name must be provided by the user to avoid ambiguity.
     *
     * - Example: For an index of name: 1, age: -1, the generated name would be "name_1_age_-1".
     */
    public let name: String?

    /// Optionally tells the index to only reference documents with the specified field in
    /// the index.
    public let sparse: Bool?

    /// Optionally used only in MongoDB 3.0.0 and higher. Specifies the storage engine
    /// to store the index in.
    public let storageEngine: String?

    /// Optionally forces the index to be unique.
    public let unique: Bool?

    /// Optionally specifies the index version number, either 0 or 1.
    public let version: Int32?

    /// Optionally specifies the default language for text indexes. Is english if none is provided.
    public let defaultLanguage: String?

    /// Optionally Specifies the field in the document to override the language.
    public let languageOverride: String?

    /// Optionally provides the text index version number.
    public let textVersion: Int32?

    /// Optionally specifies fields in the index and their corresponding weight values.
    public let weights: Document?

    /// Optionally specifies the 2dsphere index version number.
    public let sphereVersion: Int32?

    /// Optionally specifies the precision of the stored geo hash in the 2d index, from 1 to 32.
    public let bits: Int32?

    /// Optionally sets the maximum boundary for latitude and longitude in the 2d index.
    public let max: Double?

    /// Optionally sets the minimum boundary for latitude and longitude in the index in a 2d index.
    public let min: Double?

    /// Optionally specifies the number of units within which to group the location values in a geo haystack index.
    public let bucketSize: Int32?

    /// Optionally specifies a filter for use in a partial index. Only documents that match the
    /// filter expression are included in the index.
    public let partialFilterExpression: Document?

    /// Optionally specifies a collation to use for the index in MongoDB 3.4 and higher.
    /// If not specified, no collation is sent and the default collation of the collection
    /// server-side is used.
    public let collation: Document?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(background: Bool? = nil, expireAfter: Int32? = nil, name: String? = nil, sparse: Bool? = nil,
                storageEngine: String? = nil, unique: Bool? = nil, version: Int32? = nil,
                defaultLanguage: String? = nil, languageOverride: String? = nil, textVersion: Int32? = nil,
                weights: Document? = nil, sphereVersion: Int32? = nil, bits: Int32? = nil, max: Double? = nil,
                min: Double? = nil, bucketSize: Int32? = nil, partialFilterExpression: Document? = nil,
                collation: Document? = nil) {
        self.background = background
        self.expireAfter = expireAfter
        self.name = name
        self.sparse = sparse
        self.storageEngine = storageEngine
        self.unique = unique
        self.version = version
        self.defaultLanguage = defaultLanguage
        self.languageOverride = languageOverride
        self.textVersion = textVersion
        self.weights = weights
        self.sphereVersion = sphereVersion
        self.bits = bits
        self.max = max
        self.min = min
        self.bucketSize = bucketSize
        self.partialFilterExpression = partialFilterExpression
        self.collation = collation
    }

    // Encode everything besides the name, as we will handle that when encoding the `IndexModel`
    private enum CodingKeys: String, CodingKey {
        case background, expireAfter, sparse, storageEngine, unique, version, defaultLanguage,
            languageOverride, textVersion, weights, sphereVersion, bits, max, min, bucketSize,
            partialFilterExpression, collation
    }
}

/// Options to use when creating a new index on a `MongoCollection`.
public struct CreateIndexOptions {
    /// An optional `WriteConcern` to use for the command
    let writeConcern: WriteConcern?
}

/// Options to use when dropping an index from a `MongoCollection`.
public struct DropIndexOptions {
    /// An optional `WriteConcern` to use for the command
    let writeConcern: WriteConcern?
}

/// A MongoDB collection.
public class MongoCollection<T: Codable> {
    private var _collection: OpaquePointer?
    private var _client: MongoClient?

    /// A `Codable` type associated with this `MongoCollection` instance. 
    /// This allows `CollectionType` values to be directly inserted into and 
    /// retrieved from the collection, by encoding/decoding them using the 
    /// `BsonEncoder` and `BsonDecoder`. 
    /// This type association only exists in the context of this particular 
    /// `MongoCollection` instance. It is the responsibility of the user to 
    /// ensure that any data already stored in the collection was encoded 
    /// from this same type.
    public typealias CollectionType = T

    /// The name of this collection.
    public var name: String {
        return String(cString: mongoc_collection_get_name(self._collection))
    }

    /// The `ReadConcern` set on this collection, or `nil` if one is not set.
    public var readConcern: ReadConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let readConcern = mongoc_collection_get_read_concern(self._collection)
        let rcObj = ReadConcern(from: readConcern)
        if rcObj.isDefault { return nil }
        return rcObj
    }

    /// The `WriteConcern` set on this collection, or nil if one is not set.
    public var writeConcern: WriteConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let writeConcern = mongoc_collection_get_write_concern(self._collection)
        let wcObj = WriteConcern(writeConcern)
        if wcObj.isDefault { return nil }
        return wcObj
    }

    /// Initializes a new `MongoCollection` instance, not meant to be instantiated directly
    internal init(fromCollection: OpaquePointer, withClient: MongoClient) {
        self._collection = fromCollection
        self._client = withClient
    }

    /// Deinitializes a `MongoCollection`, cleaning up the internal `mongoc_collection_t`
    deinit {
        self._client = nil
        guard let collection = self._collection else {
            return
        }
        mongoc_collection_destroy(collection)
        self._collection = nil
    }

    /// Drops this collection from its parent database.
    public func drop() throws {
        var error = bson_error_t()
        if !mongoc_collection_drop(self._collection, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
    }

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
        guard let cursor = mongoc_collection_find_with_opts(self._collection, filter.data, opts?.data, nil) else {
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
        let pipeline: Document = ["pipeline": pipeline]
        guard let cursor = mongoc_collection_aggregate(
            self._collection, MONGOC_QUERY_NONE, pipeline.data, withWC?.data, nil) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: cursor, withClient: client)
    }

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
        var error = bson_error_t()
        // because we already encode skip and limit in the options,
        // pass in 0s so we don't get duplicate parameter errors.
        let count = mongoc_collection_count_with_opts(
            self._collection, MONGOC_QUERY_NONE, filter.data, 0, 0, opts?.data, nil, &error)

        if count == -1 { throw MongoError.commandError(message: toErrorString(error)) }

        return Int(count)
    }

    /**
     * Finds the distinct values for a specified field across the collection.
     *
     * - Parameters:
     *   - fieldName: The field for which the distinct values will be found
     *   - filter: a `Document` representing the filter that documents must match in order to be considered for this operation
     *   - options: Optional `DistinctOptions` to use when executing the command
     *
     * - Returns: A 'MongoCursor' containing the distinct values for the specified criteria
     */
    public func distinct(fieldName: String, filter: Document = [:],
                         options: DistinctOptions? = nil) throws -> MongoCursor<Document> {
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }

        let collName = String(cString: mongoc_collection_get_name(self._collection))
        let command: Document = [
            "distinct": collName,
            "key": fieldName,
            "query": filter
        ]

        let opts = try BsonEncoder().encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_read_command_with_opts(
            self._collection, command.data, nil, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }

        let fakeReply: Document = [
            "ok": 1,
            "cursor": [
                "id": 0,
                "ns": "",
                "firstBatch": [reply]
            ] as Document
        ]

        // mongoc_cursor_new_from_command_reply will bson_destroy the data we pass in,
        // so copy it to avoid destroying twice (already done in Document deinit)
        let fakeData = bson_copy(fakeReply.data)
        guard let newCursor = mongoc_cursor_new_from_command_reply(client._client, fakeData, 0) else {
            throw MongoError.invalidResponse()
        }

        return MongoCursor(fromCursor: newCursor, withClient: client)
    }

    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it.
     *
     * - Parameters:
     *   - value: A `CollectionType` value to encode and insert
     *   - options: Optional `InsertOneOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to perform the insert. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func insertOne(_ value: CollectionType, options: InsertOneOptions? = nil) throws -> InsertOneResult? {
        let encoder = BsonEncoder()
        let document = try encoder.encode(value)
        if document["_id"] == nil {
            try ObjectId().encode(to: document.data, forKey: "_id")
        }
        let opts = try WriteConcern.append(options?.writeConcern, to: try encoder.encode(options), callerWC: self.writeConcern)
        var error = bson_error_t()
        if !mongoc_collection_insert_one(self._collection, document.data, opts?.data, nil, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return InsertOneResult(insertedId: document["_id"]!)
    }

    /**
     * Encodes the provided values to BSON and inserts them. If any values are missing identifiers,
     * the driver will generate them.
     *
     * - Parameters:
     *   - documents: The `CollectionType` values to insert
     *   - options: Optional `InsertManyOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to performing the insert. If the write concern
     *            is unacknowledged, nil is returned
     */
    @discardableResult
    public func insertMany(_ values: [CollectionType], options: InsertManyOptions? = nil) throws -> InsertManyResult? {
        let encoder = BsonEncoder()

        let documents = try values.map { try encoder.encode($0) }
        for doc in documents where doc["_id"] == nil {
            try ObjectId().encode(to: doc.data, forKey: "_id")
        }
        var docPointers = documents.map { UnsafePointer($0.data) }

        let opts = try WriteConcern.append(options?.writeConcern, to: try encoder.encode(options), callerWC: self.writeConcern)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_insert_many(
            self._collection, &docPointers, documents.count, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return InsertManyResult(fromArray: documents.map { $0["_id"]! })
    }

    /**
     * Replaces a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - replacement: The replacement value, a `CollectionType` value to be encoded and inserted
     *   - options: Optional `ReplaceOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to replace a document. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func replaceOne(filter: Document, replacement: CollectionType, options: ReplaceOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let replacementDoc = try encoder.encode(replacement)
        let opts = try WriteConcern.append(options?.writeConcern, to: try encoder.encode(options), callerWC: self.writeConcern)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_replace_one(
            self._collection, filter.data, replacementDoc.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return UpdateResult(from: reply)
    }

    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to a matching document
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to update a document. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func updateOne(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let opts = try WriteConcern.append(options?.writeConcern, to: try encoder.encode(options), callerWC: self.writeConcern)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_update_one(
            self._collection, filter.data, update.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return UpdateResult(from: reply)
    }

    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to matching documents
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to update multiple documents. If the write
     *            concern is unacknowledged, nil is returned
     */
    @discardableResult
    public func updateMany(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let opts = try WriteConcern.append(options?.writeConcern, to: try encoder.encode(options), callerWC: self.writeConcern)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_update_many(
            self._collection, filter.data, update.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return UpdateResult(from: reply)
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func deleteOne(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let encoder = BsonEncoder()
        let opts = try WriteConcern.append(options?.writeConcern, to: try encoder.encode(options), callerWC: self.writeConcern)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_delete_one(
            self._collection, filter.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return DeleteResult(from: reply)
    }

    /**
     * Deletes multiple documents
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     */
    @discardableResult
    public func deleteMany(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let encoder = BsonEncoder()
        let opts = try WriteConcern.append(options?.writeConcern, to: try encoder.encode(options), callerWC: self.writeConcern)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_delete_many(
            self._collection, filter.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return DeleteResult(from: reply)
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - model: An `IndexModel` representing the keys and options for the index
     *   - writeConcern: Optional WriteConcern to use for the command
     *
     * - Returns: The name of the created index.
     */
    @discardableResult
    public func createIndex(_ forModel: IndexModel, options: CreateIndexOptions? = nil) throws -> String {
        return try createIndexes([forModel], options: options)[0]
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - keys: a `Document` specifing the keys for the index
     *   - options: Optional `IndexOptions` to use for the index
     *   - writeConcern: Optional `WriteConcern` to use for the command
     *
     * - Returns: The name of the created index
     */
    @discardableResult
    public func createIndex(_ keys: Document, options: IndexOptions? = nil,
                            commandOptions: CreateIndexOptions? = nil) throws -> String {
        return try createIndex(IndexModel(keys: keys, options: options), options: commandOptions)
    }

    /**
     * Creates multiple indexes in the collection.
     *
     * - Parameters:
     *   - models: An `[IndexModel]` specifying the indexes to create
     *   - writeConcern: Optional `WriteConcern` to use for the command
     *
     * - Returns: An `[String]` containing the names of all the indexes that were created.
     */
    @discardableResult
    public func createIndexes(_ forModels: [IndexModel], options: CreateIndexOptions? = nil) throws -> [String] {
        let collName = String(cString: mongoc_collection_get_name(self._collection))
        let encoder = BsonEncoder()
        var indexData = [Document]()
        for index in forModels {
            var indexDoc = try encoder.encode(index)
            if let opts = try encoder.encode(index.options) {
                try indexDoc.merge(opts)
            }
            indexData.append(indexDoc)
        }

        let command: Document = [
            "createIndexes": collName,
            "indexes": indexData
        ]

        var error = bson_error_t()
        let opts = try WriteConcern.append(options?.writeConcern, to: nil, callerWC: self.writeConcern)
        if !mongoc_collection_write_command_with_opts(self._collection, command.data, opts?.data, nil, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }

        return forModels.map { $0.options?.name ?? $0.defaultName }
    }

     /**
     * Drops a single index from the collection by the index name.
     *
     * - Parameters:
     *   - name: The name of the index to drop
     *   - writeConcern: An optional WriteConcern to use for the command
     *
     */
    public func dropIndex(_ name: String, options: DropIndexOptions? = nil) throws {
        var error = bson_error_t()
        let opts = try WriteConcern.append(options?.writeConcern, to: nil, callerWC: self.writeConcern)
        if !mongoc_collection_drop_index_with_opts(self._collection, name, opts?.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
    }

    /**
     * Attempts to drop a single index from the collection given the keys and options describing it.
     *
     * - Parameters:
     *   - keys: a `Document` containing the keys for the index to drop
     *   - options: Optional `IndexOptions` the dropped index should match
     *   - writeConcern: An optional `WriteConcern` to use for the command
     *
     * - Returns: a `Document` containing the server's response to the command.
     */
    @discardableResult
    public func dropIndex(_ keys: Document, options: IndexOptions? = nil,
                            commandOptions: DropIndexOptions? = nil) throws -> Document {
        return try dropIndex(IndexModel(keys: keys, options: options), options: commandOptions)
    }

    /**
     * Attempts to drop a single index from the collection given an `IndexModel` describing it.
     *
     * - Parameters:
     *   - model: An `IndexModel` describing the index to drop
     *   - writeConcern: An optional `WriteConcern` to use for the command
     *
     * - Returns: a `Document` containing the server's response to the command.
     */
    @discardableResult
    public func dropIndex(_ model: IndexModel, options: DropIndexOptions? = nil) throws -> Document {
        return try _dropIndexes(keys: model.keys, options: options)
    }

    /**
     * Drops all indexes in the collection.
     * 
     * - Parameters:
    *   - writeConcern: An optional `WriteConcern` to use for the command
     *
     * - Returns: a `Document` containing the server's response to the command.
     */
    @discardableResult
    public func dropIndexes(options: DropIndexOptions? = nil) throws -> Document {
        return try _dropIndexes(options: options)
    }

    private func _dropIndexes(keys: Document? = nil, options: DropIndexOptions? = nil) throws -> Document {
        let collName = String(cString: mongoc_collection_get_name(self._collection))
        let command: Document = ["dropIndexes": collName, "index": keys ?? "*"]
        let reply = Document()
        var error = bson_error_t()
        let opts = try WriteConcern.append(options?.writeConcern, to: nil, callerWC: self.writeConcern)
        if !mongoc_collection_write_command_with_opts(self._collection, command.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return reply
    }

    /**
     * Retrieves a list of the indexes currently on this collection.
     *
     * - Returns: A `MongoCursor` over the index names.
     */
    public func listIndexes() throws -> MongoCursor<Document> {
        guard let cursor = mongoc_collection_find_indexes_with_opts(self._collection, nil) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: cursor, withClient: client)
    }
}
