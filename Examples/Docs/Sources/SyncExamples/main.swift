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
    var dbOptions = DatabaseOptions(
        readConcern: ReadConcern(.majority),
        writeConcern: try WriteConcern(w: .majority, wtimeoutMS: 1000)
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
        let pipeline: [Document] = [
            ["$match": ["fullDocument.username": "alice"]],
            ["$addFields": ["newField": "this is an added field!"]]
        ]
        let inventory = db.collection("inventory")
        let changeStream = try inventory.watch(pipeline, withEventType: Document.self)
        let next = changeStream.next()
        // End Changestream Example 4
    }
}
