struct UnifiedCreateCollection: UnifiedOperationProtocol {
    /// The collection to create.
    let collection: String

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        ["collection", "session"]
    }
}

struct UnifiedDropCollection: UnifiedOperationProtocol {
    /// The collection to drop.
    let collection: String

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        ["collection", "session"]
    }
}
