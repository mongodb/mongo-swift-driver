@testable import class MongoSwift.ClientSession
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

struct UnifiedAssertCollectionExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database
    let databaseName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName"]
    }
}

struct UnifiedAssertCollectionNotExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database.
    let databaseName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName"]
    }
}

struct UnifiedAssertIndexExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database.
    let databaseName: String

    /// The name of the index.
    let indexName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName", "indexName"]
    }
}

struct UnifiedAssertIndexNotExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database to look for the collection in.
    let databaseName: String

    /// The name of the index.
    let indexName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName", "indexName"]
    }
}

struct AssertSessionNotDirty: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }
}

struct AssertSessionDirty: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }
}

struct UnifiedAssertSessionPinned: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }
}

struct UnifiedAssertSessionUnpinned: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }
}

struct UnifiedAssertSessionTransactionState: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    /// The expected transaction state.
    let state: ClientSession.TransactionState

    static var knownArguments: Set<String> {
        ["session", "state"]
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

struct UnifiedTargetedFailPoint: UnifiedOperationProtocol {
    /// The configureFailPoint command to be executed.
    let failPoint: BSONDocument

    /// Identifier for the session entity with which to set the fail point.
    let session: String

    static var knownArguments: Set<String> {
        ["failPoint", "session"]
    }
}
