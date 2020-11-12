import MongoSwiftSync

struct UnifiedFailPoint: UnifiedOperationProtocol {
    /// The configureFailpoint command to be executed.
    let failPoint: BSONDocument

    /// The client entity to use for setting the failpoint.
    let client: String

    static var knownArguments: Set<String> {
        ["failPoint", "client"]
    }
}

struct AssertSessionNotDirty: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }
}

struct AssertDifferentLsidOnLastTwoCommands: UnifiedOperationProtocol {
    /// Identifier for the client to perform the assertion on.
    let client: String

    static var knownArguments: Set<String> {
        ["client"]
    }
}

struct AssertSameLsidOnLastTwoCommands: UnifiedOperationProtocol {
    /// Identifier for the client to perform the assertion on.
    let client: String

    static var knownArguments: Set<String> {
        ["client"]
    }
}
