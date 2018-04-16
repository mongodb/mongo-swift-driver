import libmongoc

public struct AggregateOptions: BsonEncodable {
    /// Enables writing to temporary files. When set to true, aggregation stages
    /// can write data to the _tmp subdirectory in the dbPath directory
    public let allowDiskUse: Bool?

    /// The number of documents to return per batch.
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

    /// A ReadConcern to use for this operation. 
    let readConcern: ReadConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(allowDiskUse: Bool? = nil, batchSize: Int32? = nil, bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil, comment: String? = nil, maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil) {
        self.allowDiskUse = allowDiskUse
        self.batchSize = batchSize
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.comment = comment
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
    }

    public var skipFields: [String] { return ["readConcern"] }
}

public struct CountOptions: BsonEncodable {
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
    let readConcern: ReadConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil, limit: Int64? = nil, maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil, skip: Int64? = nil) {
        self.collation = collation
        self.limit = limit
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.skip = skip
    }

    public var skipFields: [String] { return ["readConcern"] }
}

public struct DistinctOptions: BsonEncodable {
    /// Specifies a collation.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// A ReadConcern to use for this operation. 
    let readConcern: ReadConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil, maxTimeMS: Int64? = nil, readConcern: ReadConcern? = nil) {
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
    }

    public var skipFields: [String] { return ["readConcern"] }
}

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

public struct FindOptions: BsonEncodable {
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
    let readConcern: ReadConcern?

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

    public var skipFields: [String] { return ["readConcern"] }
}

public struct InsertOneOptions: BsonEncodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Convenience initializer allowing bypassDocumentValidation to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
    }
}

public struct InsertManyOptions: BsonEncodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// If true, when an insert fails, return without performing the remaining
    /// writes. If false, when a write fails, continue with the remaining writes, if any.
    /// Defaults to true.
    public var ordered: Bool = true

    /// Convenience initializer allowing any/all parameters to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, ordered: Bool? = true) {
        self.bypassDocumentValidation = bypassDocumentValidation
        if let o = ordered { self.ordered = o }
    }
}

public struct UpdateOptions: BsonEncodable {
    /// A set of filters specifying to which array elements an update should apply.
    public let arrayFilters: [Document]?

    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(arrayFilters: [Document]? = nil, bypassDocumentValidation: Bool? = nil, collation: Document? = nil,
                upsert: Bool? = nil) {
        self.arrayFilters = arrayFilters
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
    }
}

public struct ReplaceOptions: BsonEncodable {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(bypassDocumentValidation: Bool? = nil, collation: Document? = nil, upsert: Bool? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
    }
}

public struct DeleteOptions: BsonEncodable {
    /// Specifies a collation.
    public let collation: Document?

     /// Convenience initializer allowing collation to be omitted or optional
    public init(collation: Document? = nil) {
        self.collation = collation
    }
}

public struct InsertOneResult {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BsonValue
}

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

public struct UpdateResult {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents that were modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: Any

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
         self.upsertedId = from["upsertedId"] as Any
    }
}

public struct IndexModel: BsonEncodable {
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

    public func encode(to encoder: BsonEncoder) throws {
        // we need a flat document containing key, name, and options,
        // so encode the options directly to this encoder first
        try self.options?.encode(to: encoder)
        try encoder.encode(keys, forKey: "key")
        if self.options?.name == nil {
            try encoder.encode(self.defaultName, forKey: "name")
        }
    }

}

public struct IndexOptions: BsonEncodable {
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
}

// A MongoDB Collection
public class MongoCollection {
    private var _collection: OpaquePointer?
    private var _client: MongoClient?

    /// The name of this collection.
    public var name: String {
        return String(cString: mongoc_collection_get_name(self._collection))
    }

    /// The readConcern set on this collection.
    public var readConcern: ReadConcern {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let readConcern = mongoc_collection_get_read_concern(self._collection)
        return ReadConcern(readConcern)
    }

    /**
        Initializes a new MongoCollection instance, not meant to be instantiated directly
     */
    internal init(fromCollection: OpaquePointer, withClient: MongoClient) {
        self._collection = fromCollection
        self._client = withClient
    }

    /**
        Deinitializes a MongoCollection, cleaning up the internal mongoc_collection_t
     */
    deinit {
        self._client = nil
        guard let collection = self._collection else {
            return
        }
        mongoc_collection_destroy(collection)
        self._collection = nil
    }

