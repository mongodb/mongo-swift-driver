// Example used for the MongoDB documentation on Causal Consistency.
// https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/#examples

// Start example 1
let client1 = try MongoClient()
let s1 = try client1.startSession(options: ClientSessionOptions(causalConsistency: true))
let currentDate = Date()
var dbOptions = DatabaseOptions(readConcern: ReadConcern(.majority),
                                writeConcern: try WriteConcern(w: .majority, wtimeoutMS: 1000))
let items = client1.db("test", options: dbOptions).collection("items")
try items.updateOne(filter: ["sku": "111", "end": BSONNull()],
                    update: ["$set": ["end": currentDate] as Document],
                    session: s1)
try items.insertOne(["sku": "nuts-111", "name": "Pecans", "start": currentDate], session: s1)

// Start example 2
let client2 = try MongoClient()
try client2.withSession(options: ClientSessionOptions(causalConsistency: true)) { s2 in
    s2.advanceClusterTime(to: s1.clusterTime!)
    s2.advanceOperationTime(to: s1.operationTime!)

    dbOptions.readPreference = ReadPreference(.secondary)
    let items2 = client2.db("test", options: dbOptions).collection("items")
    for item in try items2.find(["end": BSONNull()], session: s2) {
        print(item)
    }
}
