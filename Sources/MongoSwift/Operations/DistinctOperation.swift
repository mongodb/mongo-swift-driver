import mongoc

/// Options to use when executing a `distinct` command on a `MongoCollection`.
public struct DistinctOptions: Encodable {
    /// Specifies a collation.
    public let collation: Document?

    /// The maximum amount of time to allow the query to run.
    public let maxTimeMS: Int64?

    /// A ReadConcern to use for this operation.
    public let readConcern: ReadConcern?

    /// A ReadPreference to use for this operation.
    public let readPreference: ReadPreference?

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

        let opts = try combine(options: self.options, session: self.session, using: self.collection.encoder)
        let rp = self.options?.readPreference?._readPreference
        let reply = Document()
        var error = bson_error_t()
        guard mongoc_collection_read_command_with_opts(
            self.collection._collection, command.data, rp, opts?.data, reply.data, &error) else {
            throw parseMongocError(error, errorLabels: reply["errorLabels"] as? [String])
        }

        guard let values = try reply.getValue(for: "values") as? [BSONValue] else {
            throw RuntimeError.internalError(message:
                "expected server reply \(reply) to contain an array of distinct values")
        }

        return values
    }
}
