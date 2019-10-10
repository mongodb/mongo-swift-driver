import mongoc

/// A struct representing an index on a `MongoCollection` or a `SyncMongoCollection`.
public struct IndexModel: Codable {
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
        return self.keys.map { k, v in "\(k)_\(v.bsonValue)" }.joined(separator: "_")
    }

    // Encode own data as well as nested options data
    private enum CodingKeys: String, CodingKey {
        case key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keys, forKey: .key)
        try self.options?.encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.keys = try values.decode(Document.self, forKey: .key)
        self.options = try IndexOptions(from: decoder)
    }
}

/// Options to use when creating an index for a collection.
public struct IndexOptions: Codable {
    /// Optionally tells the server to build the index in the background and not block other tasks.
    public var background: Bool?

    /// Optionally specifies the precision of the stored geo hash in the 2d index, from 1 to 32.
    public var bits: Int32?

    /// Optionally specifies the number of units within which to group the location values in a geo haystack index.
    public var bucketSize: Int32?

    /// Optionally specifies a collation to use for the index in MongoDB 3.4 and higher. If not specified, no collation
    /// is sent and the default collation of the collection server-side is used.
    public var collation: Document?

    /// Optionally specifies the default language for text indexes. Is 'english' if none is provided.
    public var defaultLanguage: String?

    /// Optionally specifies the length in time, in seconds, for documents to remain in a collection.
    public var expireAfterSeconds: Int32?

    /// Optionally specifies the field in the document to override the language.
    public var languageOverride: String?

    /// Optionally sets the maximum boundary for latitude and longitude in the 2d index.
    public var max: Double?

    /// Optionally sets the minimum boundary for latitude and longitude in the index in a 2d index.
    public var min: Double?

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

    /// Optionally specifies a filter for use in a partial index. Only documents that match the filter expression are
    /// included in the index. New in MongoDB 3.2.
    public var partialFilterExpression: Document?

    /// Optionally tells the index to only reference documents with the specified field in the index.
    public var sparse: Bool?

    /// Optionally specifies the 2dsphere index version number. MongoDB 2.4 can only support version 1. MongoDB 2.6 and
    /// higher may support version 1 or 2.
    public var sphereIndexVersion: Int32?

    /// Optionally used only in MongoDB 3.0.0 and higher. Allows users to configure the storage engine on a per-index
    /// basis when creating an index.
    public var storageEngine: Document?

    /// Optionally provides the text index version number. MongoDB 2.4 can only support version 1. MongoDB 2.6 and
    /// higher may support version 1 or 2.
    public var textIndexVersion: Int32?

    /// Optionally forces the index to be unique.
    public var unique: Bool?

    /// Optionally specifies the index version number, either 0 or 1.
    public var version: Int32?

    /// Optionally specifies fields in the index and their corresponding weight values.
    public var weights: Document?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(background: Bool? = nil,
                bits: Int32? = nil,
                bucketSize: Int32? = nil,
                collation: Document? = nil,
                defaultLanguage: String? = nil,
                expireAfterSeconds: Int32? = nil,
                languageOverride: String? = nil,
                max: Double? = nil,
                min: Double? = nil,
                name: String? = nil,
                partialFilterExpression: Document? = nil,
                sparse: Bool? = nil,
                sphereIndexVersion: Int32? = nil,
                storageEngine: Document? = nil,
                textIndexVersion: Int32? = nil,
                unique: Bool? = nil,
                version: Int32? = nil,
                weights: Document? = nil) {
        self.background = background
        self.bits = bits
        self.bucketSize = bucketSize
        self.collation = collation
        self.defaultLanguage = defaultLanguage
        self.expireAfterSeconds = expireAfterSeconds
        self.languageOverride = languageOverride
        self.max = max
        self.min = min
        self.name = name
        self.partialFilterExpression = partialFilterExpression
        self.sparse = sparse
        self.sphereIndexVersion = sphereIndexVersion
        self.storageEngine = storageEngine
        self.textIndexVersion = textIndexVersion
        self.unique = unique
        self.version = version
        self.weights = weights
    }

    private enum CodingKeys: String, CodingKey {
        case background, expireAfterSeconds, name, sparse, storageEngine, unique, version = "v",
            defaultLanguage = "default_language", languageOverride = "language_override", textIndexVersion, weights,
            sphereIndexVersion = "2dsphereIndexVersion", bits, max, min, bucketSize, partialFilterExpression,
            collation
    }
}

