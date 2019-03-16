internal protocol Operation {
    associatedtype OperationResult
    func execute() throws -> OperationResult
}

internal func executeOperation<T: Operation>(_ operation: T) throws -> T.OperationResult {
    return try operation.execute()
}
