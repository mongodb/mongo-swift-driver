/// A protocol for operation types to conform to. An `Operation` instance corresponds to any single operation a user
/// can perform with the driver's API that requires I/O.
internal protocol Operation {
    /// The result type this operation returns.
    associatedtype OperationResult
    /// Executes this operation and returns its corresponding result type.
    func execute() throws -> OperationResult
}

/// Internal function for generating an options `Document` for passing to libmongoc.
internal func combine<T: Encodable>(options: T?, session: ClientSession?, using encoder: BSONEncoder) throws -> Document? {
    guard options != nil || session != nil else {
        return nil
    }

    var doc = try encoder.encode(options) ?? Document()
    try session?.append(to: &doc)
    return doc
}
