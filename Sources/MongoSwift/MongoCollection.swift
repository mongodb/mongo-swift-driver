import libmongoc

/// A MongoDB collection.
public class MongoCollection<T: Codable> {
    internal var _collection: OpaquePointer?
    internal var _client: MongoClient?

    /// A `Codable` type associated with this `MongoCollection` instance. 
    /// This allows `CollectionType` values to be directly inserted into and 
    /// retrieved from the collection, by encoding/decoding them using the 
    /// `BsonEncoder` and `BsonDecoder`. 
    /// This type association only exists in the context of this particular 
    /// `MongoCollection` instance. It is the responsibility of the user to 
    /// ensure that any data already stored in the collection was encoded 
    /// from this same type.
    public typealias CollectionType = T

    /// The name of this collection.
    public var name: String {
        return String(cString: mongoc_collection_get_name(self._collection))
    }

    /// The `ReadConcern` set on this collection, or `nil` if one is not set.
    public var readConcern: ReadConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let readConcern = mongoc_collection_get_read_concern(self._collection)
        let rcObj = ReadConcern(from: readConcern)
        if rcObj.isDefault { return nil }
        return rcObj
    }

    /// The `ReadPreference` set on this collection
    public var readPreference: ReadPreference? {
        return ReadPreference(from: mongoc_collection_get_read_prefs(self._collection))
    }

    /// The `WriteConcern` set on this collection, or nil if one is not set.
    public var writeConcern: WriteConcern? {
        // per libmongoc docs, we don't need to handle freeing this ourselves
        let writeConcern = mongoc_collection_get_write_concern(self._collection)
        let wcObj = WriteConcern(writeConcern)
        if wcObj.isDefault { return nil }
        return wcObj
    }

    /// Initializes a new `MongoCollection` instance, not meant to be instantiated directly
    internal init(fromCollection: OpaquePointer, withClient: MongoClient) {
        self._collection = fromCollection
        self._client = withClient
    }

    /// Deinitializes a `MongoCollection`, cleaning up the internal `mongoc_collection_t`
    deinit {
        self._client = nil
        guard let collection = self._collection else {
            return
        }
        mongoc_collection_destroy(collection)
        self._collection = nil
    }

    /// Drops this collection from its parent database.
    public func drop() throws {
        var error = bson_error_t()
        if !mongoc_collection_drop(self._collection, &error) {
            throw MongoError.commandError(message: toErrorString(error))
        }
    }
}
