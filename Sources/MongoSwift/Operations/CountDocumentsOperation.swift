import CLibMongoC

/// Options to use when executing a `countDocuments` command on a `MongoCollection`.
public struct CountDocumentsOptions: Codable {
    /// Specifies a collation.
    public var collation: BSONDocument?

    /// An arbitrary BSON type to help trace the operation through
    /// the database profiler, currentOp and logs. The default is to not send a value.
    public var comment: BSON?

    /// A hint for the index to use.
    public var hint: IndexHint?

    /// The maximum number of documents to count.
    public var limit: Int?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization
    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil
    // swiftlint:enable redundant_optional_initialization

    /// The number of documents to skip before counting.
    public var skip: Int?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        collation: BSONDocument? = nil,
        comment: BSON? = nil,
        hint: IndexHint? = nil,
        limit: Int? = nil,
        maxTimeMS: Int? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil,
        skip: Int? = nil
    ) {
        self.collation = collation
        self.comment = comment
        self.hint = hint
        self.limit = limit
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
        self.skip = skip
    }

    internal enum CodingKeys: String, CaseIterable, CodingKey {
        case collation, comment, hint, limit, maxTimeMS, readConcern, skip
    }
}

/// An operation corresponding to a "count" command on a collection.
internal struct CountDocumentsOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let filter: BSONDocument
    private let options: CountDocumentsOptions?

    internal init(collection: MongoCollection<T>, filter: BSONDocument, options: CountDocumentsOptions?) {
        self.collection = collection
        self.filter = filter
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> Int {
        let opts = try encodeOptions(options: options, session: session)
        var error = bson_error_t()

        return try self.collection.withMongocCollection(from: connection) { collPtr in
            try self.filter.withBSONPointer { filterPtr in
                try withOptionalBSONPointer(to: opts) { optsPtr in
                    try ReadPreference.withOptionalMongocReadPreference(from: self.options?.readPreference) { rpPtr in
                        try withStackAllocatedMutableBSONPointer { replyPtr in
                            let count = mongoc_collection_count_documents(
                                collPtr,
                                filterPtr,
                                optsPtr,
                                rpPtr,
                                replyPtr,
                                &error
                            )
                            guard count != -1 else {
                                throw extractMongoError(error: error, reply: BSONDocument(copying: replyPtr))
                            }
                            return Int(count)
                        }
                    }
                }
            }
        }
    }
}
