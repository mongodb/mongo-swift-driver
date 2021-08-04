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

        let opts = MongoClientOptions(
            serverAPI: MongoServerAPI(version: .v1)
        )
        let client = try MongoClient(uri, using: myEventLoopGroup, options: opts)

        // End Versioned API Example 1

        try client.syncClose()
    }

    do {
        // Start Versioned API Example 2

        let opts = MongoClientOptions(
            serverAPI: MongoServerAPI(version: .v1, strict: true)
        )
        let client = try MongoClient(uri, using: myEventLoopGroup, options: opts)

        // End Versioned API Example 2

        try client.syncClose()
    }

    do {
        // Start Versioned API Example 3

        let opts = MongoClientOptions(
            serverAPI: MongoServerAPI(version: .v1, strict: false)
        )
        let client = try MongoClient(uri, using: myEventLoopGroup, options: opts)

        // End Versioned API Example 3

        try client.syncClose()
    }

    do {
        // Start Versioned API Example 4

        let opts = MongoClientOptions(
            serverAPI: MongoServerAPI(version: .v1, deprecationErrors: true)
        )
        let client = try MongoClient(uri, using: myEventLoopGroup, options: opts)

        // End Versioned API Example 3

        try client.syncClose()
    }
}

private func versionedAPIMigrationExample() throws {
    let myEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let options = MongoClientOptions(
        serverAPI: MongoServerAPI(version: .v1, strict: true)
    )
    let client = try MongoClient(using: myEventLoopGroup, options: options)
    try client.db("test").drop().wait()

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime]

    // swiftlint:disable line_length
    // 1. Populate a test sales collection
    let insertResult = client.db("test").collection("sales").insertMany([
        ["_id": 1, "item": "abc", "price": 10, "quantity": 2, "date": .datetime(dateFormatter.date(from: "2021-01-01T08:00:00Z")!)],
        ["_id": 2, "item": "jkl", "price": 20, "quantity": 1, "date": .datetime(dateFormatter.date(from: "2021-02-03T09:00:00Z")!)],
        ["_id": 3, "item": "xyz", "price": 5, "quantity": 5, "date": .datetime(dateFormatter.date(from: "2021-02-03T09:00:00Z")!)],
        ["_id": 4, "item": "abc", "price": 10, "quantity": 10, "date": .datetime(dateFormatter.date(from: "2021-02-15T08:00:00Z")!)],
        ["_id": 5, "item": "xyz", "price": 5, "quantity": 10, "date": .datetime(dateFormatter.date(from: "2021-02-15T09:05:00Z")!)],
        ["_id": 6, "item": "xyz", "price": 5, "quantity": 5, "date": .datetime(dateFormatter.date(from: "2021-02-15T12:05:10Z")!)],
        ["_id": 7, "item": "xyz", "price": 5, "quantity": 10, "date": .datetime(dateFormatter.date(from: "2021-02-15T14:12:12Z")!)],
        ["_id": 8, "item": "abc", "price": 10, "quantity": 5, "date": .datetime(dateFormatter.date(from: "2021-03-16T20:20:13Z")!)]
    ])
    // End step 1
    // swiftlint:enable line_length

    try insertResult.wait()

    // 2. Run "count" using a strict client, observe error
    let countResult = client.db("test").runCommand(["count": "sales"])

    countResult.whenFailure { error in
        print(error) // prints:
        // MongoSwift.MongoError.CommandError(
        //     code: 323,
        //     codeName: "APIStrictError",
        //     message: "Provided apiStrict:true, but the command count is not in API Version 1",
        //     errorLabels: nil
        // )
    }
    // End step 2

    try? countResult.wait()

    // 3. New way to count documents
    let newCountResult = client.db("test").collection("sales").countDocuments()
    newCountResult.whenSuccess { result in
        print(result) // prints: 8
    }
    // End step 3

    try newCountResult.wait()
    try client.syncClose()
}
