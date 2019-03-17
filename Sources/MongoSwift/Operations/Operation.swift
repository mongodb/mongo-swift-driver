internal protocol Operation {
    associatedtype OperationResult
    func execute(client: OpaquePointer) throws -> OperationResult
}

internal func executeOperation<T: Operation>(_ operation: T, withClient: OpaquePointer) throws -> T.OperationResult {
    return try operation.execute(client: withClient)
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
