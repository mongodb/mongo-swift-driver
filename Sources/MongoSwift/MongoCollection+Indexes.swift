import libmongoc

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
public struct CreateIndexOptions: Encodable {
    /// An optional `WriteConcern` to use for the command
    public let writeConcern: WriteConcern?
}

/// Options to use when dropping an index from a `MongoCollection`.
public struct DropIndexOptions: Encodable {
    /// An optional `WriteConcern` to use for the command
    public let writeConcern: WriteConcern?
}

/// An extension of `MongoCollection` encapsulating index management capabilities.
extension MongoCollection {
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

        let opts = try encoder.encode(options)
        var error = bson_error_t()

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
        let opts = try BsonEncoder().encode(options)
        var error = bson_error_t()
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
     *    - writeConcern: An optional `WriteConcern` to use for the command
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
        let opts = try BsonEncoder().encode(options)
        let reply = Document()
        var error = bson_error_t()
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
