import mongoc

/// An extension of `MongoCollection` encapsulating write operations.
extension MongoCollection {
    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it.
     *
     * - Parameters:
     *   - value: A `CollectionType` value to encode and insert
     *   - options: Optional `InsertOneOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to perform the insert. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` to BSON.
     */
    @discardableResult
    public func insertOne(_ value: CollectionType,
                          options: InsertOneOptions? = nil,
                          session: ClientSession? = nil) throws -> InsertOneResult? {
        return try convertingBulkWriteErrors {
            let model = InsertOneModel(value)
            let result = try self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            return try InsertOneResult(from: result)
        }
    }

    /**
     * Encodes the provided values to BSON and inserts them. If any values are
     * missing identifiers, the driver will generate them.
     *
     * - Parameters:
     *   - values: The `CollectionType` values to insert
     *   - options: optional `InsertManyOptions` to use while executing the operation
     *
     * - Returns: an `InsertManyResult`, or `nil` if the write concern is unacknowledged.
     *
     * - Throws:
     *   - `ServerError.bulkWriteError` if an error occurs while performing any of the writes.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func insertMany(_ values: [CollectionType],
                           options: InsertManyOptions? = nil,
                           session: ClientSession? = nil) throws -> InsertManyResult? {
        let models = values.map { InsertOneModel($0) }
        let result = try self.bulkWrite(models, options: options, session: session)
        return InsertManyResult(from: result)
    }

    /**
     * Replaces a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - replacement: The replacement value, a `CollectionType` value to be encoded and inserted
     *   - options: Optional `ReplaceOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to replace a document. If the `WriteConcern`
     *            is unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the `CollectionType` or options to BSON.
     */
    @discardableResult
    public func replaceOne(filter: Document,
                           replacement: CollectionType,
                           options: ReplaceOptions? = nil,
                           session: ClientSession? = nil) throws -> UpdateResult? {
        return try convertingBulkWriteErrors {
            let model = ReplaceOneModel(filter: filter,
                                        replacement: replacement,
                                        collation: options?.collation,
                                        upsert: options?.upsert)
            let result = try self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            return try UpdateResult(from: result)
        }
    }

    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to a matching document
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to update a document. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateOne(filter: Document,
                          update: Document,
                          options: UpdateOptions? = nil,
                          session: ClientSession? = nil) throws -> UpdateResult? {
        return try convertingBulkWriteErrors {
            let model = UpdateOneModel(filter: filter,
                                       update: update,
                                       arrayFilters: options?.arrayFilters,
                                       collation: options?.collation,
                                       upsert: options?.upsert)
            let result = try self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            return try UpdateResult(from: result)
        }
    }

    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - update: A `Document` representing the update to be applied to matching documents
     *   - options: Optional `UpdateOptions` to use when executing the command
     *
     * - Returns: The optional result of attempting to update multiple documents. If the write
     *            concern is unacknowledged, nil is returned
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func updateMany(filter: Document,
                           update: Document,
                           options: UpdateOptions? = nil,
                           session: ClientSession? = nil) throws -> UpdateResult? {
        return try convertingBulkWriteErrors {
            let model = UpdateManyModel(filter: filter,
                                        update: update,
                                        arrayFilters: options?.arrayFilters,
                                        collation: options?.collation,
                                        upsert: options?.upsert)
            let result = try self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            return try UpdateResult(from: result)
        }
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteOne(_ filter: Document,
                          options: DeleteOptions? = nil,
                          session: ClientSession? = nil) throws -> DeleteResult? {
        return try convertingBulkWriteErrors {
            let model = DeleteOneModel(filter, collation: options?.collation)
            let result = try self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            return try DeleteResult(from: result)
        }
    }

    /**
     * Deletes multiple documents
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *   - options: Optional `DeleteOptions` to use when executing the command
     *
     * - Returns: The optional result of performing the deletion. If the `WriteConcern` is
     *            unacknowledged, `nil` is returned.
     *
     * - Throws:
     *   - `ServerError.writeError` if an error occurs while performing the command.
     *   - `ServerError.commandError` if an error occurs that prevents the command from executing.
     *   - `UserError.invalidArgumentError` if the options passed in form an invalid combination.
     *   - `UserError.logicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    @discardableResult
    public func deleteMany(_ filter: Document,
                           options: DeleteOptions? = nil,
                           session: ClientSession? = nil) throws -> DeleteResult? {
        return try convertingBulkWriteErrors {
            let model = DeleteManyModel(filter, collation: options?.collation)
            let result = try self.bulkWrite([model], options: options?.asBulkWriteOptions(), session: session)
            return try DeleteResult(from: result)
        }
    }
}

/// Protocol indicating that an options type can be converted to a BulkWriteOptions.
private protocol BulkWriteOptionsConvertible {
    var bypassDocumentValidation: Bool? { get }
    var writeConcern: WriteConcern? { get }
    func asBulkWriteOptions() -> BulkWriteOptions
}

/// Default implementation of the protocol.
private extension BulkWriteOptionsConvertible {
    func asBulkWriteOptions() -> BulkWriteOptions {
        return BulkWriteOptions(bypassDocumentValidation: self.bypassDocumentValidation,
                                writeConcern: self.writeConcern)
    }
}

// Write command options structs

/// Options to use when executing an `insertOne` command on a `MongoCollection`.
public struct InsertOneOptions: Codable, BulkWriteOptionsConvertible {
    /// If true, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// An optional WriteConcern to use for the command.
    public var writeConcern: WriteConcern?

    /// Convenience initializer allowing bypassDocumentValidation to be omitted or optional
    public init(bypassDocumentValidation: Bool? = nil, writeConcern: WriteConcern? = nil) {
        self.bypassDocumentValidation = bypassDocumentValidation
        self.writeConcern = writeConcern
    }
}

/// Options to use when executing a multi-document insert operation on a `MongoCollection`.
public typealias InsertManyOptions = BulkWriteOptions

/// Options to use when executing an `update` command on a `MongoCollection`.
public struct UpdateOptions: Codable, BulkWriteOptionsConvertible {
    /// A set of filters specifying to which array elements an update should apply.
    public var arrayFilters: [Document]?

    /// If true, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public var collation: Document?

    /// When true, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional WriteConcern to use for the command.
    public var writeConcern: WriteConcern?

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

/// Options to use when executing a `replace` command on a `MongoCollection`.
public struct ReplaceOptions: Codable, BulkWriteOptionsConvertible {
    /// If true, allows the write to opt-out of document level validation.
    public var bypassDocumentValidation: Bool?

    /// Specifies a collation.
    public var collation: Document?

    /// When true, creates a new document if no document matches the query.
    public var upsert: Bool?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

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

/// Options to use when executing a `delete` command on a `MongoCollection`.
public struct DeleteOptions: Codable, BulkWriteOptionsConvertible {
    /// Specifies a collation.
    public var collation: Document?

    /// An optional `WriteConcern` to use for the command.
    public var writeConcern: WriteConcern?

     /// Convenience initializer allowing collation to be omitted or optional
    public init(collation: Document? = nil, writeConcern: WriteConcern? = nil) {
        self.collation = collation
        self.writeConcern = writeConcern
    }
    /// This is a requirement of the BulkWriteOptionsConvertible protocol.
    /// Since it does not apply to deletions, we just set it to nil.
    internal var bypassDocumentValidation: Bool? { return nil }
}

// Write command results structs

/// The result of an `insertOne` command on a `MongoCollection`.
public struct InsertOneResult: Decodable {
    private enum CodingKeys: String, CodingKey {
        case insertedId
    }

    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BSONValue

    internal init?(from result: BulkWriteResult?) throws {
        guard let result = result else {
            return nil
        }
        guard let id = result.insertedIds[0] else {
            throw RuntimeError.internalError(message: "BulkWriteResult missing _id for inserted document")
        }
        self.insertedId = id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let abv = try container.decode(AnyBSONValue.self, forKey: .insertedId)
        self.insertedId = abv.value
    }
}

/// The result of a multi-document insert operation on a `MongoCollection`.
public struct InsertManyResult {
    /// Number of documents inserted.
    public let insertedCount: Int

    /// Map of the index of the document in `values` to the value of its ID
    public let insertedIds: [Int: BSONValue]

    /// Internal initializer used for converting from a `BulkWriteResult` optional to an `InsertManyResult` optional.
    internal init?(from result: BulkWriteResult?) {
        guard let result = result else {
            return nil
        }
        self.insertedCount = result.insertedCount
        self.insertedIds = result.insertedIds
    }
}

/// The result of a `delete` command on a `MongoCollection`.
public struct DeleteResult: Decodable {
    /// The number of documents that were deleted.
    public let deletedCount: Int

    internal init?(from result: BulkWriteResult?) throws {
        guard let result = result else {
            return nil
        }
        self.deletedCount = result.deletedCount
    }
}

/// The result of an `update` operation a `MongoCollection`.
public struct UpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents that were modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: BSONValue?

    /// The number of documents that were upserted.
    public let upsertedCount: Int

    internal init?(from result: BulkWriteResult?) throws {
        guard let result = result else {
            return nil
        }
        self.matchedCount = result.matchedCount
        self.modifiedCount = result.modifiedCount
        self.upsertedCount = result.upsertedCount
        if result.upsertedCount == 1 {
            guard let id = result.upsertedIds[0] else {
                throw RuntimeError.internalError(message: "BulkWriteResult missing _id for upserted document")
            }
            self.upsertedId = id
        } else {
            self.upsertedId = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case matchedCount, modifiedCount, upsertedId, upsertedCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.matchedCount = try container.decode(Int.self, forKey: .matchedCount)
        self.modifiedCount = try container.decode(Int.self, forKey: .modifiedCount)
        let id = try container.decodeIfPresent(AnyBSONValue.self, forKey: .upsertedId)
        self.upsertedId = id?.value
        self.upsertedCount = try container.decode(Int.self, forKey: .upsertedCount)
    }
}
