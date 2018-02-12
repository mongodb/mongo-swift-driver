import libmongoc

public struct AggregateOptions {
    /// Enables writing to temporary files. When set to true, aggregation stages
    /// can write data to the _tmp subdirectory in the dbPath directory
    let allowDiskUse: Bool?

    /// The number of documents to return per batch.
    let batchSize: Int32?

    /// If true, allows the write to opt-out of document level validation. This only applies
    /// when the $out stage is specified.
    let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    let collation: Document?

    /// The maximum amount of time to allow the query to run.
    let maxTimeMS: Int64?

    /// Enables users to specify an arbitrary string to help trace the operation through
    /// the database profiler, currentOp and logs. The default is to not send a value.
    let comment: String?

    /// The index to use for the aggregation. The hint does not apply to $lookup and $graphLookup stages.
    // let hint: Optional<(String | Document)>
}

public struct CountOptions {
    /// Specifies a collation.
    let collation: Document?

    /// The index to use.
    // let hint: Optional<(String | Document)>

    /// The maximum number of documents to count.
    let limit: Int64?

    /// The maximum amount of time to allow the query to run.
    let maxTimeMS: Int64?

    /// The number of documents to skip before counting.
    let skip: Int64?
}

public struct DistinctOptions {
    /// Specifies a collation.
    let collation: Document?

    /// The maximum amount of time to allow the query to run.
    let maxTimeMS: Int64?
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

public struct FindOptions {
    /// Get partial results from a mongos if some shards are down (instead of throwing an error).
    let allowPartialResults: Bool?

    /// The number of documents to return per batch.
    let batchSize: Int32?

    /// Specifies a collation.
    let collation: Document?

    /// Attaches a comment to the query.
    let comment: String?

    /// Indicates the type of cursor to use. This value includes both the tailable and awaitData options.
    let cursorType: CursorType?

    /// The index to use.
    // let hint: Optional<(String | Document)>

    /// The maximum number of documents to return.
    let limit: Int64?

    /// The exclusive upper bound for a specific index.
    let max: Document?

    /// The maximum amount of time for the server to wait on new documents to satisfy a tailable cursor
    /// query. This only applies to a TAILABLE_AWAIT cursor. When the cursor is not a TAILABLE_AWAIT cursor,
    /// this option is ignored.
    let maxAwaitTimeMS: Int64?

    /// Maximum number of documents or index keys to scan when executing the query.
    let maxScan: Int64?

    /// The maximum amount of time to allow the query to run.
    let maxTimeMS: Int64?

    /// The inclusive lower bound for a specific index.
    let min: Document?

    /// The server normally times out idle cursors after an inactivity period (10 minutes)
    /// to prevent excess memory use. Set this option to prevent that.
    let noCursorTimeout: Bool?

    /// Limits the fields to return for all matching documents.
    let projection: Document?

    /// If true, returns only the index keys in the resulting documents.
    let returnKey: Bool?

    /// Determines whether to return the record identifier for each document. If true, adds a field $recordId
    /// to the returned documents.
    let showRecordId: Bool?

    /// The number of documents to skip before returning.
    let skip: Int64?

    /// The order in which to return matching documents.
    let sort: Document?
}

public struct InsertOneOptions {
    /// If true, allows the write to opt-out of document level validation.
    let bypassDocumentValidation: Bool?
}

public struct InsertManyOptions {
    /// If true, allows the write to opt-out of document level validation.
    let bypassDocumentValidation: Bool?

    /// If true, when an insert fails, return without performing the remaining
    /// writes. If false, when a write fails, continue with the remaining writes, if any.
    /// Defaults to true.
    let ordered: Bool = true
}

public struct UpdateOptions {
    /// A set of filters specifying to which array elements an update should apply.
    let arrayFilters: [Document]?

    /// If true, allows the write to opt-out of document level validation.
    let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    let collation: Document?

