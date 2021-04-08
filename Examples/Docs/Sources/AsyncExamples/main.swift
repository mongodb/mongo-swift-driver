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
        try? client1.syncClose()
        try? elg.syncShutdownGracefully()
    }

    // Start Causal Consistency Example 1
    let s1 = client1.startSession(options: ClientSessionOptions(causalConsistency: true))
    let currentDate = Date()
    var dbOptions = MongoDatabaseOptions(
        readConcern: .majority,
        writeConcern: try .majority(wtimeoutMS: 1000)
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

        dbOptions.readPreference = .secondary
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
        let pipeline: [BSONDocument] = [
            ["$match": ["fullDocument.username": "alice"]],
            ["$addFields": ["newField": "this is an added field!"]]
        ]
        let inventory = db.collection("inventory")

        // Option 1: use next() to iterate
        let next = inventory.watch(pipeline, withEventType: BSONDocument.self).flatMap { changeStream in
            changeStream.next()
        }

        // Option 2: register a callback to execute for each document
        let result = inventory.watch(pipeline, withEventType: BSONDocument.self).flatMap { changeStream in
            changeStream.forEach { event in
                // process event
                print(event)
            }
        }
        // End Changestream Example 4
    }
}

/// Examples used for the MongoDB documentation on transactions.
/// - SeeAlso: https://docs.mongodb.com/manual/core/transactions-in-applications/
private func transactions() throws {
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let client = try MongoClient(using: elg)

    // Start Transactions Into Example 1
    func updateEmployeeInfo(session: ClientSession) -> EventLoopFuture<Void> {
        let employees = client.db("hr").collection("employees")
        let events = client.db("reporting").collection("events")

        let options = TransactionOptions(readConcern: .snapshot, writeConcern: .majority)
        return session.startTransaction(options: options).flatMap {
            employees.updateOne(
                filter: ["employee": 3],
                update: ["$set": ["status": "Inactive"]],
                session: session
            ).flatMap { _ in
                events.insertOne(["employee": 3, "status": ["new": "Inactive", "old": "Active"]])
            }.flatMapError { error in
                print("Caught error during transaction, aborting")
                return session.abortTransaction().flatMapThrowing { _ in
                    throw error
                }
            }
        }.flatMap { _ in
            commitWithRetry(session: session)
        }
    }
    // End Transactions Intro Example 1

    // Start Transactions Retry Example 1
    func runTransactionWithRetry(
        session: ClientSession,
        txnFunc: @escaping (ClientSession) -> EventLoopFuture<Void>
    ) -> EventLoopFuture<Void> {
        let txnFuture = txnFunc(session)
        let eventLoop = txnFuture.eventLoop
        return txnFuture.flatMapError { error in
            guard
                let labeledError = error as? MongoLabeledError,
                labeledError.errorLabels?.contains("TransientTransactionError") == true
            else {
                return eventLoop.makeFailedFuture(error)
            }
            print("TransientTransactionError, retrying transaction...")
            return runTransactionWithRetry(session: session, txnFunc: txnFunc)
        }
    }
    // End Transactions Retry Example 1

    // Start Transactions Retry Example 2
    func commitWithRetry(session: ClientSession) -> EventLoopFuture<Void> {
        let commitFuture = session.commitTransaction()
        let eventLoop = commitFuture.eventLoop
        return commitFuture.flatMapError { error in
            guard
                let labeledError = error as? MongoLabeledError,
                labeledError.errorLabels?.contains("UnknownTransactionCommitResult") == true
            else {
                print("Error during commit...")
                return eventLoop.makeFailedFuture(error)
            }
            print("UnknownTransactionCommitResult, retrying commit operation...")
            return commitWithRetry(session: session)
        }
    }
    // End Transactions Retry Example 2

    // Start Transactions Retry Example 3
    try client.withSession { session in
        runTransactionWithRetry(session: session, txnFunc: updateEmployeeInfo).flatMapErrorThrowing { _ in
            // do something with error
        }
    }.wait()
    // End Transactions Retry Example 3
}

private func versionedAPI() throws {
    let uri = "mongodb://localhost:27017"
    let myEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer { try? myEventLoopGroup.syncShutdownGracefully() }

    do {
        // Start Versioned API Example 1

        // Declare API version "1" for the client
        var clientOpts = MongoClientOptions()
        clientOpts.serverAPI = MongoServerAPI(version: .v1)
        let client = try MongoClient(uri, using: myEventLoopGroup, options: clientOpts)
        // End Versioned API Example 1

        try client.syncClose()
    }

    do {
        // Start Versioned API Example 2

        // Use the `strict` option
        var opts = MongoClientOptions()
        opts.serverAPI = MongoServerAPI(version: .v1, strict: true)
        let client = try MongoClient(uri, using: myEventLoopGroup, options: opts)

        var findOpts = FindOptions()
        findOpts.cursorType = .tailable
        // Fails with an error because `tailable` is not part of version 1
        do {
            let cursor = try client.db("db").collection("coll").find(options: findOpts).wait()
        } catch {
            // error
        }
        // End Versioned API Example 2

        try client.syncClose()
    }

    do {
        // Start Versioned API Example 3

        // Use the `deprecationErrors` option
        var opts = MongoClientOptions()
        opts.serverAPI = MongoServerAPI(version: .v1, deprecationErrors: true)
        let client = try MongoClient(uri, using: myEventLoopGroup, options: opts)
        // End Versioned API Example 3

        try client.syncClose()
    }
}
