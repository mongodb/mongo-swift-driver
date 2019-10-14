import mongoc

extension SyncMongoCollection {
    /**
     * Starts a `SyncChangeStream` on a collection. The `CollectionType` will be associated with the `fullDocument` field
     * in `ChangeStreamEvent`s emitted by the returned `SyncChangeStream`. The server will return an error if this is called
     * on a system collection.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `SyncClientSession` to use with this change stream.
     * - Returns: A `SyncChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
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
                      session: SyncClientSession? = nil) throws -> SyncChangeStream<ChangeStreamEvent<CollectionType>> {
        return try self.watch(pipeline, options: options, session: session, withFullDocumentType: CollectionType.self)
    }

    /**
     * Starts a `SyncChangeStream` on a collection. Associates the specified `Codable` type `T` with the `fullDocument`
     * field in the `ChangeStreamEvent`s emitted by the returned `SyncChangeStream`. The server will return an error
     * if this is called on a system collection.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `SyncClientSession` to use with this change stream.
     *   - withFullDocumentType: The type that the `fullDocument` field of the emitted `ChangeStreamEvent`s will be
     *                           decoded to.
     * - Returns: A `SyncChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     */
    public func watch<FullDocType: Codable>(_ pipeline: [Document] = [],
                                            options: ChangeStreamOptions? = nil,
                                            session: SyncClientSession? = nil,
                                            withFullDocumentType type: FullDocType.Type)
                                        throws -> SyncChangeStream<ChangeStreamEvent<FullDocType>> {
        return try self.watch(pipeline,
                              options: options,
                              session: session,
                              withEventType: ChangeStreamEvent<FullDocType>.self)
    }

    /**
     * Starts a `SyncChangeStream` on a collection. Associates the specified `Codable` type `T` with the returned
     * `SyncChangeStream`. The server will return an error if this is called on a system collection.
     * - Parameters:
     *   - pipeline: An array of aggregation pipeline stages to apply to the events returned by the change stream.
     *   - options: An optional `ChangeStreamOptions` to use when constructing the change stream.
     *   - session: An optional `SyncClientSession` to use with this change stream.
     *   - withEventType: The type that the entire change stream response will be decoded to and that will be returned
     *                    when iterating through the change stream.
     * - Returns: A `SyncChangeStream` on a specific collection.
     * - Throws:
     *   - `ServerError.commandError` if an error occurs on the server while creating the change stream.
     *   - `UserError.invalidArgumentError` if the options passed formed an invalid combination.
     *   - `UserError.invalidArgumentError` if the `_id` field is projected out of the change stream documents by the
     *     pipeline.
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/changeStreams/
     *   - https://docs.mongodb.com/manual/meta/aggregation-quick-reference/
     *   - https://docs.mongodb.com/manual/reference/system-collections/
     */
    public func watch<EventType: Codable>(_ pipeline: [Document] = [],
                                          options: ChangeStreamOptions? = nil,
                                          session: SyncClientSession? = nil,
                                          withEventType type: EventType.Type) throws -> SyncChangeStream<EventType> {
        let connection = try resolveConnection(client: self._client, session: session)
        let operation = try WatchOperation<CollectionType, EventType>(target: .collection(self),
                                                                      pipeline: pipeline,
                                                                      options: options,
                                                                      stealing: connection)
        return try self._client.executeOperation(operation, session: session)
    }
}
