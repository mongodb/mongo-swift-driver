import CLibMongoC

/// Options to use when executing a `distinct` command on a `MongoCollection`.
public struct DistinctOptions: Codable {
    /// Specifies a collation.
    public var collation: Document?

    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int64?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization
    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil
    // swiftlint:enable redundant_optional_initialization

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        collation: Document? = nil,
        maxTimeMS: Int64? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil
    ) {
        self.collation = collation
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
    }

    private enum CodingKeys: String, CodingKey {
        case collation, maxTimeMS, readConcern
    }
}

/// An operation corresponding to a "distinct" command on a collection.
internal struct DistinctOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let fieldName: String
    private let filter: Document
    private let options: DistinctOptions?

    internal init(collection: MongoCollection<T>, fieldName: String, filter: Document, options: DistinctOptions?) {
        self.collection = collection
        self.fieldName = fieldName
        self.filter = filter
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> [BSON] {
        let command: Document = [
            "distinct": .string(self.collection.name),
            "key": .string(self.fieldName),
            "query": .document(self.filter)
        ]

        let opts = try encodeOptions(options: self.options, session: session)
        let rp = self.options?.readPreference?.pointer
        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            self.collection.withMongocCollection(from: connection) { collPtr in
                mongoc_collection_read_command_with_opts(collPtr, command._bson, rp, opts?._bson, replyPtr, &error)
            }
        }
        guard success else {
            throw extractMongoError(error: error, reply: reply)
        }

        guard let values = try reply.getValue(for: "values")?.arrayValue else {
            throw InternalError(
                message:
                "expected server reply \(reply) to contain an array of distinct values"
            )
        }

        return values
    }
}
