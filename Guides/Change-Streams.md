# Using Change Streams

MongoSwift 0.2.0 added support for [change streams](https://docs.mongodb.com/manual/changeStreams/), which allow applications to access real-time data changes. Applications can use change streams to subscribe to all data changes on a single collection, a database, or an entire deployment, and immediately react to them. Because change streams use the aggregation framework, applications can also filter for specific changes or transform the notifications at will.

**Note**: Change streams only work with MongoDB replica sets and sharded clusters.

## Examples

### Open a Change Stream on a `MongoCollection<Document>` (MongoDB 3.6+)
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch() // returns a `ChangeStream<ChangeStreamEvent<Document>>`

// perform some operations using `inventory`...

for change in stream {
    // process `ChangeStreamEvent<Document>` here
}

// check if any errors occurred while iterating
if let error = stream.error {
    // handle error
}
```

### Open a Change Stream on a `MongoCollection<MyCodableType>` (MongoDB 3.6+)
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory", withType: MyCodableType.self)
let stream = try inventory.watch() // returns a `ChangeStream<ChangeStreamEvent<MyCodableType>>`

// perform some operations using `inventory`...

for change in stream {
    // process `ChangeStreamEvent<MyCodableType>` here
}

// check if any errors occurred while iterating
if let error = stream.error {
    // handle error
}
```

### Use a Custom `Codable` Type for the `fullDocument` Property of Returned `ChangeStreamEvent`s
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch(withFullDocumentType: MyCodableType.self) // returns a `ChangeStream<ChangeStreamEvent<MyCodableType>>`

// perform some operations using `inventory`...

for change in stream {
    // process `ChangeStreamEvent<MyCodableType>` here
}

// check if any errors occurred while iterating
if let error = stream.error {
    // handle error
}
```

### Use a Custom `Codable` Type for the Return type of `ChangeStream.next()`
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch(withEventType: MyCodableType.self) // returns a `ChangeStream<MyCodableType>`

// perform some operations using `inventory`...

for change in stream {
    // process `MyCodableType` here
}

// check if any errors occurred while iterating
if let error = stream.error {
    // handle error
}
```

### Open a Change Stream on a `MongoDatabase` (MongoDB 4.0+)
```swift
let client = try MongoClient()
let db = client.db("example")
let stream = try db.watch()

// perform some operations using `db`...

for change in stream {
    // process `ChangeStreamEvent<Document>` here
}

// check if any errors occurred while iterating
if let error = stream.error {
    // handle error
}
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Open a Change Stream on a `MongoClient` (MongoDB 4.0+)
```swift
let client = try MongoClient()
let stream = try client.watch()

// perform some operations using `client`...

for change in stream {
    // process `ChangeStreamEvent<Document>` here
}

// check if any errors occurred while iterating
if let error = stream.error {
    // handle error
}
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Resume a Change Stream
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch()

// perform some operations using `inventory`...

// read the first change event
let next = try stream.nextOrError()

// create a new change stream that starts after the first change event
let resumeToken = stream.resumeToken
let resumedStream = try inventory.watch(options: ChangeStreamOptions(resumeAfter: resumeToken))
for change in resumedStream {
    // process `ChangeStreamEvent<Document>` here
}

// check if any errors occurred while iterating
if let error = resumedStream.error {
    // handle error
}
```

### Modify Change Stream Output
```swift
let client = try MongoClient()
let inventory = client.db("example").collection("inventory")

// Only include events where the changed document's username = "alice"
let pipeline: [Document] = [
    ["$match": ["fullDocument.username": "alice"] as Document]
]

let stream = try inventory.watch(pipeline)
for change in stream {
    // process `ChangeStreamEvent<Document>` here
}

// check if any errors occurred while iterating
if let error = stream.error {
    // handle error
}
```

## See Also
- [MongoDB Change Streams documentation](https://docs.mongodb.com/manual/changeStreams/)