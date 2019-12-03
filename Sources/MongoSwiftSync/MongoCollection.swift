import MongoSwift

/// A MongoDB collection.
public struct MongoCollection<T: Codable> {
    /// The client which this collection was derived from.
    internal let _client: MongoClient

    /// Encoder used by this collection for BSON conversions. (e.g. converting `CollectionType`s, indexes, and options
    /// to documents).
    public var encoder: BSONEncoder { fatalError("unimplemented") }

    /// Decoder used by this collection for BSON conversions (e.g. converting documents to `CollectionType`s).
    public var decoder: BSONDecoder { fatalError("unimplemented") }

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
    public var name: String { fatalError("unimplemented") }

    /// The `ReadConcern` set on this collection, or `nil` if one is not set.
    public var readConcern: ReadConcern? { fatalError("unimplemented") }

    /// The `ReadPreference` set on this collection.
    public var readPreference: ReadPreference { fatalError("unimplemented") }

    /// The `WriteConcern` set on this collection, or nil if one is not set.
    public var writeConcern: WriteConcern? { fatalError("unimplemented") }

    /// Initializes a new `MongoCollection` instance corresponding to a collection with name `name` in database with
    /// the provided options.
    internal init(name: String, database: MongoDatabase, options: CollectionOptions?) {
        fatalError("unimplemented")
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
        fatalError("unimplemented")
    }
}
