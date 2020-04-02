import CLibMongoC

/// Options to use when executing a `countDocuments` command on a `MongoCollection`.
public struct CountDocumentsOptions: Codable {
    /// Specifies a collation.
    public var collation: Document?

    /// A hint for the index to use.
    public var hint: Hint?

    /// The maximum number of documents to count.
    public var limit: Int64?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization
    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil
    // swiftlint:enable redundant_optional_initialization

    /// The number of documents to skip before counting.
    public var skip: Int64?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        collation: Document? = nil,
        hint: Hint? = nil,
        limit: Int64? = nil,
        maxTimeMS: Int64? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        skip: Int64? = nil
    ) {
        self.collation = collation
        self.hint = hint
        self.limit = limit
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.skip = skip
    }

    private enum CodingKeys: String, CodingKey {
        case collation, hint, limit, maxTimeMS, readConcern, skip
    }
}

/// An operation corresponding to a "count" command on a collection.
internal struct CountDocumentsOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let filter: Document
    private let options: CountDocumentsOptions?

    internal init(collection: MongoCollection<T>, filter: Document, options: CountDocumentsOptions?) {
        self.collection = collection
        self.filter = filter
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> Int {
        let opts = try encodeOptions(options: options, session: session)
        let rp = self.options?.readPreference?.pointer
        var error = bson_error_t()
        let count = self.collection.withMongocCollection(from: connection) { collPtr in
            mongoc_collection_count_documents(collPtr, self.filter._bson, opts?._bson, rp, nil, &error)
        }

        guard count != -1 else { throw extractMongoError(error: error) }

        return Int(count)
    }
}
