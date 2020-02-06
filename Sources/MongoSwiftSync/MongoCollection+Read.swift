import MongoSwift

extension MongoCollection {
    /**
     * Finds the documents in this collection which match the provided filter.
     *
     * - Parameters:
     *   - filter: A `Document` that should match the query
     *   - options: Optional `FindOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `MongoCursor` over the resulting `Document`s
     *
     * - Throws:
     *   - `InvalidArgumentError` if the options passed are an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func find(
        _ filter: Document = [:],
        options: FindOptions? = nil,
        session: ClientSession? = nil
    ) throws -> MongoCursor<CollectionType> {
        let asyncCursor = try self.asyncColl.find(filter, options: options, session: session?.asyncSession).wait()
        return MongoCursor(wrapping: asyncCursor, client: self.client)
    }

    /**
     * Finds a single document in this collection that matches the provided filter.
     *
     * - Parameters:
     *   - filter: A `Document` that should match the query
     *   - options: Optional `FindOneOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:  the resulting `Document`, or nil if there is no match
     *
     * - Throws:
     *   - `InvalidArgumentError` if the options passed are an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func findOne(
        _ filter: Document = [:],
        options: FindOneOptions? = nil,
        session: ClientSession? = nil
    ) throws -> T? {
        return try self.asyncColl.findOne(filter, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: an `[Document]` containing the pipeline of aggregation operations to perform
     *   - options: Optional `AggregateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `MongoCursor` over the resulting `Document`s
     *
     * - Throws:
     *   - `InvalidArgumentError` if the options passed are an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func aggregate(
        _ pipeline: [Document],
        options: AggregateOptions? = nil,
        session: ClientSession? = nil
    ) throws -> MongoCursor<Document> {
        let asyncCursor = try self.asyncColl.aggregate(pipeline, options: options, session: session?.asyncSession)
            .wait()
        return MongoCursor(wrapping: asyncCursor, client: self.client)
    }

    /**
     * Counts the number of documents in this collection matching the provided filter. Note that an empty filter will
     * force a scan of the entire collection. For a fast count of the total documents in a collection see
     * `estimatedDocumentCount`.
     *
     * - Parameters:
     *   - filter: a `Document`, the filter that documents must match in order to be counted
     *   - options: Optional `CountDocumentsOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: The count of the documents that matched the filter
     */
    public func countDocuments(
        _ filter: Document = [:],
        options: CountDocumentsOptions? = nil,
        session: ClientSession? = nil
    ) throws -> Int {
        return try self.asyncColl.countDocuments(filter, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Gets an estimate of the count of documents in this collection using collection metadata.
     *
     * - Parameters:
     *   - options: Optional `EstimatedDocumentCountOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: an estimate of the count of documents in this collection
     */
    public func estimatedDocumentCount(
        options: EstimatedDocumentCountOptions? = nil,
        session: ClientSession? = nil
    ) throws -> Int {
        return try self.asyncColl.estimatedDocumentCount(options: options, session: session?.asyncSession).wait()
    }

    /**
     * Finds the distinct values for a specified field across the collection.
     *
     * - Parameters:
     *   - fieldName: The field for which the distinct values will be found
     *   - filter: a `Document` representing the filter documents must match in order to be considered for the operation
     *   - options: Optional `DistinctOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `[BSONValue]` containing the distinct values for the specified criteria
     *
     * - Throws:
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func distinct(
        fieldName: String,
        filter: Document = [:],
        options: DistinctOptions? = nil,
        session: ClientSession? = nil
    ) throws -> [BSON] {
        return try self.asyncColl.distinct(
            fieldName: fieldName,
            filter: filter,
            options: options,
            session: session?.asyncSession
        )
        .wait()
    }
}
