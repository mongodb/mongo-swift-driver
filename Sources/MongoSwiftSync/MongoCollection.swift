import MongoSwift

/// A MongoDB collection.
public struct MongoCollection<T: Codable> {
    /// Encoder used by this collection for BSON conversions. (e.g. converting `CollectionType`s, indexes, and options
    /// to documents).
    public var encoder: BSONEncoder { self.asyncColl.encoder }

    /// Decoder used by this collection for BSON conversions (e.g. converting documents to `CollectionType`s).
    public var decoder: BSONDecoder { self.asyncColl.decoder }

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

    /// The namespace for this collection.
    public var namespace: MongoNamespace { self.asyncColl.namespace }

    /// The name of this collection.
    public var name: String { self.asyncColl.name }

    /// The `ReadConcern` set on this collection, or `nil` if one is not set.
    public var readConcern: ReadConcern? { self.asyncColl.readConcern }

    /// The `ReadPreference` set on this collection.
    public var readPreference: ReadPreference { self.asyncColl.readPreference }

    /// The `WriteConcern` set on this collection, or nil if one is not set.
    public var writeConcern: WriteConcern? { self.asyncColl.writeConcern }

    /// The underlying asynchronous collection.
    internal let asyncColl: MongoSwift.MongoCollection<T>

    /// The client this collection was derived from. We store this to ensure it remains open for as long as this object
    /// is in scope.
    internal let client: MongoClient

    /// Initializes a new `MongoCollection` instance wrapping the provided async collection.
    internal init(client: MongoClient, asyncCollection: MongoSwift.MongoCollection<T>) {
        self.client = client
        self.asyncColl = asyncCollection
    }

    /**
     *   Drops this collection from its parent database.
     * - Parameters:
     *   - options: An optional `DropCollectionOptions` to use when executing this command
     *   - session: An optional `ClientSession` to use when executing this command
     *
     * - Throws:
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     */
    public func drop(options: DropCollectionOptions? = nil, session: ClientSession? = nil) throws {
        try self.asyncColl.drop(options: options, session: session?.asyncSession).wait()
    }

    /**
     * Renames this collection with the specified options.
     *
     * - Parameters:
     *   - to: A `String`, the new name for the collection
     *   - dropTarget: A `Bool`, indicating whether the target collection should be dropped prior to renaming it.
     *                 The default value is false.
     *   - options: Optional `RenamedCollectionOptions` to use for the collection
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCollection>` evaluating to a copy of the target `MongoCollection` with the new name.
     *
     *    If the future evaluates to an error, it is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this databases's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func renamed(
        _ to: String,
        dropTarget: Bool = false,
        options: RenamedCollectionOptions? = nil,
        session: ClientSession? = nil
    ) throws -> MongoCollection {
        let newAsyncColl = try self.asyncColl.renamed(
            to,
            dropTarget: dropTarget,
            options: options,
            session: session?.asyncSession
        )
        .wait()
        return MongoCollection(client: self.client, asyncCollection: newAsyncColl)
    }
}
