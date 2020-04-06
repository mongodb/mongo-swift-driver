# Swift Driver Transactions Guide

`MongoSwift` 1.0.0 added support for [transactions](https://docs.mongodb.com/manual/core/transactions/), which allow applications to use multi-statement transactions that guarantee the atomicity of reads and writes to multiple documents (in a single or multiple collections). Applications can use transactions instead of implementing complex and error-prone ACID-compliant logic themselves, simplifying development and allowing developers to focus on the new features that really matter.

**Note**: Transactions only work with MongoDB replica sets (v4.0+) and sharded clusters (v4.2+).

## Examples

### Transaction that Atomically Moves a `Document` from One `MongoCollection` to Another
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)

defer {
    // free driver resources
    client.syncShutdown()
    cleanupMongoSwift()

    // shut down EventLoopGroup
    try? elg.syncShutdownGracefully()
}

let client = try MongoClient(using: elg)
let session = client.startSession()

let db = client.db("test")
let srcColl = db.collection("src")
let destColl = db.collection("coll")
let docToMove: Document = ["hello": "world"]

session.startTransaction().flatMap { _ in
    srcColl.deleteOne(docToMove, session: session)
}.flatMap { _ in
    destColl.insertOne(docToMove, session: session)
}.flatMap { _ in
    session.commitTransaction()
}.whenFailure { error in
    session.abortTransaction()
    // handle error
}
```

### Transaction with Custom Transaction Options
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)

defer {
    // free driver resources
    client.syncShutdown()
    cleanupMongoSwift()

    // shut down EventLoopGroup
    try? elg.syncShutdownGracefully()
}

let client = try MongoClient(using: elg)
let session = client.startSession()

let txnOpts = TransactionOptions(
    maxCommitTimeMS: 30,
    readConcern: ReadConcern(.local),
    readPreference: ReadPreference.primaryPreferred,
    writeConcern: try WriteConcern(w: .majority)
)

session.startTransaction(options: txnOpts).flatMap { _ in
    // do something
}.flatMap { _ in
    session.commitTransaction()
}.whenFailure { error in
    session.abortTransaction()
    // handle error
}
```

### Transaction with Default Transaction Options
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)

defer {
    // free driver resources
    client.syncShutdown()
    cleanupMongoSwift()

    // shut down EventLoopGroup
    try? elg.syncShutdownGracefully()
}

let txnOpts = TransactionOptions(
    maxCommitTimeMS: 30,
    readConcern: ReadConcern(.local),
    readPreference: ReadPreference.primaryPreferred,
    writeConcern: try WriteConcern(w: .majority)
)

let client = try MongoClient(using: elg)
let session = client.startSession(options: ClientSessionOptions(defaultTransactionOptions: txnOpts))

session.startTransaction().flatMap { _ in
    // do something
}.flatMap { _ in
    session.commitTransaction()
}.whenFailure { error in
    session.abortTransaction()
    // handle error
}
```

Note: Any transaction options provided directly to `startTransaction()` override the default transaction options for the session. More so, the default transaction options for the session override any options inherited from the client.

## See Also
- [MongoDB Transactions documentation](https://docs.mongodb.com/manual/core/transactions/)