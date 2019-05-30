import mongoc

/// A MongoDB collection.
public class MongoCollection<T: Codable> {
    internal var _collection: OpaquePointer?
    internal var _client: MongoClient

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
        return String(cString: mongoc_collection_get_name(self._collection))
    }

    /// The `ReadConcern` set on this collection, or `nil` if one is not set.
    public var readConcern: ReadConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let rc = ReadConcern(from: mongoc_collection_get_read_concern(self._collection))
        return rc.isDefault ? nil : rc
    }

    /// The `ReadPreference` set on this collection.
    public var readPreference: ReadPreference {
        return ReadPreference(from: mongoc_collection_get_read_prefs(self._collection))
    }

    /// The `WriteConcern` set on this collection, or nil if one is not set.
    public var writeConcern: WriteConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let wc = WriteConcern(from: mongoc_collection_get_write_concern(self._collection))
        return wc.isDefault ? nil : wc
    }

    /// Initializes a new `MongoCollection` instance corresponding to a collection with name `name` in database with
    /// the provided options.
    internal init(name: String, database: MongoDatabase, options: CollectionOptions?) {
        guard let collection = mongoc_database_get_collection(database._database, name) else {
            fatalError("Could not get collection '\(name)'")
        }

        if let rc = options?.readConcern {
            mongoc_collection_set_read_concern(collection, rc._readConcern)
        }

        if let rp = options?.readPreference {
            mongoc_collection_set_read_prefs(collection, rp._readPreference)
        }

        if let wc = options?.writeConcern {
            mongoc_collection_set_write_concern(collection, wc._writeConcern)
        }

        self._collection = collection
        self._client = database._client
        self.encoder = BSONEncoder(copies: database.encoder, options: options)
        self.decoder = BSONDecoder(copies: database.decoder, options: options)
    }

    /// Cleans up internal state.
    deinit {
        guard let collection = self._collection else {
            return
        }
        mongoc_collection_destroy(collection)
        self._collection = nil
    }

    /// Drops this collection from its parent database.
    /// - Throws:
    ///   - `ServerError.commandError` if an error occurs that prevents the command from executing.
    public func drop(session: ClientSession? = nil) throws {
        let operation = DropCollectionOperation(collection: self, session: session)
        try operation.execute()
    }
}