    /// When true, creates a new document if no document matches the query.
    let upsert: Bool?
}

public struct ReplaceOptions {
    /// If true, allows the write to opt-out of document level validation.
    let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    let collation: Document?

    /// When true, creates a new document if no document matches the query.
    let upsert: Bool?
}

public struct DeleteOptions {
    /// Specifies a collation.
    let collation: Document?
}

public struct InsertOneResult {
    /// The identifier that was inserted. If the server generated the identifier, this value
    /// will be null as the driver does not have access to that data.
    let insertedId: Any
}

public struct InsertManyResult {
    /// Map of the index of the inserted document to the id of the inserted document.
    let insertedIds: [Int64: Any]
}

public struct DeleteResult {
    /// The number of documents that were deleted.
    let deletedCount: Int64
}

public struct UpdateResult {
    /// The number of documents that matched the filter.
    let matchedCount: Int64

    /// The number of documents that were modified.
    let modifiedCount: Int64

    /// The identifier of the inserted document if an upsert took place.
    let upsertedId: Any
}

public struct IndexModel {
    /// Contains the required keys for the index.
    let keys: Document

    /// Contains the options for the index.
    let options: IndexOptions?
}

public struct IndexOptions {
    /// Optionally tells the server to build the index in the background and not block
    /// other tasks.
    let background: Bool?

    /// Optionally specifies the length in time, in seconds, for documents to remain in
    /// a collection.
    let expireAfter: Int32?

    /**
     * Optionally specify a specific name for the index outside of the default generated
     * name. If none is provided then the name is generated in the format "[field]_[direction]".
     *
     * Note that if an index is created for the same key pattern with different collations,
     * a name must be provided by the user to avoid ambiguity.
     *
     * - Example: For an index of name: 1, age: -1, the generated name would be "name_1_age_-1".
     */
    let name: String?

    /// Optionally tells the index to only reference documents with the specified field in
    /// the index.
    let sparse: Bool?

    /// Optionally used only in MongoDB 3.0.0 and higher. Specifies the storage engine
    /// to store the index in.
    let storageEngine: String?

    /// Optionally forces the index to be unique.
    let unique: Bool?

    /// Optionally specifies the index version number, either 0 or 1.
    let version: Int32?

    /// Optionally specifies the default language for text indexes. Is english if none is provided.
    let defaultLanguage: String?

    /// Optionally Specifies the field in the document to override the language.
    let languageOverride: String?

    /// Optionally provides the text index version number.
    let textVersion: Int32?

    /// Optionally specifies fields in the index and their corresponding weight values.
    let weights: Document?

    /// Optionally specifies the 2dsphere index version number.
    let sphereVersion: Int32?

    /// Optionally specifies the precision of the stored geo hash in the 2d index, from 1 to 32.
    let bits: Int32?

    /// Optionally sets the maximum boundary for latitude and longitude in the 2d index.
    let max: Double?

    /// Optionally sets the minimum boundary for latitude and longitude in the index in a 2d index.
    let min: Double?

    /// Optionally specifies the number of units within which to group the location values in a geo haystack index.
    let bucketSize: Int32?

    /// Optionally specifies a filter for use in a partial index. Only documents that match the
    /// filter expression are included in the index.
    let partialFilterExpression: Document?

    /// Optionally specifies a collation to use for the index in MongoDB 3.4 and higher.
    /// If not specified, no collation is sent and the default collation of the collection
    /// server-side is used.
    let collation: Document?
}

// A MongoDB Collection
public class Collection {
    private var _collection = OpaquePointer(bitPattern: 1)
    /**
        Initializes a new Collection instance, not meant to be instantiated directly
     */
    public init(fromCollection: OpaquePointer) {
        self._collection = fromCollection
    }

    public init(fromCollection: OpaquePointer) {
        _collection = fromCollection
    }

    /**
        Deinitializes a Collection, cleaning up the internal mongoc_collection_t
     */
    deinit {
        guard let collection = self._collection else {
            return
        }

        mongoc_collection_destroy(collection)
        self._collection = nil
    }

