import CLibMongoC
import NIO

/// A struct representing an index on a `MongoCollection`.
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
        self.keys.map { k, v in "\(k)_\(v.bsonValue)" }.joined(separator: "_")
    }

    // Encode own data as well as nested options data
    private enum CodingKeys: String, CodingKey {
        case key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.keys, forKey: .key)
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
    public var bits: Int?

    /// Optionally specifies the number of units within which to group the location values in a geo haystack index.
    public var bucketSize: Int?

    /// Optionally specifies a collation to use for the index in MongoDB 3.4 and higher. If not specified, no collation
    /// is sent and the default collation of the collection server-side is used.
    public var collation: Document?

    /// Optionally specifies the default language for text indexes. Is 'english' if none is provided.
    public var defaultLanguage: String?

    /// Optionally specifies the length in time, in seconds, for documents to remain in a collection.
    public var expireAfterSeconds: Int?

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
    public var sphereIndexVersion: Int?

    /// Optionally used only in MongoDB 3.0.0 and higher. Allows users to configure the storage engine on a per-index
    /// basis when creating an index.
    public var storageEngine: Document?

    /// Optionally provides the text index version number. MongoDB 2.4 can only support version 1. MongoDB 2.6 and
    /// higher may support version 1 or 2.
    public var textIndexVersion: Int?

    /// Optionally forces the index to be unique.
    public var unique: Bool?

    /// Optionally specifies the index version number, either 0 or 1.
    public var version: Int?

    /// Optionally specifies fields in the index and their corresponding weight values.
    public var weights: Document?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(
        background: Bool? = nil,
        bits: Int? = nil,
        bucketSize: Int? = nil,
        collation: Document? = nil,
        defaultLanguage: String? = nil,
        expireAfterSeconds: Int? = nil,
        languageOverride: String? = nil,
        max: Double? = nil,
        min: Double? = nil,
        name: String? = nil,
        partialFilterExpression: Document? = nil,
        sparse: Bool? = nil,
        sphereIndexVersion: Int? = nil,
        storageEngine: Document? = nil,
        textIndexVersion: Int? = nil,
        unique: Bool? = nil,
        version: Int? = nil,
        weights: Document? = nil
    ) {
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

/// An extension of `MongoCollection` encapsulating index management capabilities.
extension MongoCollection {
    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - keys: a `Document` specifing the keys for the index
     *   - indexOptions: Optional `IndexOptions` to use for the index
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<String>`. On success, contains the name of the created index.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `WriteError` if an error occurs while performing the write.
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the index specification or options.
     */
    public func createIndex(
        _ keys: Document,
        indexOptions: IndexOptions? = nil,
        options: CreateIndexOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<String> {
        let model = IndexModel(keys: keys, options: indexOptions)
        return self.createIndex(model, options: options, session: session)
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - model: An `IndexModel` representing the keys and options for the index
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<String>`. On success, contains the name of the created index.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `WriteError` if an error occurs while performing the write.
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the index specification or options.
     */
    public func createIndex(
        _ model: IndexModel,
        options: CreateIndexOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<String> {
        self.createIndexes([model], options: options, session: session).flatMapThrowing { result in
            guard result.count == 1 else {
                throw InternalError(message: "expected 1 result, got \(result.count)")
            }
            return result[0]
        }
    }

    /**
     * Creates multiple indexes in the collection.
     *
     * - Parameters:
     *   - models: An `[IndexModel]` specifying the indexes to create
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[String]>`. On success, contains the names of the created indexes.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `WriteError` if an error occurs while performing the write.
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `InvalidArgumentError` if `models` is empty.
     *    - `InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the index specifications or options.
     */
    public func createIndexes(
        _ models: [IndexModel],
        options: CreateIndexOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[String]> {
        guard !models.isEmpty else {
            return self._client.operationExecutor
                .makeFailedFuture(InvalidArgumentError(message: "models cannot be empty"))
        }
        let operation = CreateIndexesOperation(collection: self, models: models, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Drops a single index from the collection by the index name.
     *
     * - Parameters:
     *   - name: The name of the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when the drop is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `WriteError` if an error occurs while performing the command.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndex(
        _ name: String,
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<Void> {
        guard name != "*" else {
            return self._client.operationExecutor.makeFailedFuture(InvalidArgumentError(
                message: "Invalid index name '*'; use dropIndexes() to drop all indexes"
            ))
        }
        return self._dropIndexes(index: .string(name), options: options, session: session)
    }

    /**
     * Attempts to drop a single index from the collection given the keys describing it.
     *
     * - Parameters:
     *   - keys: a `Document` containing the keys for the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when the drop is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `WriteError` if an error occurs while performing the command.
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndex(
        _ keys: Document,
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<Void> {
        self._dropIndexes(index: .document(keys), options: options, session: session)
    }

    /**
     * Attempts to drop a single index from the collection given an `IndexModel` describing it.
     *
     * - Parameters:
     *   - model: An `IndexModel` describing the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when the drop is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `WriteError` if an error occurs while performing the command.
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndex(
        _ model: IndexModel,
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<Void> {
        self._dropIndexes(index: .document(model.keys), options: options, session: session)
    }

    /**
     * Drops all indexes in the collection.
     *
     * - Parameters:
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when the drop is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `WriteError` if an error occurs while performing the command.
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndexes(
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<Void> {
        self._dropIndexes(index: "*", options: options, session: session)
    }

    /// Internal helper to drop an index. `index` must either be an index specification document or a
    /// string index name.
    private func _dropIndexes(
        index: BSON,
        options: DropIndexOptions?,
        session: ClientSession?
    ) -> EventLoopFuture<Void> {
        let operation = DropIndexesOperation(collection: self, index: index, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Retrieves a list of the indexes currently on this collection.
     *
     * - Parameters:
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCursor<IndexModel>>`. On success, contains a cursor over the indexes.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     */
    public func listIndexes(session: ClientSession? = nil) -> EventLoopFuture<MongoCursor<IndexModel>> {
        let operation = ListIndexesOperation(collection: self, nameOnly: false)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
            .flatMapThrowing { result in
                guard case let .models(result) = result else {
                    throw InternalError(message: "Invalid result")
                }
                return result
            }
    }

    /**
     * Retrieves a list of names of the indexes currently on this collection.
     *
     * - Parameters:
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[String]>` containing the index names.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `LogicError` if the provided session is inactive.
     *    - `LogicError` if this collection's parent client has already been closed.
     */
    public func listIndexNames(session: ClientSession? = nil) -> EventLoopFuture<[String]> {
        let operation = ListIndexesOperation(collection: self, nameOnly: true)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
            .flatMapThrowing { result in
                guard case let .names(names) = result else {
                    throw InternalError(message: "Invalid result")
                }
                return names
            }
    }
}
