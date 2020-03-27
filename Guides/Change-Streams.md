# Using Change Streams

MongoSwift 0.2.0 added support for [change streams](https://docs.mongodb.com/manual/changeStreams/), which allow applications to access real-time data changes. Applications can use change streams to subscribe to all data changes on a single collection, a database, or an entire deployment, and immediately react to them. Because change streams use the aggregation framework, applications can also filter for specific changes or transform the notifications at will.

**Note**: Change streams only work with MongoDB replica sets and sharded clusters.

## Examples

### Open a Change Stream on a `MongoCollection<Document>` (MongoDB 3.6+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")

inventory.watch().flatMap { stream in // a `ChangeStream<ChangeStreamEvent<Document>>`
    stream.forEach { event in
        // process `ChangeStreamEvent<Document>` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `inventory`...
```

### Open a Change Stream on a `MongoCollection<MyCodableType>` (MongoDB 3.6+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory", withType: MyCodableType.self)

inventory.watch().flatMap { stream in // a `ChangeStream<ChangeStreamEvent<MyCodableType>>`
    stream.forEach { event in
        // process `ChangeStreamEvent<MyCodableType>` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `inventory`...
```

### Use a Custom `Codable` Type for the `fullDocument` Property of Returned `ChangeStreamEvent`s
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")

inventory.watch(withFullDocumentType: MyCodableType.self).flatMap { stream in // a `ChangeStream<ChangeStreamEvent<MyCodableType>>`
    stream.forEach { event in
        // process `ChangeStreamEvent<MyCodableType>` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `inventory`...
```

### Use a Custom `Codable` Type for the Return type of `ChangeStream.next()`
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")

inventory.watch(withEventType: MyCodableType.self).flatMap { stream in // a `ChangeStream<MyCodableType>`
    stream.forEach { event in
        // process `MyCodableType` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `inventory`...
```

### Open a Change Stream on a `MongoDatabase` (MongoDB 4.0+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let db = client.db("example")

db.watch().flatMap { stream in // a `ChangeStream<ChangeStreamEvent<Document>>`
    stream.forEach { event in
        // process `ChangeStreamEvent<Document>` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `db`...
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Open a Change Stream on a `MongoClient` (MongoDB 4.0+)
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)

client.watch().flatMap { stream in // a `ChangeStream<ChangeStreamEvent<Document>>`
    stream.forEach { event in
        // process `ChangeStreamEvent<Document>` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `client`...
```

Note: the types of the `fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above.

### Resume a Change Stream
```swift
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient(using: elg)
let inventory = client.db("example").collection("inventory")

inventory.watch().flatMap { stream -> EventLoopFuture<ChangeStream<ChangeStreamEvent<Document>>> in
    // read the first change event
    stream.next().flatMap { _ in
        // simulate an error by killing the stream
        stream.kill()
    }.flatMap { _ in
        // create a new change stream that starts after the first change event
        let resumeToken = stream.resumeToken
        return inventory.watch(options: ChangeStreamOptions(resumeAfter: resumeToken))
    }
}.flatMap { resumedStream in
    resumedStream.forEach { event in
        // process `ChangeStreamEvent<Document>` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `inventory`...
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

inventory.watch(pipeline).flatMap { stream in // a `ChangeStream<ChangeStreamEvent<Document>>`
    stream.forEach { event in
        // process `ChangeStreamEvent<Document>` here
    }
}.whenFailure { error in
    // handle error
}

// perform some operations using `inventory`...
```

## See Also
- [MongoDB Change Streams documentation](https://docs.mongodb.com/manual/changeStreams/)