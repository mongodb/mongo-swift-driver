internal protocol Operation {
    associatedtype OperationResult
    func execute() throws -> OperationResult
}
