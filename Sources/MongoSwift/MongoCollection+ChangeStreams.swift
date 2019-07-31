import mongoc

extension MongoCollection {
    /**
     * Starts a `ChangeStream` on a collection. The `CollectionType` will be associated with the
     * `fullDocument` field in `ChangeStreamDocument`s emitted by the returned `ChangeStream`.
     * Excludes system collections.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     * - Returns: A `ChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `ServerError.commandError` if the pipeline passed is invalid.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     */
    public func watch(_ pipeline: [Document] = [],
                      options: ChangeStreamOptions? =  nil,
                      session: ClientSession? = nil) throws ->
                      ChangeStream<ChangeStreamDocument<CollectionType>> {
        return try self.watch(pipeline, options: options, session: session, withFullDocumentType: CollectionType.self)
    }

    /**
     * Starts a `ChangeStream` on a collection. Associates the specified `Codable` type `T` with the `fullDocument`
     * field in the `ChangeStreamDocument`s emitted by the returned `ChangeStream`. Excludes system collections.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the `fullDocument` field of the emitted `ChangeStreamDocument`s will be
     *                           decoded to.
     * - Returns: A `ChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `ServerError.commandError` if the pipeline passed is invalid.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     */
    public func watch<T: Codable>(_ pipeline: [Document] = [],
                                  options: ChangeStreamOptions? = nil,
                                  session: ClientSession? = nil,
                                  withFullDocumentType type: T.Type) throws ->
                                  ChangeStream<ChangeStreamDocument<T>> {
        return try self.watch(pipeline,
                              options: options,
                              session: session,
                              withEventType: ChangeStreamDocument<T>.self)
    }

    /**
     * Starts a `ChangeStream` on a collection. Associates the specified `Codable` type `T` with the returned
     * `ChangeStream`. Excludes system collections
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `ClientSession` to use with this change stream.
     *   - withEventType: The type that the entire change stream response will be decoded to and that will be returned
     *                    when iterating through the change stream.
     * - Returns: A `ChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `ServerError.commandError` if the pipeline passed is invalid.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     */
    public func watch<T: Codable>(_ pipeline: [Document] = [],
                                  options: ChangeStreamOptions? = nil,
                                  session: ClientSession? = nil,
                                  withEventType type: T.Type) throws ->
                                  ChangeStream<T> {
        let pipeline: Document = ["pipeline": pipeline]
        let connection = try self._client.connectionPool.checkOut()
        return try self.withMongocCollection(from: connection) { collPtr in
            let opts = try encodeOptions(options: options, session: session)
            let changeStreamPtr: OpaquePointer = mongoc_collection_watch(collPtr, pipeline._bson, opts?._bson)
            return try ChangeStream<T>(stealing: changeStreamPtr,
                                       options: options,
                                       client: self._client,
                                       connection: connection,
                                       session: session,
                                       decoder: self.decoder)
        }
    }
}
