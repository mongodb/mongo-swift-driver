# Using Change Streams

MongoSwift 0.2.0 added support for [change streams](https://docs.mongodb.com/manual/changeStreams/), which allow applications to access real-time data changes. Applications can use change streams to subscribe to all data changes on a single collection, a database, or an entire deployment, and immediately react to them. Because change streams use the aggregation framework, applications can also filter for specific changes or transform the notifications at will.

**Note**: Change streams only work with MongoDB replica sets and sharded clusters.

## Examples

### Open a Change Stream on a `MongoCollection<Document>` (MongoDB 3.6+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch().wait() // returns a `ChangeStream<ChangeStreamEvent<Document>>`

let future = stream.forEach { event in
    // process `ChangeStreamEvent<Document>` here
}

// perform some operations using `inventory`...

try future.wait()
```

### Open a Change Stream on a `MongoCollection<MyCodableType>` (MongoDB 3.6+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory", withType: MyCodableType.self)
let stream = try inventory.watch().wait() // returns a `ChangeStream<ChangeStreamEvent<MyCodableType>>`

let future = stream.forEach { event in
    // process `ChangeStreamEvent<MyCodableType>` here
}

// perform some operations using `inventory`...

try future.wait()
```

### Use a Custom `Codable` Type for the `fullDocument` Property of Returned `ChangeStreamEvent`s
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch(withFullDocumentType: MyCodableType.self).wait() // returns a `ChangeStream<ChangeStreamEvent<MyCodableType>>`

let future = stream.forEach { event in
    // process `ChangeStreamEvent<MyCodableType>` here
}

// perform some operations using `inventory`...

try future.wait()
```

### Use a Custom `Codable` Type for the Return type of `ChangeStream.next()`
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch(withEventType: MyCodableType.self).wait() // returns a `ChangeStream<MyCodableType>`

let future = stream.forEach { type in
    // process `MyCodableType` here
}

// perform some operations using `inventory`...

try future.wait()
```

### Open a Change Stream on a `MongoDatabase` (MongoDB 4.0+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let db = client.db("example")
let stream = try db.watch().wait() // returns a `ChangeStream<ChangeStreamEvent<Document>>`

let future = stream.forEach { event in
    // process `ChangeStreamEvent<Document>` here
}

// perform some operations using `db`...

try future.wait()
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Open a Change Stream on a `MongoClient` (MongoDB 4.0+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let stream = try client.watch().wait() // returns a `ChangeStream<ChangeStreamEvent<Document>>`

let future = stream.forEach { event in
    // process `ChangeStreamEvent<Document>` here
}

// perform some operations using `client`...

try future.wait()
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Resume a Change Stream
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")
let stream = try inventory.watch().wait() // returns a `ChangeStream<ChangeStreamEvent<Document>>`

// perform some operations using `inventory`...

// read the first change event
let next = try stream.next().wait()

// create a new change stream that starts after the first change event
let resumeToken = stream.resumeToken
let resumedStream = try inventory.watch(options: ChangeStreamOptions(resumeAfter: resumeToken)).wait()

let future = resumedStream.forEach { event in
    // process `ChangeStreamEvent<Document>` here
}

try future.wait()
```

### Modify Change Stream Output
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")

// Only include events where the changed document's username = "alice"
let pipeline: [Document] = [
    ["$match": ["fullDocument.username": "alice"] as Document]
]

let stream = try inventory.watch(pipeline).wait() // returns a `ChangeStream<ChangeStreamEvent<Document>>`

let future = stream.forEach { event in
    // process `ChangeStreamEvent<Document>` here
}

// perform some operations using `inventory`...

try future.wait()
```

## See Also
- [MongoDB Change Streams documentation](https://docs.mongodb.com/manual/changeStreams/)