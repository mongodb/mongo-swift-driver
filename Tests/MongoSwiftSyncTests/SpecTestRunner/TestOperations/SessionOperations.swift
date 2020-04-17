import MongoSwiftSync

struct StartTransaction: TestOperation {
    let options: TransactionOptions?

    init() {
        self.options = nil
    }

    func execute(on session: ClientSession) throws -> TestOperationResult? {
        try session.startTransaction(options: self.options)
        return nil
    }
}

struct CommitTransaction: TestOperation {
    func execute(on session: ClientSession) throws -> TestOperationResult? {
        try session.commitTransaction()
        return nil
    }
}

struct AbortTransaction: TestOperation {
    func execute(on session: ClientSession) throws -> TestOperationResult? {
        try session.abortTransaction()
        return nil
    }
}
