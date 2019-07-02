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
public struct MongoCollection<T: Codable> {
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
        self.readConcern = options?.readConcern ?? database.readConcern ?? database._client.readConcern
        self.writeConcern = options?.writeConcern ?? database.writeConcern ?? database._client.writeConcern
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

        self.readConcern?.withMongocReadConcern { rcPtr in
            mongoc_collection_set_read_concern(collection, rcPtr)
        }
        self.writeConcern?.withMongocWriteConcern { wcPtr in
            mongoc_collection_set_write_concern(collection, wcPtr)
        }
        if self.readPreference != self._client.readPreference {
            mongoc_collection_set_read_prefs(collection, self.readPreference._readPreference)
        }

        return try body(collection)
    }
}
