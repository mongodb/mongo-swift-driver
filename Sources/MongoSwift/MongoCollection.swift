import mongoc

/// Options to use when dropping a collection.
public struct DropCollectionOptions: Codable {
    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(writeConcern: WriteConcern? = nil) {
        self.writeConcern = writeConcern
    }
}

/// A MongoDB collection.
public class MongoCollection<T: Codable> {
    /// The client which this collection was derived from.
    internal let _client: MongoClient

    /// The namespace for this collection.
    private let namespace: MongoNamespace

    /// Encoder used by this collection for BSON conversions. (e.g. converting `CollectionType`s, indexes, and options
    /// to documents).
    public let encoder: BSONEncoder

    /// Decoder used by this collection for BSON conversions (e.g. converting documents to `CollectionType`s).
    public let decoder: BSONDecoder

    /**
     * A `Codable` type associated with this `MongoCollection` instance.
     * This allows `CollectionType` values to be directly inserted into and retrieved from the collection, by
     * encoding/decoding them using the `BSONEncoder` and `BSONDecoder`. The strategies to be used by the encoder and
     * decoder for certain types can be configured by setting the coding strategies on the options used to create this
     * collection instance. The default strategies are inherited from those set on the database this collection derived
     * from.
     *
     * This type association only exists in the context of this particular `MongoCollection` instance. It is the
     * responsibility of the user to ensure that any data already stored in the collection was encoded
     * from this same type and according to the coding strategies set on this instance.
     */
    public typealias CollectionType = T

    /// The name of this collection.
    public var name: String {
        // safe to force unwrap as collection name is always present for a collection namespace.
        return self.namespace.collection! // swiftlint:disable:this force_unwrapping
    }

    /// The `ReadConcern` set on this collection, or `nil` if one is not set.
    public let readConcern: ReadConcern?

    /// The `ReadPreference` set on this collection.
    public let readPreference: ReadPreference

    /// The `WriteConcern` set on this collection, or nil if one is not set.
    public let writeConcern: WriteConcern?

    /// Initializes a new `MongoCollection` instance corresponding to a collection with name `name` in database with
    /// the provided options.
    internal init(name: String, database: MongoDatabase, options: CollectionOptions?) {
        self.namespace = MongoNamespace(db: database.name, collection: name)
        self._client = database._client

        // for both read concern and write concern, we look for a read concern in the following order:
        // 1. options provided for this collection
        // 2. value for this `MongoCollection`'s parent `MongoDatabase`
        // if we found a non-nil value, we check if it's the empty/server default or not, and store it if not.
        if let rc = options?.readConcern ?? database.readConcern, !rc.isDefault {
            self.readConcern = rc
        } else {
            self.readConcern = nil
        }

        if let wc = options?.writeConcern ?? database.writeConcern, !wc.isDefault {
            self.writeConcern = wc
        } else {
            self.writeConcern = nil
        }

        self.readPreference = options?.readPreference ?? database.readPreference
        self.encoder = BSONEncoder(copies: database.encoder, options: options)
        self.decoder = BSONDecoder(copies: database.decoder, options: options)
    }

    /**
     *   Drops this collection from its parent database.
     * - Parameters:
     *   - options: An optional `DropCollectionOptions` to use when executing this command
     *   - session: An optional `ClientSession` to use when executing this command
     *
     * - Throws:
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     */
    public func drop(options: DropCollectionOptions? = nil, session: ClientSession? = nil) throws {
        let operation = DropCollectionOperation(collection: self, options: options)
        return try self._client.executeOperation(operation, session: session)
    }