/// An extension of `SyncMongoCollection` encapsulating index management capabilities.
extension SyncMongoCollection {
    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - keys: a `Document` specifing the keys for the index
     *   - indexOptions: Optional `IndexOptions` to use for the index
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `SyncClientSession` to use when executing this command
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
                            indexOptions: IndexOptions? = nil,
                            options: CreateIndexOptions? = nil,
                            session: SyncClientSession? = nil) throws -> String {
        return try createIndexes([IndexModel(keys: keys, options: indexOptions)],
                                 options: options,
                                 session: session)[0]
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - model: An `IndexModel` representing the keys and options for the index
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `SyncClientSession` to use when executing this command
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
                            session: SyncClientSession? = nil) throws -> String {
        return try createIndexes([model], options: options, session: session)[0]
    }

    /**
     * Creates multiple indexes in the collection.
     *
     * - Parameters:
     *   - models: An `[IndexModel]` specifying the indexes to create
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `SyncClientSession` to use when executing this command
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
                              session: SyncClientSession? = nil) throws -> [String] {
        let operation = CreateIndexesOperation(collection: self, models: models, options: options)
        return try self._client.executeOperation(operation, session: session)
    }

    /**
     * Drops a single index from the collection by the index name.
     *
     * - Parameters:
     *   - name: The name of the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `SyncClientSession` to use when executing this command
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
                          session: SyncClientSession? = nil) throws -> Document {
        guard name != "*" else {
            throw UserError.invalidArgumentError(message:
                "Invalid index name '*'; use dropIndexes() to drop all indexes")
        }
        return try _dropIndexes(index: .string(name), options: options, session: session)
    }

    /**
     * Attempts to drop a single index from the collection given the keys describing it.
     *
     * - Parameters:
     *   - keys: a `Document` containing the keys for the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `SyncClientSession` to use when executing this command
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
                          options: DropIndexOptions? = nil,
                          session: SyncClientSession? = nil) throws -> Document {
        return try _dropIndexes(index: .document(keys), options: options, session: session)
    }

    /**
     * Attempts to drop a single index from the collection given an `IndexModel` describing it.
     *
     * - Parameters:
     *   - model: An `IndexModel` describing the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `SyncClientSession` to use when executing this command
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
                          session: SyncClientSession? = nil) throws -> Document {
        return try _dropIndexes(index: .document(model.keys), options: options, session: session)
    }

    /**
     * Drops all indexes in the collection.
     *
     * - Parameters:
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `SyncClientSession` to use when executing this command
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
    public func dropIndexes(options: DropIndexOptions? = nil, session: SyncClientSession? = nil) throws -> Document {
        return try _dropIndexes(index: "*", options: options, session: session)
    }

    /// Internal helper to drop an index. `index` must either be an index specification document or a
    /// string index name.
    private func _dropIndexes(index: BSON,
                              options: DropIndexOptions?,
                              session: SyncClientSession?) throws -> Document {
        let operation = DropIndexesOperation(collection: self, index: index, options: options)
        return try self._client.executeOperation(operation, session: session)
    }

    /**
     * Retrieves a list of the indexes currently on this collection.
     *
     * - Parameters:
     *   - session: Optional `SyncClientSession` to use when executing this command
     *
     * - Returns: A `SyncMongoCursor` over the `IndexModel`s.
     *
     * - Throws: `UserError.logicError` if the provided session is inactive.
     */
    public func listIndexes(session: SyncClientSession? = nil) throws -> SyncMongoCursor<IndexModel> {
        let operation = ListIndexesOperation(collection: self)
        return try self._client.executeOperation(operation, session: session)
    }

    /**
     * Retrieves a list of names of the indexes currently on this collection.
     *
     * - Parameters:
     *   - session: Optional `SyncClientSession` to use when executing this command
     *
     * - Returns: A `SyncMongoCursor` over the index names.
     *
     * - Throws: `UserError.logicError` if the provided session is inactive.
     */
    public func listIndexNames(session: SyncClientSession? = nil) throws -> [String] {
        let operation = ListIndexesOperation(collection: self)
        let models = try self._client.executeOperation(operation, session: session)
        return try models.map { model in
            guard let name = model.options?.name else {
                throw RuntimeError.internalError(message: "Server response missing a 'name' field")
            }
            return name
        }
    }
}
