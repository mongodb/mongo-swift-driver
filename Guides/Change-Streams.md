# Using Change Streams

MongoSwift 0.2.0 added support for [change streams](https://docs.mongodb.com/manual/changeStreams/), which allow applications to access real-time data changes. Applications can use change streams to subscribe to all data changes on a single collection, a database, or an entire deployment, and immediately react to them. Because change streams use the aggregation framework, applications can also filter for specific changes or transform the notifications at will.

**Note**: Change streams only work with MongoDB replica sets and sharded clusters.

## Examples

### Open a Change Stream on a `MongoCollection<Document>` (MongoDB 3.6+)
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let cursor = try inventory.watch() // returns a `ChangeStream<ChangeStreamEvent<Document>>`

// perform some operations using `inventory`...

for change in cursor {
    // process `ChangeStreamEvent<Document>` here
}
```

### Open a Change Stream on a `MongoCollection<MyCodableType>` (MongoDB 3.6+)
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory", withType: MyCodableType.self)
let cursor = try inventory.watch() // returns a `ChangeStream<ChangeStreamEvent<MyCodableType>>`

// perform some operations using `inventory`...

for change in cursor {
    // process `ChangeStreamEvent<MyCodableType>` here
}
```

### Use a Custom `Codable` Type for the `fullDocument` Property of Returned `ChangeStreamEvent`s
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let cursor = try inventory.watch(withFullDocumentType: MyCodableType.self) // returns a `ChangeStream<ChangeStreamEvent<MyCodableType>>`

// perform some operations using `inventory`...

for change in cursor {
    // process `ChangeStreamEvent<MyCodableType>` here
}
```

### Use a Custom `Codable` Type for the Return type of `ChangeStream.next()`
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let cursor = try inventory.watch(withEventType: MyCodableType.self) // returns a `ChangeStream<MyCodableType>`

// perform some operations using `inventory`...

for change in cursor {
    // process `MyCodableType` here
}
```

### Open a Change Stream on a `MongoDatabase` (MongoDB 4.0+)
```swift
let client = try MongoClient()
let db = client.db("example")
let cursor = try db.watch()

// perform some operations using `db`...

for change in cursor {
    // process `ChangeStreamEvent<Document>` here
}
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Open a Change Stream on a `MongoClient` (MongoDB 4.0+)
```swift
let client = try MongoClient()
let cursor = try client.watch()

// perform some operations using `client`...

for change in cursor {
    // process `ChangeStreamEvent<Document>` here
}
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Resume a Change Stream
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let cursor = try inventory.watch()

// perform some operations using `inventory`...

// read the first change event
let next = try cursor.nextOrError()

// create a new change stream that starts after the first change event
let resumeToken = next?.resumeToken
let resumedChangeStream = try inventory.watch(options: ChangeStreamOptions(resumeAfter: resumeToken))
for change in resumedChangeStream {
    // process `ChangeStreamEvent<Document>` here
}
```

## See Also
- [MongoDB Change Streams documentation](https://docs.mongodb.com/manual/changeStreams/)