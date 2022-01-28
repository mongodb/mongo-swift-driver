# Swift Driver Transactions Guide

`MongoSwift` 1.0.0 added support for [transactions](https://docs.mongodb.com/manual/core/transactions/), which allow applications to use to execute multiple read and write operations atomically across multiple documents and/or collections. Transactions reduce the need for complicated application logic when operating on several different documents simultaneously; however, because operations on single documents are always atomic, transactions are often not necessary.

Transactions in the driver must be started on a `ClientSession` using `startTransaction()`. *The session must then be passed to each operation in the transaction*. If the session is not passed to an operation, said operation will be executed outside the context of the transaction. Transactions must be committed or aborted using `commitTransaction()` or `abortTransaction()`, respectively. Ending a session *aborts* all in-progress transactions.

**Note**: Transactions only work with MongoDB replica sets (v4.0+) and sharded clusters (v4.2+).

## Examples

Below are some basic examples of using transactions in `MongoSwift`. In realistic use cases, transactions would ideally be retried when facing transient errors. For more detailed examples featuring retry logic, see the [official MongoDB documentation's examples](https://docs.mongodb.com/manual/core/transactions-in-applications/#txn-core-api). 

These examples use the driver's async/await APIs; for examples using `EventLoopFuture`s please see the [previous version of this guide](https://github.com/mongodb/mongo-swift-driver/blob/79c9683d56f92540f4065f40b9f55e1911a1ff5b/Guides/Transactions-Guide.md).

### Transaction that Atomically Moves a `Document` from One `MongoCollection` to Another

The transaction below atomically deletes the document `{ "hello": "world" }` from the collection `test.src` and inserts the document in the collection `test.dest`. This ensures that the document exists in either `test.src` or `test.dest`, but not both or neither. Executing the delete and insert non-atomically raises the following issues:
- A race between `deleteOne()` and `insertOne()` where the document does not exist in either collection.
- If `deleteOne()` fails and `insertOne()` succeeds, the document exists in both collections.
- If `deleteOne()` succeeds and `insertOne()` fails, the document does not exist in either collection.

In order to achieve the highest safety guarantees that MongoDB transactions offer, a "snapshot" read concern and a "majority" write concern must be used. To see the varying levels safety provided by different read concern / write concern configurations, see the [official MongoDB documentation](https://docs.mongodb.com/manual/core/transactions/#read-concern-write-concern-read-preference).

Transactions will inherit the read concern / write concern / read preference specified on the client that started the transaction's session unless they were also specified in either the default transaction options or in the transaction options passed to `startTransaction`. See the below sections on how to do either.

**Note:** All operations executed as part of a transaction will use the transaction's read concern / write concern / read preference. Any of those options specified on the database or collection that executes the operation or on a per-operation basis will be _ignored_.

```swift
let client = try MongoClient(
    "your-connection-string-here",
    using: yourEventLoopGroup,
    options: MongoClientOptions(readConcern: .snapshot, writeConcern: .majority)
)

let db = client.db("test")
let srcColl = db.collection("src")
let destColl = db.collection("dest")
let docToMove: BSONDocument = ["hello": "world"]

try await client.withSession { session in
    try await session.startTransaction()
    do {
        try await srcColl.deleteOne(docToMove, session: session)
        try await destColl.insertOne(docToMove, session: session)
        try await session.commitTransaction()
    } catch {
        try await session.abortTransaction()
        // handle error
    }
}
```

### Transaction with Default Transaction Options

The default transaction options specified below apply to any transaction started on the session.

```swift
let client = try MongoClient(
    "your-connection-string-here",
    using: yourEventLoopGroup
)

let txnOpts = TransactionOptions(
    maxCommitTimeMS: 30,
    readConcern: .snapshot,
    readPreference: .primary,
    writeConcern: .majority
)

try client.withSession(options: ClientSessionOptions(defaultTransactionOptions: txnOpts)) { session in
    try await session.startTransaction()
    do {
        // perform operations here
        try await session.commitTransaction()
    } catch {
        try await session.abortTransaction()
        // handle error
    }
}
```
### Transaction with Custom Transaction Options

**Note**: Any transaction options provided directly to `startTransaction()` override the default transaction options for the session. More so, the default transaction options for the session override any options inherited from the client.

```swift
let client = try MongoClient(
    "mongodb://localhost:27017,localhost:27018,localhost:27019/?replicaSet=b8510123-7f36-40f7-8437-bfb4ee70abbc",
    using: elg
)

let txnOpts = TransactionOptions(
    maxCommitTimeMS: 30,
    readConcern: .snapshot,
    readPreference: .primary,
    writeConcern: .majority
)

try await client.withSession { session in
    try await session.startTransaction(options: txnOpts)
    do {
        // perform operations here
        try await session.commitTransaction()
    } catch {
        try await session.abortTransaction()
        // handle error
    }
}
```

## See Also
- [MongoDB Transactions documentation](https://docs.mongodb.com/manual/core/transactions/)
- [MongoDB Driver Transactions Core API](https://docs.mongodb.com/manual/core/transactions-in-applications/#txn-core-api)
- [MongoDB Transactions and Read Concern / Write Concern / Read Preference](https://docs.mongodb.com/manual/core/transactions/#read-concern-write-concern-read-preference)
