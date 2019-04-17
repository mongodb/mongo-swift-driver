/// A protocol for operation types to conform to. An operation corresponds to any single operation a user can perform
/// with the driver's API that requires I/O.
internal protocol Operation {
    /// The result type this operation returns.
    associatedtype OperationResult
    /// Executes this operation and returns its corresponding result type.
    func execute() throws -> OperationResult
}
