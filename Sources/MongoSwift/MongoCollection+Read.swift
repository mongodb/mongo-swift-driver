import CLibMongoC
import NIO

/// An extension of `MongoCollection` encapsulating read operations.
extension MongoCollection {
    /**
     * Finds the documents in this collection which match the provided filter.
     *
     * - Warning:
     *    If the returned cursor is alive when it goes out of scope, it will leak resources. To ensure the cursor
     *    is dead before it leaves scope, invoke `MongoCursor.kill(...)` on it.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` that should match the query
     *   - options: Optional `FindOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCursor<CollectionType>`. On success, contains a cursor over the resulting documents.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func find(
        _ filter: BSONDocument = [:],
        options: FindOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<MongoCursor<CollectionType>> {
        let operation = FindOperation(collection: self, filter: filter, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Finds a single document in this collection that matches the provided filter.
     *
     * - Parameters:
     *   - filter: A `BSONDocument` that should match the query
     *   - options: Optional `FindOneOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<CollectionType?>`. On success, contains the matching document, or nil if there was no
     *    match.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func findOne(
        _ filter: BSONDocument = [:],
        options: FindOneOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<T?> {
        let options = options.map { FindOptions(from: $0) }
        return self.find(filter, options: options, session: session).flatMap { cursor in
            cursor.next().always { _ in _ = cursor.kill() }
        }
    }

    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: an `[Document]` containing the pipeline of aggregation operations to perform
     *   - options: Optional `AggregateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Warning:
     *    If the returned cursor is alive when it goes out of scope, it will leak resources. To ensure the cursor
     *    is dead before it leaves scope, invoke `MongoCursor.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCursor<CollectionType>`. On success, contains a cursor over the resulting documents.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func aggregate(
        _ pipeline: [BSONDocument],
        options: AggregateOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<MongoCursor<BSONDocument>> {
        self.aggregate(pipeline, options: options, session: session, withOutputType: BSONDocument.self)
    }

    /**
     * Runs an aggregation framework pipeline against this collection.
     * Associates the specified `Codable` type `OutputType` with the returned `MongoCursor`
     *
     * - Parameters:
     *   - pipeline: an `[Document]` containing the pipeline of aggregation operations to perform
     *   - options: Optional `AggregateOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *   - withOutputType: the type that each resulting document of the output
     *     of the aggregation operation will be decoded to
     *
     * - Warning:
     *    If the returned cursor is alive when it goes out of scope, it will leak resources. To ensure the cursor
     *    is dead before it leaves scope, invoke `MongoCursor.kill(...)` on it.
     *
     * - Returns:
     *    An `EventLoopFuture<MongoCursor>`over the resulting `OutputType`s
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.InvalidArgumentError` if the options passed are an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func aggregate<OutputType: Codable>(
        _ pipeline: [BSONDocument],
        options: AggregateOptions? = nil,
        session: ClientSession? = nil,
        withOutputType _: OutputType.Type
    ) -> EventLoopFuture<MongoCursor<OutputType>> {
        let operation = AggregateOperation<T, OutputType>(collection: self, pipeline: pipeline, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Counts the number of documents in this collection matching the provided filter. Note that an empty filter will
     * force a scan of the entire collection. For a fast count of the total documents in a collection see
     * `estimatedDocumentCount`.
     *
     * - Parameters:
     *   - filter: a `BSONDocument`, the filter that documents must match in order to be counted
     *   - options: Optional `CountDocumentsOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<Int>`. On success, contains the count of the documents that matched the filter.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func countDocuments(
        _ filter: BSONDocument = [:],
        options: CountDocumentsOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<Int> {
        let operation = CountDocumentsOperation(collection: self, filter: filter, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }

    /**
     * Gets an estimate of the count of documents in this collection using collection metadata. This operation cannot
     * be used in a transaction.
     *
     * - Parameters:
     *   - options: Optional `EstimatedDocumentCountOptions` to use when executing the command
     *
     * - Returns:
     *    An `EventLoopFuture<Int>`. On success, contains an estimate of the count of documents in this collection.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func estimatedDocumentCount(options: EstimatedDocumentCountOptions? = nil) -> EventLoopFuture<Int> {
        let operation = EstimatedDocumentCountOperation(collection: self, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: nil)
    }

    /**
     * Finds the distinct values for a specified field across the collection.
     *
     * - Parameters:
     *   - fieldName: The field for which the distinct values will be found
     *   - filter: a `BSONDocument` representing the filter documents must match in order to be considered for the
     *             operation
     *   - options: Optional `DistinctOptions` to use when executing the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns:
     *    An `EventLoopFuture<[BSON]>`. On success, contains the distinct values for the specified criteria.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *    - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *    - `MongoError.LogicError` if the provided session is inactive.
     *    - `MongoError.LogicError` if this collection's parent client has already been closed.
     *    - `EncodingError` if an error occurs while encoding the options to BSON.
     */
    public func distinct(
        fieldName: String,
        filter: BSONDocument = [:],
        options: DistinctOptions? = nil,
        session: ClientSession? = nil
    ) -> EventLoopFuture<[BSON]> {
        let operation = DistinctOperation(collection: self, fieldName: fieldName, filter: filter, options: options)
        return self._client.operationExecutor.execute(operation, client: self._client, session: session)
    }
}
