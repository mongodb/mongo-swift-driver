import mongoc

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
    public init(collation: Document? = nil,
                maxTimeMS: Int64? = nil,
                readConcern: ReadConcern? = nil,
                readPreference: ReadPreference? = nil) {
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
internal struct DistinctOperation<T: Codable> {
    private let collection: MongoCollection<T>
    private let fieldName: String
    private let filter: Document
    private let options: DistinctOptions?
    private let session: ClientSession?

    internal init(collection: MongoCollection<T>,
                  fieldName: String,
                  filter: Document,
                  options: DistinctOptions?,
                  session: ClientSession?) {
        self.collection = collection
        self.fieldName = fieldName
        self.filter = filter
        self.options = options
        self.session = session
    }

    internal func execute() throws -> [BSONValue] {
        let collName = String(cString: mongoc_collection_get_name(self.collection._collection))
        let command: Document = [
            "distinct": collName,
            "key": self.fieldName,
            "query": self.filter
        ]

        let opts = try encodeOptions(options: self.options, session: self.session)
        let rp = self.options?.readPreference?._readPreference
        var reply = Document()
        var error = bson_error_t()
        let success = withMutableBSONPointer(to: &reply) { replyPtr in
            mongoc_collection_read_command_with_opts(
            self.collection._collection, command._bson, rp, opts?._bson, replyPtr, &error)
        }
        guard success else {
            throw parseMongocError(error, errorLabels: reply["errorLabels"] as? [String])
        }

        guard let values = try reply.getValue(for: "values") as? [BSONValue] else {
            throw RuntimeError.internalError(message:
                "expected server reply \(reply) to contain an array of distinct values")
        }

        return values
    }
}
