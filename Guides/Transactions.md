# Swift Driver Transactions Guide

`MongoSwift` 1.0.0 added support for [transactions](https://docs.mongodb.com/manual/core/transactions/), which allow applications to use to execute multiple read and write operations atomically across multiple documents and/or collections. Transactions reduce the need for complicated application logic when operating on several different documents simultaneously; however, because operations on single documents are always atomic, transactions are often not necessary.

Transactions in the driver must be started on a `ClientSession` using `startTransaction()`. The session must then be passed to each operation in the transaction. If the session is not passed to an operation, said operation will be executed outside the context of the transaction. Transactions must be committed or aborted using `commitTransaction()` or `abortTransaction()`, respectively. Ending a session *aborts* all in-progress transactions.

**Note**: Transactions only work with MongoDB replica sets (v4.0+) and sharded clusters (v4.2+).

## Examples

Below are some basic examples of using transactions in `MongoSwift`. In realistic use cases, transactions would ideally be retried when facing transient errors. For more detailed examples featuring retry logic, see the [official MongoDB documentation's examples](https://docs.mongodb.com/manual/core/transactions-in-applications/#txn-core-api). 

### Transaction that Atomically Moves a `Document` from One `MongoCollection` to Another

The transaction below atomically deletes the document `{ "hello": "world" }` from the collection `test.src` and inserts the document in the collection `test.dest`. This ensures that the document exists in either `test.src` or `test.dest`, but not both or neither. Executing the delete and insert non-atomically raises the following issues:
- A race between `deleteOne()` and `insertOne()` where the document does not exist in either collection.
- If `deleteOne()` fails and `insertOne()` succeeds, the document exists in both collections.
- If `deleteOne()` succeeds and `insertOne()` fails, the document does not exist in either collection.

```swift
let client = try MongoClient(using: elg)
let session = client.startSession()

let db = client.db("test")
let srcColl = db.collection("src")
let destColl = db.collection("dest")
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

### Transaction with Default Transaction Options

The default transaction options specified below apply to any transaction started on the session.

```swift
let txnOpts = TransactionOptions(
    maxCommitTimeMS: 30,
    readConcern: ReadConcern(.local),
    readPreference: .primaryPreferred,
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

### Transaction with Custom Transaction Options

**Note**:: Any transaction options provided directly to `startTransaction()` override the default transaction options for the session. More so, the default transaction options for the session override any options inherited from the client.

```swift
let client = try MongoClient(using: elg)
let session = client.startSession()

let txnOpts = TransactionOptions(
    maxCommitTimeMS: 30,
    readConcern: ReadConcern(.local),
    readPreference: .primaryPreferred,
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

## See Also
- [MongoDB Transactions documentation](https://docs.mongodb.com/manual/core/transactions/)
- [MongoDB Driver Transactions Core API](https://docs.mongodb.com/manual/core/transactions-in-applications/#txn-core-api)
