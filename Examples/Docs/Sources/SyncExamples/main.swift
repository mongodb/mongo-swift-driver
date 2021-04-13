import Foundation
import MongoSwiftSync

// swiftlint:disable force_unwrapping

/// Examples used for the MongoDB documentation on Causal Consistency.
/// - SeeAlso: https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/#examples
private func causalConsistency() throws {
    let client1 = try MongoClient()

    // Start Causal Consistency Example 1
    let s1 = client1.startSession(options: ClientSessionOptions(causalConsistency: true))
    let currentDate = Date()
    var dbOptions = MongoDatabaseOptions(
        readConcern: .majority,
        writeConcern: try .majority(wtimeoutMS: 1000)
    )
    let items = client1.db("test", options: dbOptions).collection("items")
    try items.updateOne(
        filter: ["sku": "111", "end": .null],
        update: ["$set": ["end": .datetime(currentDate)]],
        session: s1
    )
    try items.insertOne(["sku": "nuts-111", "name": "Pecans", "start": .datetime(currentDate)], session: s1)
    // End Causal Consistency Example 1

    let client2 = try MongoClient()

    // Start Causal Consistency Example 2
    try client2.withSession(options: ClientSessionOptions(causalConsistency: true)) { s2 in
        // The cluster and operation times are guaranteed to be non-nil since we already used s1 for operations above.
        s2.advanceClusterTime(to: s1.clusterTime!)
        s2.advanceOperationTime(to: s1.operationTime!)

        dbOptions.readPreference = .secondary
        let items2 = client2.db("test", options: dbOptions).collection("items")
        for item in try items2.find(["end": .null], session: s2) {
            print(item)
        }
    }
    // End Causal Consistency Example 2
}

/// Examples used for the MongoDB documentation on Change Streams.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
private func changeStreams() throws {
    let client = try MongoClient()
    let db = client.db("example")

    // The following examples assume that you have connected to a MongoDB replica set and have
    // accessed a database that contains an inventory collection.

    do {
        // Start Changestream Example 1
        let inventory = db.collection("inventory")
        let changeStream = try inventory.watch()
        let next = changeStream.next()
        // End Changestream Example 1
    }

    do {
        // Start Changestream Example 2
        let inventory = db.collection("inventory")
        let changeStream = try inventory.watch(options: ChangeStreamOptions(fullDocument: .updateLookup))
        let next = changeStream.next()
        // End Changestream Example 2
    }

    do {
        // Start Changestream Example 3
        let inventory = db.collection("inventory")
        let changeStream = try inventory.watch(options: ChangeStreamOptions(fullDocument: .updateLookup))
        let next = changeStream.next()

        let resumeToken = changeStream.resumeToken
        let resumedChangeStream = try inventory.watch(options: ChangeStreamOptions(resumeAfter: resumeToken))
        let nextAfterResume = resumedChangeStream.next()
        // End Changestream Example 3
    }

    do {
        // Start Changestream Example 4
        let pipeline: [BSONDocument] = [
            ["$match": ["fullDocument.username": "alice"]],
            ["$addFields": ["newField": "this is an added field!"]]
        ]
        let inventory = db.collection("inventory")
        let changeStream = try inventory.watch(pipeline, withEventType: BSONDocument.self)
        let next = changeStream.next()
        // End Changestream Example 4
    }
}

/// Examples used for the MongoDB documentation on transactions.
/// - SeeAlso: https://docs.mongodb.com/manual/core/transactions-in-applications/
private func transactions() throws {
    // Start Transactions Intro Example 1
    func updateEmployeeInfo(session: ClientSession) throws {
        let employees = session.client.db("hr").collection("employees")
        let events = session.client.db("reporting").collection("events")

        do {
            try employees.updateOne(filter: ["employee": 3], update: ["$set": ["status": "Inactive"]], session: session)
            try events.insertOne(["employee": 3, "status": ["new": "Inactive", "old": "Active"]], session: session)
        } catch {
            print("Caught error during transaction, aborting")
            try session.abortTransaction()
            throw error
        }
        try commitWithRetry(session: session)
    }
    // End Transactions Intro Example 1

    // Start Transactions Retry Example 1
    func runTransactionWithRetry(session: ClientSession, txnFunc: @escaping (ClientSession) throws -> Void) throws {
        while true {
            do {
                return try txnFunc(session) // performs transaction
            } catch {
                print("Transaction aborted. Caught exception during transaction.")
                guard
                    let labeledError = error as? MongoLabeledError,
                    labeledError.errorLabels?.contains("TransientTransactionError") == true
                else {
                    throw error
                }
                // If transient error, retry the whole transaction
                print("TransientTransactionError, retrying transaction ...")
                continue
            }
        }
    }
    // End Transactions Retry Example 1

    // Start Transactions Retry Example 2
    func commitWithRetry(session: ClientSession) throws {
        while true {
            do {
                try session.commitTransaction() // Uses write concern set at transaction start
                print("Transaction committed.")
                break
            } catch {
                guard
                    let labeledError = error as? MongoLabeledError,
                    labeledError.errorLabels?.contains("UnknownTransactionCommitResult") == true
                else {
                    print("Error during commit ...")
                    throw error
                }
                print("UnknownTransactionCommitResult, retrying commit operation ...")
                continue
            }
        }
    }
    // End Transactions Retry Example 2

    let client = try MongoClient()
    // Start Transactions Retry Example 3
    client.withSession { session in
        do {
            try runTransactionWithRetry(session: session, txnFunc: updateEmployeeInfo)
        } catch {
            // do something with error
        }
    }
    // End Transactions Retry Example 3
}

private func versionedAPI() throws {
    let uri = "mongodb://localhost:27017"

    do {
        // Start Versioned API Example 1

        // Declare API version "1" for the client
        var clientOpts = MongoClientOptions()
        clientOpts.serverAPI = MongoServerAPI(version: .v1)
        let client = try MongoClient(uri, options: clientOpts)
        // End Versioned API Example 1
    }

    do {
        // Start Versioned API Example 2

        // Use the `strict` option
        var opts = MongoClientOptions()
        opts.serverAPI = MongoServerAPI(version: .v1, strict: true)
        let client = try MongoClient(uri, options: opts)

        var findOpts = FindOptions()
        findOpts.cursorType = .tailable
        // Fails with an error because `tailable` is not part of version 1
        do {
            let cursor = try client.db("db").collection("coll").find(options: findOpts)
        } catch {
            // error
        }

        // End Versioned API Example 2
    }

    do {
        // Start Versioned API Example 3

        // Use the `deprecationErrors` option
        var opts = MongoClientOptions()
        opts.serverAPI = MongoServerAPI(version: .v1, deprecationErrors: true)
        let client = try MongoClient(uri, options: opts)
        // End Versioned API Example 3
    }
}
