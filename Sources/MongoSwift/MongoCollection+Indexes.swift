import mongoc

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
        return self.keys.map { k, v in "\(k)_\(v)" }.joined(separator: "_")
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
public struct IndexOptions: Codable {
    /// Optionally tells the server to build the index in the background and not block other tasks.
    public var background: Bool?

    /// Optionally specifies the length in time, in seconds, for documents to remain in a collection.
    public var expireAfterSeconds: Int32?

    /**
     * Optionally specify a specific name for the index outside of the default generated name. If none is provided then
     * the name is generated in the format "[field]_[direction]".
     *
     * Note that if an index is created for the same key pattern with different collations,  a name must be provided by
     * the user to avoid ambiguity.
     *
     * - Example: For an index of name: 1, age: -1, the generated name would be "name_1_age_-1".
     */
    public var name: String?

    /// Optionally tells the index to only reference documents with the specified field in the index.
    public var sparse: Bool?

    /// Optionally used only in MongoDB 3.0.0 and higher. Allows users to configure the storage engine on a per-index
    /// basis when creating an index.
    public var storageEngine: Document?

    /// Optionally forces the index to be unique.
    public var unique: Bool?

    /// Optionally specifies the index version number, either 0 or 1.
    public var indexVersion: Int32?

    /// Optionally specifies the default language for text indexes. Is 'english' if none is provided.
    public var defaultLanguage: String?

    /// Optionally specifies the field in the document to override the language.
    public var languageOverride: String?

    /// Optionally provides the text index version number. MongoDB 2.4 can only support version 1. MongoDB 2.6 and
    /// higher may support version 1 or 2.
    public var textIndexVersion: Int32?

    /// Optionally specifies fields in the index and their corresponding weight values.
    public var weights: Document?

    /// Optionally specifies the 2dsphere index version number. MongoDB 2.4 can only support version 1. MongoDB 2.6 and
    /// higher may support version 1 or 2.
    public var sphereIndexVersion: Int32?

    /// Optionally specifies the precision of the stored geo hash in the 2d index, from 1 to 32.
    public var bits: Int32?

    /// Optionally sets the maximum boundary for latitude and longitude in the 2d index.
    public var max: Double?

    /// Optionally sets the minimum boundary for latitude and longitude in the index in a 2d index.
    public var min: Double?

    /// Optionally specifies the number of units within which to group the location values in a geo haystack index.
    public var bucketSize: Int32?

    /// Optionally specifies a filter for use in a partial index. Only documents that match the filter expression are
    /// included in the index. New in MongoDB 3.2.
    public var partialFilterExpression: Document?

    /// Optionally specifies a collation to use for the index in MongoDB 3.4 and higher. If not specified, no collation
    /// is sent and the default collation of the collection server-side is used.
    public var collation: Document?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(background: Bool? = nil,
                expireAfterSeconds: Int32? = nil,
                name: String? = nil,
                sparse: Bool? = nil,
                storageEngine: Document? = nil,
                unique: Bool? = nil,
                indexVersion: Int32? = nil,
                defaultLanguage: String? = nil,
                languageOverride: String? = nil,
                textIndexVersion: Int32? = nil,
                weights: Document? = nil,
                sphereIndexVersion: Int32? = nil,
                bits: Int32? = nil,
                max: Double? = nil,
                min: Double? = nil,
                bucketSize: Int32? = nil,
                partialFilterExpression: Document? = nil,
                collation: Document? = nil) {
        self.background = background
        self.expireAfterSeconds = expireAfterSeconds
        self.name = name
        self.sparse = sparse
        self.storageEngine = storageEngine
        self.unique = unique
        self.indexVersion = indexVersion
        self.defaultLanguage = defaultLanguage
        self.languageOverride = languageOverride
        self.textIndexVersion = textIndexVersion
        self.weights = weights
        self.sphereIndexVersion = sphereIndexVersion
        self.bits = bits
        self.max = max
        self.min = min
        self.bucketSize = bucketSize
        self.partialFilterExpression = partialFilterExpression
        self.collation = collation
    }

    // Encode everything besides the name, as we will handle that when encoding the `IndexModel`
    private enum CodingKeys: String, CodingKey {
        case background, expireAfterSeconds, sparse, storageEngine, unique, indexVersion = "v",
            defaultLanguage = "default_language", languageOverride = "language_override", textIndexVersion, weights,
            sphereIndexVersion = "2dsphereIndexVersion", bits, max, min, bucketSize, partialFilterExpression, collation
    }
}

