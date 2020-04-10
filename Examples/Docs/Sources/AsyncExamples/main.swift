import Foundation
import MongoSwift
import NIO

// swiftlint:disable force_unwrapping

/// Examples used for the MongoDB documentation on Causal Consistency.
/// - SeeAlso: https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/#examples
private func causalConsistency() throws {
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let client1 = try MongoClient(using: elg)
    defer {
        client1.syncShutdown()
        try? elg.syncShutdownGracefully()
    }

    // Start Causal Consistency Example 1
    let s1 = client1.startSession(options: ClientSessionOptions(causalConsistency: true))
    let currentDate = Date()
    var dbOptions = DatabaseOptions(
        readConcern: ReadConcern(.majority),
        writeConcern: try WriteConcern(w: .majority, wtimeoutMS: 1000)
    )
    let items = client1.db("test", options: dbOptions).collection("items")
    let result1 = items.updateOne(
        filter: ["sku": "111", "end": .null],
        update: ["$set": ["end": .datetime(currentDate)]],
        session: s1
    ).flatMap { _ in
        items.insertOne(["sku": "nuts-111", "name": "Pecans", "start": .datetime(currentDate)], session: s1)
    }
    // End Causal Consistency Example 1

    let client2 = try MongoClient(using: elg)

    // Start Causal Consistency Example 2
    let options = ClientSessionOptions(causalConsistency: true)
    let result2: EventLoopFuture<Void> = client2.withSession(options: options) { s2 in
        // The cluster and operation times are guaranteed to be non-nil since we already used s1 for operations above.
        s2.advanceClusterTime(to: s1.clusterTime!)
        s2.advanceOperationTime(to: s1.operationTime!)

        dbOptions.readPreference = ReadPreference(.secondary)
        let items2 = client2.db("test", options: dbOptions).collection("items")

        return items2.find(["end": .null], session: s2).flatMap { cursor in
            cursor.forEach { item in
                print(item)
            }
        }
    }
    // End Causal Consistency Example 2
}

/// Examples used for the MongoDB documentation on Change Streams.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
private func changeStreams() throws {
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let client = try MongoClient(using: elg)
    let db = client.db("example")

    // The following examples assume that you have connected to a MongoDB replica set and have
    // accessed a database that contains an inventory collection.

    do {
        // Start Changestream Example 1
        let inventory = db.collection("inventory")

        // Option 1: retrieve next document via next()
        let next = inventory.watch().flatMap { cursor in
            cursor.next()
        }

        // Option 2: register a callback to execute for each document
        let result = inventory.watch().flatMap { cursor in
            cursor.forEach { event in
                // process event
                print(event)
            }
        }
        // End Changestream Example 1
    }

    do {
        // Start Changestream Example 2
        let inventory = db.collection("inventory")

        // Option 1: use next() to iterate
        let next = inventory.watch(options: ChangeStreamOptions(fullDocument: .updateLookup))
            .flatMap { changeStream in
                changeStream.next()
            }

        // Option 2: register a callback to execute for each document
        let result = inventory.watch(options: ChangeStreamOptions(fullDocument: .updateLookup))
            .flatMap { changeStream in
                changeStream.forEach { event in
                    // process event
                    print(event)
                }
            }
        // End Changestream Example 2
    }

    do {
        // Start Changestream Example 3
        let inventory = db.collection("inventory")

        inventory.watch(options: ChangeStreamOptions(fullDocument: .updateLookup))
            .flatMap { changeStream in
                changeStream.next().map { _ in
                    changeStream.resumeToken
                }.always { _ in
                    _ = changeStream.kill()
                }
            }.flatMap { resumeToken in
                inventory.watch(options: ChangeStreamOptions(resumeAfter: resumeToken)).flatMap { newStream in
                    newStream.forEach { event in
                        // process event
                        print(event)
                    }
                }
            }
        // End Changestream Example 3
    }

    do {
        // Start Changestream Example 4
        let pipeline: [Document] = [
            ["$match": ["fullDocument.username": "alice"]],
            ["$addFields": ["newField": "this is an added field!"]]
        ]
        let inventory = db.collection("inventory")

        // Option 1: use next() to iterate
        let next = inventory.watch(pipeline, withEventType: Document.self).flatMap { changeStream in
            changeStream.next()
        }

        // Option 2: register a callback to execute for each document
        let result = inventory.watch(pipeline, withEventType: Document.self).flatMap { changeStream in
            changeStream.forEach { event in
                // process event
                print(event)
            }
        }
        // End Changestream Example 4
    }
}

/// Examples used for the MongoDB documentation on Transactions.
/// - SeeAlso: https://docs.mongodb.com/manual/core/transactions/
private func transactions() throws {
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let client = try MongoClient(using: elg)
    let session = client.startSession()

    defer {
        client.syncShutdown()
        cleanupMongoSwift()
        try? elg.syncShutdownGracefully()
    }

    do {
        // Start Transactions Example 1
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
        // End Transactions Example 1
    }

    do {
        // Start Transactions Example 2
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
        // End Transactions Example 2
    }

    do {
        // Start Transactions Example 3
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
        // End Transactions Example 3
    }
}
