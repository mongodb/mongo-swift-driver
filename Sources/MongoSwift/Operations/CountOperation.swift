import mongoc

/// Options to use when executing a `count` command on a `MongoCollection`.
public struct CountOptions: Codable {
    /// Specifies a collation.
    public var collation: Document?

    /// A hint for the index to use.
    public var hint: Hint?

    /// The maximum number of documents to count.
    public var limit: Int64?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// The number of documents to skip before counting.
    public var skip: Int64?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization
    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil
    // swiftlint:enable redundant_optional_initialization

    /// Convenience initializer allowing any/all parameters to be optional
    public init(collation: Document? = nil,
                hint: Hint? = nil,
                limit: Int64? = nil,
                maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil,
                skip: Int64? = nil) {
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
internal struct CountOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let filter: Document
    private let options: CountOptions?
    private let session: ClientSession?

    internal init(collection: MongoCollection<T>,
                  filter: Document,
                  options: CountOptions?,
                  session: ClientSession?) {
        self.collection = collection
        self.filter = filter
        self.options = options
        self.session = session
    }

    internal func execute() throws -> Int {
        let opts = try encodeOptions(options: options, session: session)
        let rp = self.options?.readPreference?._readPreference
        var error = bson_error_t()
        // because we already encode skip and limit in the options,
        // pass in 0s so we don't get duplicate parameter errors.
        let count = mongoc_collection_count_with_opts(
            self.collection._collection, MONGOC_QUERY_NONE, self.filter._bson, 0, 0, opts?._bson, rp, &error)

        if count == -1 { throw parseMongocError(error) }

        return Int(count)
    }
}