    /// Uses the provided `Connection` to get a pointer to a `mongoc_collection_t` corresponding to this
    /// `MongoCollection`, and uses it to execute the given closure. The `mongoc_collection_t` is only valid for the
    /// body of the closure. The caller is *not responsible* for cleaning up the `mongoc_collection_t`.
    internal func withMongocCollection<T>(from connection: Connection,
                                          body: (OpaquePointer) throws -> T) rethrows -> T {
        guard let collection = mongoc_client_get_collection(connection.clientHandle,
                                                            self.namespace.db,
                                                            self.namespace.collection) else {
            fatalError("Couldn't get collection '\(self.namespace)'")
        }
        defer { mongoc_collection_destroy(collection) }

        // `collection` will automatically inherit read concern, write concern, and read preference from the parent
        // client. If this `MongoCollection`'s value for any of those settings is different than the parent, we need to
        // explicitly set it here.

        if self.readConcern != self._client.readConcern {
            // a nil value for self.readConcern corresponds to the empty read concern.
            (self.readConcern ?? ReadConcern()).withMongocReadConcern { rcPtr in
                mongoc_collection_set_read_concern(collection, rcPtr)
            }
        }

        if self.writeConcern != self._client.writeConcern {
            // a nil value for self.writeConcern corresponds to the empty write concern.
            (self.writeConcern ?? WriteConcern()).withMongocWriteConcern { wcPtr in
                mongoc_collection_set_write_concern(collection, wcPtr)
            }
        }

        if self.readPreference != self._client.readPreference {
            // there is no concept of an empty read preference so we will always have a value here.
            mongoc_collection_set_read_prefs(collection, self.readPreference._readPreference)
        }

        return try body(collection)
    }

    /**
     * Starts a `ChangeStream` on a collection. By default, the type `CollectionType` is associated with the
     * `fullDocument` field in `ChangeStreamDocument` emitted by the returned `ChangeStream`.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the `ChangeStream`.
     *   - session: An optional `ClientSession` to use with this change stream.
     * - Returns: A `ChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `ServerError.commandError` if the pipeline passed is invalid.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     */
    public func watch(_ pipeline: [Document] = [],
                      options: ChangeStreamOptions? =  nil,
                      session: ClientSession? = nil) throws ->
                      ChangeStream<ChangeStreamDocument<CollectionType>> {
        return try self.watch(pipeline, options: options, session: session, withFullDocumentType: CollectionType.self)
    }

    /**
     * Starts a `ChangeStream` on a collection. Associates the specified `Codable` type `T` with the `fullDocument`
     * field in the `ChangeStreamDocument` emitted by the returned `ChangeStream`.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the `ChangeStream`.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the change events emitted from the change stream will be decoded to.
     * - Returns: A `ChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `ServerError.commandError` if the pipeline passed is invalid.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     *   - `DecodingError` if an error occurs while decoding user-defined `withFullDocumentType` `Codable` type.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     */
    public func watch<T: Codable>(_ pipeline: [Document] = [],
                                  options: ChangeStreamOptions? = nil,
                                  session: ClientSession? = nil,
                                  withFullDocumentType type: T.Type) throws ->
                                  ChangeStream<ChangeStreamDocument<T>> {
        let pipeline: Document = ["pipeline": pipeline]
        let connection = try self._client.connectionPool.checkOut()
        return try self.withMongocCollection(from: connection) { collPtr in
            let opts = try encodeOptions(options: options, session: session)
            let changeStreamPtr: OpaquePointer = mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            return try ChangeStream<ChangeStreamDocument<T>>(stealing: changeStreamPtr,
                                                             client: self._client,
                                                             connection: connection,
                                                             session: session,
                                                             decoder: self.decoder)
        }
    }

    /**
     * Starts a `ChangeStream` on a collection. Associates the specified `Codable` type `T` with the returned
     * `ChangeStream`.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
                     - SeeAlso: https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - options: An optional `ChangeStreamOptions` to use when constructing the `ChangeStream`.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withReturnType: The type that the entire change stream response will be decoded to.
     * - Returns: A `ChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `ServerError.commandError` if the pipeline passed is invalid.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     *   - `DecodingError` if an error occurs while decoding user-defined `withReturnType` `Codable` type.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     */
    public func watch<T: Codable>(_ pipeline: [Document] = [],
                                  options: ChangeStreamOptions? = nil,
                                  session: ClientSession? = nil,
                                  withReturnType type: T.Type) throws ->
                                  ChangeStream<T> {
        let pipeline: Document = ["pipeline": pipeline]
        let connection = try self._client.connectionPool.checkOut()
        return try self.withMongocCollection(from: connection) { collPtr in
            let opts = try encodeOptions(options: options, session: session)
            let changeStreamPtr: OpaquePointer = mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            return try ChangeStream<T>(stealing: changeStreamPtr,
                                       client: self._client,
                                       connection: connection,
                                       session: session,
                                       decoder: self.decoder)
        }
    }
}