    /**
     * Drops this collection from its parent database
     */
    func drop() throws {
    }

    /**
     * Finds the documents in this collection which match the provided filter
     *
     * - Parameters:
     *   - filter: A `Document` that should match the query
     *   - options: Optional settings
     *
     * - Returns: A `Cursor` with the results
     */
    func find(filter: Document, options: FindOptions? = nil) throws -> Cursor {
        return Cursor()
    }

    /**
     * Runs an aggregation framework pipeline against this collection
     *
     * - Parameters:
     *   - pipeline: The pipeline of aggregation operations to perform
     *   - options: Optional settings
     *
     * - Returns: A `Cursor` with the results
     */
    func aggregate(pipeline: [Document], options: AggregateOptions? = nil) throws -> Cursor {
        return Cursor()
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
    func count(filter: Document, options: CountOptions? = nil) throws -> Int {
        return 0
    }

    /**
     * Finds the distinct values for a specified field accross the collection
     *
     * - Parameters:
     *   - fieldName: The field for which the distinct values will be found
     *   - filter: The filter that documents must match in order to be considered for this operation
     *   - options: Optional settings
     *
     * - Returns: A 'Cursor' containing the distinct values for the specified criteria
     */
    func distinct(fieldName: String, filter: Document, options: DistinctOptions? = nil) throws -> Cursor {
        return Cursor()
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
    func insertOne(document: Document, options: InsertOneOptions? = nil) throws -> InsertOneResult? {
        return nil
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
    func insertMany(documents: [Document], options: InsertManyOptions? = nil) throws -> InsertManyResult? {
        return nil
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
    func replaceOne(filter: Document, replacement: Document, options: ReplaceOptions? = nil) throws -> UpdateResult? {
        return nil
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
    func updateOne(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        return nil
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
    func updateMany(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        return nil
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
    func deleteOne(filter: Document, options: DeleteOptions?) throws -> DeleteResult? {
        return nil
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
    func deleteMany(filter: Document, options: DeleteOptions?) throws -> DeleteResult? {
        return nil
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options
     *
     * - Parameters:
     *   - model: An `IndexModel` representing the keys and options for the index
     *
     * - Returns: The name of the created index
     */
    func createIndex(model: IndexModel) throws -> String {
        return "index_name"
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
    func createIndex(keys: Document, options: IndexOptions? = nil) throws -> String {
        return try createIndex(model: IndexModel(keys: keys, options: options))
    }

    /**
     * Creates multiple indexes in the collection
     *
     * - Parameters:
     *   - models: An array of `IndexModel` specifying the indexes to create
     *
     * - Returns: The names of all the indexes that were created
     */
    func createIndexes(models: [IndexModel]) throws -> [String] {
        return ["index_name"]
    }

     /**
     * Drops a single index from the collection by the index name
     *
     * - Parameters:
     *   - name: The name of the index to drop
     *
     * - Returns: The result of the command returned from the server
     */
    func dropIndex(name: String) throws -> Document {
        return Document()
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
    func dropIndex(keys: Document, options: IndexOptions? = nil) throws -> Document {
        return try dropIndex(model: IndexModel(keys: keys, options: options))
    }

    /**
     * Attempts to drop a single index from the collection given an `IndexModel`
     *
     * - Parameters:
     *   - model: The model describing the index to drop
     *
     * - Returns: The result of the command returned from the server
     */
    func dropIndex(model: IndexModel) throws -> Document {
        return Document()
    }

    /**
     * Drops all indexes in the collection
     *
     * - Returns: The result of the command returned from the server
     */
    func dropIndexes() throws -> Document {
        return Document()
    }

    /**
     * Returns a list of the indexes currently on this collection
     *
     * - Returns: A `Cursor` over a collection of index names
     */
    func listIndexes() throws -> Cursor {
        return Cursor()
    }
}
