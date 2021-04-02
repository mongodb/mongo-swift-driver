import CLibMongoC

/// Options to use when executing an `estimatedDocumentCount` command on a `MongoCollection`.
public struct EstimatedDocumentCountOptions: Codable {
    /// The maximum amount of time to allow the query to run.
    public var maxTimeMS: Int?

    /// A ReadConcern to use for this operation.
    public var readConcern: ReadConcern?

    // swiftlint:disable redundant_optional_initialization
    /// A ReadPreference to use for this operation.
    public var readPreference: ReadPreference? = nil
    // swiftlint:enable redundant_optional_initialization

    /// Convenience initializer allowing any/all parameters to be optional
    public init(
        maxTimeMS: Int? = nil,
        readConcern: ReadConcern? = nil,
        readPreference: ReadPreference? = nil
    ) {
        self.maxTimeMS = maxTimeMS
        self.readConcern = readConcern
        self.readPreference = readPreference
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case maxTimeMS, readConcern
    }
}

/// An operation corresponding to a "count" command on a collection.
internal struct EstimatedDocumentCountOperation<T: Codable>: Operation {
    private let collection: MongoCollection<T>
    private let options: EstimatedDocumentCountOptions?

    internal init(collection: MongoCollection<T>, options: EstimatedDocumentCountOptions?) {
        self.collection = collection
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> Int {
        let opts = try encodeOptions(options: options, session: session)
        var error = bson_error_t()
        let count = self.collection.withMongocCollection(from: connection) { collPtr in
            withOptionalBSONPointer(to: opts) { optsPtr in
                ReadPreference.withOptionalMongocReadPreference(from: self.options?.readPreference) { rpPtr in
                    mongoc_collection_estimated_document_count(collPtr, optsPtr, rpPtr, nil, &error)
                }
            }
        }

        guard count != -1 else { throw extractMongoError(error: error) }

        return Int(count)
    }
}