/// An extension of `MongoCollection` encapsulating index management capabilities.
extension MongoCollection {
    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - keys: a `Document` specifing the keys for the index
     *   - options: Optional `IndexOptions` to use for the index
     *   - commandOptions: Optional `CreateIndexOptions` to use for the command
     *
     * - Returns: The name of the created index.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the write.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the index specification or options.
     */
    @discardableResult
    public func createIndex(_ keys: Document,
                            options: IndexOptions? = nil,
                            commandOptions: CreateIndexOptions? = nil,
                            session: ClientSession? = nil) throws -> String {
        return try createIndexes([IndexModel(keys: keys, options: options)],
                                 options: commandOptions,
                                 session: session)[0]
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - model: An `IndexModel` representing the keys and options for the index
     *   - options: Optional `CreateIndexOptions` to use for the command
     *
     * - Returns: The name of the created index.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the write.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the index specification or options.
     */
    @discardableResult
    public func createIndex(_ model: IndexModel,
                            options: CreateIndexOptions? = nil,
                            session: ClientSession? = nil) throws -> String {
        return try createIndexes([model], options: options, session: session)[0]
    }

    /**
     * Creates multiple indexes in the collection.
     *
     * - Parameters:
     *   - models: An `[IndexModel]` specifying the indexes to create
     *   - options: Optional `CreateIndexOptions` to use for the command
     *
     * - Returns: An `[String]` containing the names of all the indexes that were created.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the write.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the index specifications or options.
     */
    @discardableResult
    public func createIndexes(_ models: [IndexModel],
                              options: CreateIndexOptions? = nil,
                              session: ClientSession? = nil) throws -> [String] {
        let operation = CreateIndexesOperation(collection: self, models: models, options: options, session: session)
        return try operation.execute()
    }

    /**
     * Drops a single index from the collection by the index name.
     *
     * - Parameters:
     *   - name: The name of the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    @discardableResult
    public func dropIndex(_ name: String,
                          options: DropIndexOptions? = nil,
                          session: ClientSession? = nil) throws -> Document {
        guard name != "*" else {
            throw UserError.invalidArgumentError(message:
                "Invalid index name '*'; use dropIndexes() to drop all indexes")
        }
        return try _dropIndexes(index: name, options: options, session: session)
    }

    /**
     * Attempts to drop a single index from the collection given the keys describing it.
     *
     * - Parameters:
     *   - keys: a `Document` containing the keys for the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *
     * - Returns: a `Document` containing the server's response to the command.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    @discardableResult
    public func dropIndex(_ keys: Document,
                          commandOptions: DropIndexOptions? = nil,
                          session: ClientSession? = nil) throws -> Document {
        return try _dropIndexes(index: keys, options: commandOptions, session: session)
    }

    /**
     * Attempts to drop a single index from the collection given an `IndexModel` describing it.
     *
     * - Parameters:
     *   - model: An `IndexModel` describing the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *
     * - Returns: a `Document` containing the server's response to the command.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    @discardableResult
    public func dropIndex(_ model: IndexModel,
                          options: DropIndexOptions? = nil,
                          session: ClientSession? = nil) throws -> Document {
        return try _dropIndexes(index: model.keys, options: options, session: session)
    }

    /**
     * Drops all indexes in the collection.
     *
     * - Parameters:
     *   - options: Optional `DropIndexOptions` to use for the command
     *
     * - Returns: a `Document` containing the server's response to the command.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    @discardableResult
    public func dropIndexes(options: DropIndexOptions? = nil, session: ClientSession? = nil) throws -> Document {
        return try _dropIndexes(index: "*", options: options, session: session)
    }

    /// Internal helper to drop an index. `index` must either be an index specification document or a
    /// string index name.
    private func _dropIndexes(index: BSONValue,
                              options: DropIndexOptions?,
                              session: ClientSession?) throws -> Document {
        let operation = DropIndexesOperation(collection: self, index: index, options: options, session: session)
        return try operation.execute()
    }

    /**
     * Retrieves a list of the indexes currently on this collection.
     *
     * - Returns: A `MongoCursor` over the index names.
     *
     * - Throws: `UserError.logicError` if the provided session is inactive.
     */
    public func listIndexes(session: ClientSession? = nil) throws -> MongoCursor<Document> {
        let opts = try encodeOptions(options: Document(), session: session)

        guard let cursor = mongoc_collection_find_indexes_with_opts(self._collection, opts?._bson) else {
            fatalError("Couldn't get cursor from the server")
        }

        return try MongoCursor(from: cursor, client: self._client, decoder: self.decoder, session: session)
    }
}
