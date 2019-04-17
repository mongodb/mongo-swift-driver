import mongoc

internal protocol UpdateOperationOptions: Encodable {
    var writeConcern: WriteConcern? { get }
}

/// Options to use when executing an `update` command on a `MongoCollection`.
public struct UpdateOptions: UpdateOperationOptions {
    /// A set of filters specifying to which array elements an update should apply.
    public let arrayFilters: [Document]?

    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional WriteConcern to use for the command.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(arrayFilters: [Document]? = nil,
                bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil,
                upsert: Bool? = nil,
                writeConcern: WriteConcern? = nil) {
        self.arrayFilters = arrayFilters
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a `replaceOne` command on a `MongoCollection`.
public struct ReplaceOptions: UpdateOperationOptions {
    /// If true, allows the write to opt-out of document level validation.
    public let bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public let collation: Document?

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public let writeConcern: WriteConcern?

    /// Convenience initializer allowing any/all parameters to be optional
    public init(bypassDocumentValidation: Bool? = nil,
                collation: Document? = nil,
                upsert: Bool? = nil,
                writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.collation = collation
        self.upsert = upsert
        self.writeConcern = writeConcern
    }
}

/// An operation corresponding to an `update` command on a collection.
internal struct UpdateOperation<CollectionType: Codable, OptionsType: UpdateOperationOptions>: Operation {
    private let collection: MongoCollection<CollectionType>
    private let filter: Document
    private let update: Document
    private let options: OptionsType?
    private let type: UpdateType

    internal enum UpdateType {
        case updateOne, updateMany, replaceOne
    }

    internal init(collection: MongoCollection<CollectionType>,
                  filter: Document,
                  update: Document,
                  options: OptionsType?,
                  type: UpdateType) {
        self.collection = collection
        self.filter = filter
        self.update = update
        self.options = options
        self.type = type
    }

    internal func execute() throws -> UpdateResult? {
        let opts = try self.collection.encoder.encode(self.options)
        let reply = Document()
        var error = bson_error_t()

        var result: Bool!
        switch self.type {
        case .updateOne:
            result = mongoc_collection_update_one(
                self.collection._collection, self.filter.data, self.update.data, opts?.data, reply.data, &error)
        case .updateMany:
            result = mongoc_collection_update_many(
                self.collection._collection, self.filter.data, self.update.data, opts?.data, reply.data, &error)
        case .replaceOne:
            result = mongoc_collection_replace_one(
                self.collection._collection, self.filter.data, self.update.data, opts?.data, reply.data, &error)
        }

        guard result else {
            throw getErrorFromReply(bsonError: error, from: reply)
        }

        guard self.collection.isAcknowledged(options?.writeConcern) else {
            return nil
        }

        return try self.collection.decoder.internalDecode(
                UpdateResult.self,
                from: reply,
                withError: "Couldn't understand response from the server.")
    }
}

/// The result of an `update` operation a `MongoCollection`.
public struct UpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents that were modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: AnyBSONValue?

    /// The number of documents that were upserted.
    public let upsertedCount: Int
}
