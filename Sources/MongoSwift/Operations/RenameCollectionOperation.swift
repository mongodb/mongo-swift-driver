import CLibMongoC

/// Options to use when renaming a collection. These options will be used for `MongoCollection.renamed`.
public struct RenameCollectionOptions: Codable {
    /// Specifies whether an existing collection matching the new name should be dropped before the rename.
    /// If this is not set to true and a collection with the new collection name exists, the server will throw an error.
    public let dropTarget: Bool?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

    private enum CodingKeys: String, CodingKey {
        case writeConcern
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.writeConcern = try container.decode(WriteConcern.self, forKey: .writeConcern)
        self.dropTarget = false
    }

    /// Initializer allowing any/all parameters to be omitted.
    public init(dropTarget: Bool = false, writeConcern: WriteConcern? = nil) {
        self.dropTarget = dropTarget
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to a "createIndexes" command.
internal struct RenameCollectionOperation<T: Codable>: Operation {
    private var collection: MongoCollection<T>
    private let to: String
    private let options: RenameCollectionOptions?

    internal init(
        collection: MongoCollection<T>,
        to: String,
        options: RenameCollectionOptions? = nil
    ) {
        self.collection = collection
        self.to = to
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> MongoCollection<T> {
        let opts = try encodeOptions(options: options, session: session)
        var error = bson_error_t()
        var dropTarget = false
        if let dt = options?.dropTarget {
            dropTarget = dt
        }

        return try self.collection.withMongocCollection(from: connection) { collPtr in
            try withOptionalBSONPointer(to: opts) { optsPtr in
                let success = mongoc_collection_rename_with_opts(
                    collPtr,
                    self.collection.namespace.db,
                    self.to,
                    dropTarget,
                    optsPtr,
                    &error
                )

                guard success else {
                    throw extractMongoError(error: error)
                }

                return MongoCollection(copying: self.collection, name: self.to)
            }
        }
    }
}
