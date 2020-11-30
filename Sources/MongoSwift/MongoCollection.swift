import CLibMongoC
import NIO

/// Options to use when dropping a collection.
public struct DropCollectionOptions: Codable {
    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    /// Initializer allowing any/all parameters to be omitted.
    public init(writeConcern: WriteConcern? = nil) {
        self.writeConcern = writeConcern
    }
}

// sourcery: skipSyncExport
/// A MongoDB collection.
public struct MongoCollection<T: Codable> {
    /// The client which this collection was derived from.
    internal let _client: MongoClient

    /// The namespace for this collection.
    public let namespace: MongoNamespace

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
        self.namespace.collection! // swiftlint:disable:this force_unwrapping
    }

    /// The `ReadConcern` set on this collection, or `nil` if one is not set.
    public let readConcern: ReadConcern?

    /// The `ReadPreference` set on this collection.
    public let readPreference: ReadPreference

    /// The `WriteConcern` set on this collection, or nil if one is not set.
    public let writeConcern: WriteConcern?

    /// Initializes a new `MongoCollection` instance corresponding to a collection with name `name` in database with
    /// the provided options.
    internal init(name: String, database: MongoDatabase, options: MongoCollectionOptions?) {
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

    internal init(copying other: MongoCollection<T>, name: String) {
        self.namespace = MongoNamespace(db: other.namespace.db, collection: name)
        self._client = other._client
        self.readConcern = other.readConcern
        self.writeConcern = other.writeConcern
        self.readPreference = other.readPreference
        self.encoder = other.encoder
        self.decoder = other.decoder
    }

    /**
     *   Drops this collection from its parent database.
     * - Parameters:
     *   - options: An optional `DropCollectionOptions` to use when executing this command
     *   - session: An optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when the drop is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     */
    public func drop(options: DropCollectionOptions? = nil, session: ClientSession? = nil) -> EventLoopFuture<Void> {
        let operation = DropCollectionOperation(collection: self, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Renames this collection on the server. This method will return a handle to the renamed collection. The handle
     * which this method is invoked on will continue to refer to the old collection, which will then be empty.
     * The server will throw an error if the new name matches an existing collection unless the `dropTarget` option
     * is set to true.
     *
     * Note: This method is not supported on sharded collections.
     *
     * - Parameters:
     *   - to: A `String`, the new name for the collection
     *   - options: Optional `RenameCollectionOptions` to use for the collection
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCollection>` evaluating to a copy of the target `MongoCollection` with the new name.
     *
     *    If the future evaluates to an error, it is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func renamed(
        to newName: String,
        options: RenameCollectionOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<MongoCollection> {
        let operation = RenameCollectionOperation(
            collection: self,
            newName: newName,
            options: options
        )
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /// Uses the provided `Connection` to get a pointer to a `mongoc_collection_t` corresponding to this
    /// `MongoCollection`, and uses it to execute the given closure. The `mongoc_collection_t` is only valid for the
    /// body of the closure. The caller is *not responsible* for cleaning up the `mongoc_collection_t`.
    internal func withMongocCollection<T>(
        from connection: Connection,
        body: (OpaquePointer) throws -> T
    ) rethrows -> T {
        try connection.withMongocConnection { connPtr in
            guard let collection = mongoc_client_get_collection(
                connPtr,
                self.namespace.db,
                self.namespace.collection
            ) else {
                fatalError("Couldn't get collection '\(self.namespace)'")
            }
            defer { mongoc_collection_destroy(collection) }

            // `collection` will automatically inherit read concern, write concern, and read preference from the parent
            // client. If this `MongoCollection`'s value for any of those settings is different than the parent, we
            //  need to explicitly set it here.

            if self.readConcern != self._client.readConcern {
                // a nil value for self.readConcern corresponds to the empty read concern.
                (self.readConcern ?? .serverDefault).withMongocReadConcern { rcPtr in
                    mongoc_collection_set_read_concern(collection, rcPtr)
                }
            }

            if self.writeConcern != self._client.writeConcern {
                // a nil value for self.writeConcern corresponds to the empty write concern.
                (self.writeConcern ?? .serverDefault).withMongocWriteConcern { wcPtr in
                    mongoc_collection_set_write_concern(collection, wcPtr)
                }
            }

            if self.readPreference != self._client.readPreference {
                // there is no concept of an empty read preference so we will always have a value here.
                self.readPreference.withMongocReadPreference { rpPtr in
                    mongoc_collection_set_read_prefs(collection, rpPtr)
                }
            }

            return try body(collection)
        }
    }

    /// Internal method to check the `ReadConcern` that is set on `mongoc_collection_t`s via `withMongocCollection`.
    /// **This method may block and is for testing purposes only**.
    internal func getMongocReadConcern() throws -> ReadConcern? {
        try self._client.connectionPool.withConnection { conn in
            self.withMongocCollection(from: conn) { collPtr in
                ReadConcern(copying: mongoc_collection_get_read_concern(collPtr))
            }
        }
    }

    /// Internal method to check the `ReadPreference` that is set on `mongoc_collection_t`s via `withMongocCollection`.
    /// **This method may block and is for testing purposes only**.
    internal func getMongocReadPreference() throws -> ReadPreference {
        try self._client.connectionPool.withConnection { conn in
            self.withMongocCollection(from: conn) { collPtr in
                ReadPreference(copying: mongoc_collection_get_read_prefs(collPtr))
            }
        }
    }

    /// Internal method to check the `WriteConcern` that is set on `mongoc_collection_t`s via `withMongocCollection`.
    /// **This method may block and is for testing purposes only**.
    internal func getMongocWriteConcern() throws -> WriteConcern? {
        try self._client.connectionPool.withConnection { conn in
            self.withMongocCollection(from: conn) { collPtr in
                WriteConcern(copying: mongoc_collection_get_write_concern(collPtr))
            }
        }
    }
}
