import CLibMongoC
import Foundation

/// Options to use when executing an `aggregate` command on a `MongoCollection`.
public struct AggregateOptions: Codable {
    /// Enables writing to temporary files. When set to true, aggregation stages
    /// can write data to the _tmp subdirectory in the dbPath directory.
    public var allowDiskUse: Bool?

    /// The number of `Document`s to return per batch.
    public var batchSize: Int32?

    /// If true, allows the write to opt-out of document level validation. This only applies
    /// when the $out stage is specified.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public var collation: Document?

    /// Enables users to specify an arbitrary string to help trace the operation through
    /// the database profiler, currentOp and logs. The default is to not send a value.
    public var comment: String?

    /// The index hint to use for the aggregation. The hint does not apply to $lookup and $graphLookup stages.
    public var hint: Hint?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// A `ReadConcern` to use in read stages of this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization
    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil
    // swiftlint:enable redundant_optional_initialization

    /// A `WriteConcern` to use in `$out` stages of this operation.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        allowDiskUse: Bool? = nil,
        batchSize: Int32? = nil,
        bypassDocumentValidation: Bool? = nil,
        collation: Document? = nil,
        comment: String? = nil,
        hint: Hint? = nil,
        maxTimeMS: Int64? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.allowDiskUse = allowDiskUse
        self.batchSize = batchSize
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.comment = comment
        self.hint = hint
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.writeConcern = writeConcern
    }

    private enum CodingKeys: String, CodingKey {
        case allowDiskUse, batchSize, bypassDocumentValidation, collation, maxTimeMS, comment, hint, readConcern,
            writeConcern
    }
}

/// An operation corresponding to an "aggregate" command on a collection.
internal struct AggregateOperation<CollectionType: Codable>: Operation {
    private let collection: MongoCollection<CollectionType>
    private let pipeline: [Document]
    private let options: AggregateOptions?

    internal init(collection: MongoCollection<CollectionType>, pipeline: [Document], options: AggregateOptions?) {
        self.collection = collection
        self.pipeline = pipeline
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> MongoCursor<Document> {
        let opts = try encodeOptions(options: self.options, session: session)
        let rp = self.options?.readPreference?.pointer
        let pipeline: Document = ["pipeline": .array(self.pipeline.map { .document($0) })]

        let result: OpaquePointer = self.collection.withMongocCollection(from: connection) { collPtr in
            guard let result = mongoc_collection_aggregate(
                collPtr,
                MONGOC_QUERY_NONE,
                pipeline._bson,
                opts?._bson,
                rp
            ) else {
                fatalError(failedToRetrieveCursorMessage)
            }
            return result
        }

        // since mongoc_collection_aggregate doesn't do any I/O, use forceIO to ensure this operation fails if we
        // can not successfully get a cursor from the server.
        return try MongoCursor(
            stealing: result,
            connection: connection,
            client: self.collection._client,
            decoder: self.collection.decoder,
            session: session
        )
    }
}