    /**
     * Drops this collection from its parent database
     */
    public func drop() throws {
        var error = bson_error_t()
        if !mongoc_collection_drop(self._collection, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
    }

    /**
     * Finds the documents in this collection which match the provided filter
     *
     * - Parameters:
     *   - filter: A `Document` that should match the query
     *   - options: Optional settings
     *
     * - Returns: A `MongoCursor` with the results
     */
    public func find(_ filter: Document = [:], options: FindOptions? = nil) throws -> MongoCursor {
        let encoder = BsonEncoder()
        let opts = try ReadConcern.append(options?.readConcern, to: try encoder.encode(options), callerRC: self.readConcern)
        guard let cursor = mongoc_collection_find_with_opts(self._collection, filter.data, opts?.data, nil) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: cursor, withClient: client)
    }

    /**
     * Runs an aggregation framework pipeline against this collection
     *
     * - Parameters:
     *   - pipeline: The pipeline of aggregation operations to perform
     *   - options: Optional settings
     *
     * - Returns: A `MongoCursor` with the results
     */
    public func aggregate(_ pipeline: [Document], options: AggregateOptions? = nil) throws -> MongoCursor {
        let encoder = BsonEncoder()
        let opts = try ReadConcern.append(options?.readConcern, to: try encoder.encode(options), callerRC: self.readConcern)
        let pipeline: Document = ["pipeline": pipeline]
        guard let cursor = mongoc_collection_aggregate(
            self._collection, MONGOC_QUERY_NONE, pipeline.data, opts?.data, nil) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: cursor, withClient: client)
    }

    /**
     * Counts the number of documents matching the provided filter
     *
     * - Parameters:
     *   - filter: The filter that documents must match in order to be counted
     *   - options: Optional settings
     *
     * - Returns: The count of the documents that matched the filter
     */
    public func count(_ filter: Document = [:], options: CountOptions? = nil) throws -> Int {
        let encoder = BsonEncoder()
        let opts = try ReadConcern.append(options?.readConcern, to: try encoder.encode(options), callerRC: self.readConcern)
        var error = bson_error_t()
        // because we already encode skip and limit in the options,
        // pass in 0s so we don't get duplicate parameter errors.
        let count = mongoc_collection_count_with_opts(
            self._collection, MONGOC_QUERY_NONE, filter.data, 0, 0, opts?.data, nil, &error)

        if count == -1 { throw MongoError.commandError(message: toErrorString(error)) }

        return Int(count)
    }

    /**
     * Finds the distinct values for a specified field across the collection
     *
     * - Parameters:
     *   - fieldName: The field for which the distinct values will be found
     *   - filter: The filter that documents must match in order to be considered for this operation
     *   - options: Optional settings
     *
     * - Returns: A 'MongoCursor' containing the distinct values for the specified criteria
     */
    public func distinct(fieldName: String, filter: Document = [:],
                         options: DistinctOptions? = nil) throws -> MongoCursor {
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }

        let collName = String(cString: mongoc_collection_get_name(self._collection))
        let command: Document = [
            "distinct": collName,
            "key": fieldName,
            "query": filter
        ]
        let encoder = BsonEncoder()
        let opts = try ReadConcern.append(options?.readConcern, to: try encoder.encode(options), callerRC: self.readConcern)

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
     * Inserts the provided document. If the document is missing an identifier, one will be
     * generated for it
     *
     * - Parameters:
     *   - document: The document to insert
     *   - options: Optional settings
     *
     * - Returns: The optional result of attempting to perform the insert. If the write concern
     *            is unacknowledged, nil is returned
     */
    public func insertOne(_ document: Document, options: InsertOneOptions? = nil) throws -> InsertOneResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        var error = bson_error_t()
        if document["_id"] == nil {
            try ObjectId().encode(to: document.data, forKey: "_id")
        }
        if !mongoc_collection_insert_one(self._collection, document.data, opts?.data, nil, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return InsertOneResult(insertedId: document["_id"]!)
    }

    /**
     * Inserts the provided documents. If any documents are missing an identifier,
     * the driver will generate them
     *
     * - Parameters:
     *   - documents: The documents to insert
     *   - options: Optional settings
     *
     * - Returns: The optional result of attempting to performing the insert. If the write concern
     *            is unacknowledged, nil is returned
     */
    public func insertMany(_ documents: [Document], options: InsertManyOptions? = nil) throws -> InsertManyResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)

        for doc in documents where doc["_id"] == nil {
            try ObjectId().encode(to: doc.data, forKey: "_id")
        }
        var docPointers = documents.map { UnsafePointer($0.data) }
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_insert_many(
            self._collection, &docPointers, documents.count, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return InsertManyResult(fromArray: documents.map { $0["_id"]! })
    }

    /**
     * Replaces a single document matching the provided filter in this collection
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - replacement: The replacement document
     *   - options: Optional settings
     *
     * - Returns: The optional result of attempting to replace a document. If the write concern
     *            is unacknowledged, nil is returned
     */
    public func replaceOne(filter: Document, replacement: Document, options: ReplaceOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_replace_one(
            self._collection, filter.data, replacement.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return UpdateResult(from: reply)
    }

    /**
     * Updates a single document matching the provided filter in this collection
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - update: Document representing the update to be applied to a matching document
     *   - options: Optional settings
     *
     * - Returns: The optional result of attempting to update a document. If the write concern is
     *            unacknowledged, nil is returned
     */
    public func updateOne(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_update_one(
            self._collection, filter.data, update.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return UpdateResult(from: reply)
    }

    /**
     * Updates multiple documents matching the provided filter in this collection
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - update: Document representing the update to be applied to matching documents
     *   - options: Optional settings
     *
     * - Returns: The optional result of attempting to update multiple documents. If the write
     *            concern is unacknowledged, nil is returned
     */
    public func updateMany(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_update_many(
            self._collection, filter.data, update.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return UpdateResult(from: reply)
    }

    /**
     * Deletes a single matching document from the collection
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional settings
     *
     * - Returns: The optional result of performing the deletion. If the write concern is
     *            unacknowledged, nil is returned
     */
    public func deleteOne(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
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
     *   - options: Optional settings
     *
     * - Returns: The optional result of performing the deletion. If the write concern is
     *            unacknowledged, nil is returned
     */
    public func deleteMany(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        let encoder = BsonEncoder()
        let opts = try encoder.encode(options)
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_delete_many(
            self._collection, filter.data, opts?.data, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
        return DeleteResult(from: reply)
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options
     *
     * - Parameters:
     *   - model: An `IndexModel` representing the keys and options for the index
     *
     * - Returns: The name of the created index
     */
    public func createIndex(_ forModel: IndexModel) throws -> String {
        return try createIndexes([forModel])[0]
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options
     *
     * - Parameters:
     *   - keys: The keys for the index
     *   - options: Optional settings
     *
     * - Returns: The name of the created index
     */
    public func createIndex(_ keys: Document, options: IndexOptions? = nil) throws -> String {
        return try createIndex(IndexModel(keys: keys, options: options))
    }

    /**
     * Creates multiple indexes in the collection
     *
     * - Parameters:
     *   - models: An array of `IndexModel` specifying the indexes to create
     *
     * - Returns: The names of all the indexes that were created
     */
    public func createIndexes(_ forModels: [IndexModel]) throws -> [String] {
        let collName = String(cString: mongoc_collection_get_name(self._collection))
        let command: Document = [
            "createIndexes": collName,
            "indexes": try forModels.map { try BsonEncoder().encode($0) }
        ]
        var error = bson_error_t()
        if !mongoc_collection_write_command_with_opts(self._collection, command.data, nil, nil, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }

        return forModels.map { $0.options?.name ?? $0.defaultName }
    }

     /**
     * Drops a single index from the collection by the index name
     *
     * - Parameters:
     *   - name: The name of the index to drop
     *
     */
    public func dropIndex(_ name: String) throws {
        var error = bson_error_t()
        if !mongoc_collection_drop_index(self._collection, name, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
    }

    /**
     * Attempts to drop a single index from the collection given the keys and options
     *
     * - Parameters:
     *   - keys: The keys for the index
     *   - options: Optional settings
     *
     * - Returns: The result of the command returned from the server
     */
    public func dropIndex(_ keys: Document, options: IndexOptions? = nil) throws -> Document {
        return try dropIndex(IndexModel(keys: keys, options: options))
    }

    /**
     * Attempts to drop a single index from the collection given an `IndexModel`
     *
     * - Parameters:
     *   - model: The model describing the index to drop
     *
     * - Returns: The result of the command returned from the server
     */
    public func dropIndex(_ model: IndexModel) throws -> Document {
        return try _dropIndexes(keys: model.keys)
    }

    /**
     * Drops all indexes in the collection
     *
     * - Returns: The result of the command returned from the server
     */
    public func dropIndexes() throws -> Document {
        return try _dropIndexes()
    }

    private func _dropIndexes(keys: Document? = nil) throws -> Document {
        let collName = String(cString: mongoc_collection_get_name(self._collection))
        let command: Document = ["dropIndexes": collName, "index": keys ?? "*"]
        let reply = Document()
        var error = bson_error_t()
        if !mongoc_collection_write_command_with_opts(self._collection, command.data, nil, reply.data, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }

        return reply
    }

    /**
     * Returns a list of the indexes currently on this collection
     *
     * - Returns: A `MongoCursor` over a collection of index names
     */
    public func listIndexes() throws -> MongoCursor {
        guard let cursor = mongoc_collection_find_indexes_with_opts(self._collection, nil) else {
            throw MongoError.invalidResponse()
        }
        guard let client = self._client else {
            throw MongoError.invalidClient()
        }
        return MongoCursor(fromCursor: cursor, withClient: client)
    }
}
