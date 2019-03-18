import mongoc

internal protocol Operation {
    associatedtype OperationResult
    func execute(client: OpaquePointer) throws -> OperationResult
}

internal func executeOperation<T: Operation>(_ operation: T, withClient: MongoClient) throws -> T.OperationResult {
    if let pool = withClient._pool {
        let client = mongoc_client_pool_pop(pool)
        let result = try operation.execute(client: client!)
        mongoc_client_pool_push(pool, client)
        return result
    }

    return try operation.execute(client: withClient._client!)
}

internal struct MongoNamespace {
    ///
    public let db: String

    ///
    public let collection: String?

    /// Create a namespace for a collection
    public init(_ databaseName: String, _ collectionName: String? = nil) {
        self.db = databaseName
        self.collection = collectionName
    }
}
