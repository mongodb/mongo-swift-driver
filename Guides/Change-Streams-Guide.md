# Using Change Streams

The driver supports [change streams](https://docs.mongodb.com/manual/changeStreams/), which allow applications to access real-time data changes. Applications can use change streams to subscribe to all data changes on a single collection, a database, or an entire deployment, and immediately react to them. Because change streams use the aggregation framework, applications can also filter for specific changes or transform the notifications at will.

**Note**: Change streams only work with MongoDB replica sets and sharded clusters.

## Examples
These examples use the driver's async/await APIs; for examples using `EventLoopFuture`s please see the [previous version of this guide](https://github.com/mongodb/mongo-swift-driver/blob/79c9683d56f92540f4065f40b9f55e1911a1ff5b/Guides/Change-Streams-Guide.md).

### Open a Change Stream on a `MongoCollection` (MongoDB 3.6+)

We recommend to open and interact with change streams in their own `Task`s, and to terminate change streams by canceling their corresponding `Task`s.
In the following example, change stream events will be processed asynchronously as they arrive on `changeStreamTask` until the `Task` is canceled.
`ChangeStream` conforms to Swift's [`AsyncSequence` protocol](https://developer.apple.com/documentation/swift/asyncsequence) and so can be iterated 
over using a for-in loop.

```swift
struct Item: Codable {
    let _id: BSONObjectID
    let name: String
    let cost: Int
    let count: Int
}

let inventory = client.db("example").collection("inventory", withType: Item.self)
let changeStreamTask = Task {
    for try await event in try await inventory.watch() {
        // process  `ChangeStream<ChangeStreamEvent<Item>>`
    }
}

// later...
changeStreamTask.cancel()
```

If you provide a pipeline to `watch` which transforms the shape of the returned documents, you will need to specify a type to use for the
`ChangeStreamEvent.fullDocument` property. You can do this as follows when calling `watch`:

```swift
struct ItemCount: Codable {
    let _id: BSONObjectID
    let count: Int
}

let changeStreamTask = Task {
    let pipeline: [BSONDocument] = [["$unset": ["fullDocument.name", "fullDocument.cost"]]]
    for try await event in try await inventory.watch(pipeline, withFullDocumentType: ItemCount.self) {
        // process  `ChangeStream<ChangeStreamEvent<ItemCount>>`
    }
}

// later...
changeStreamTask.cancel()
```

You can also provide a type to use in place of `ChangeStreamEvent` altogether:

```swift
let changeStreamTask = Task {
    for try await event in try await inventory.watch(withEventType: InventoryEvent.self) {
        // process  `ChangeStream<ChangeStreamEvent<InventoryEvent>>`
    }
}

// later...
changeStreamTask.cancel()
```

### Open a Change Stream on a `MongoDatabase` (MongoDB 4.0+)
You can also open a change stream on an entire database, which will observe events on all collections in the database:

```swift
let db = client.db("example")

let changeStreamTask = Task {
    for try await event in try await db.watch() {
        // process  `ChangeStream<ChangeStreamEvent<BSONDocument>>`
    }
}

// later...
changeStreamTask.cancel()
```

Note: the type of the `ChangeStreamEvent.fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above by passing in `fullDocumentType` or `eventType` to `watch()`.

### Open a Change Stream on a `MongoClient` (MongoDB 4.0+)
You can also open a change stream on an entire cluster, which will observe events on all databases and collections:

```swift
let changeStreamTask = Task {
    for try await event in try await client.watch() {
        // process  `ChangeStream<ChangeStreamEvent<BSONDocument>>`
    }
}

// later...
changeStreamTask.cancel()
```

Note: the type of the `ChangeStreamEvent.fullDocument` property, as well as the return type of `ChangeStream.next()`, may be customized in the same fashion as the examples using `MongoCollection` above by passing in `fullDocumentType` or `eventType` to `watch()`.

### Resume a Change Stream
Change streams can be resumed from particular points in time using resume tokens. For example:

```swift
let inventory = client.db("example").collection("inventory")

let changeStreamTask1 = Task { () -> ResumeToken? in
    let changeStream = try await inventory.watch()
    // read the first change event
    _ = try await changeStream.next()
    // resume token to resume stream after the first event
    return changeStream.resumeToken
}

// Get resume token from the first task and change stream.
guard let resumeToken = try await changeStreamTask1.value else {
    fatalError("Unexpectedly missing resume token after processing event")
}

let changeStreamTask2 = Task {
    let changeStream = try await inventory.watch(options: ChangeStreamOptions(resumeAfter: resumeToken))
    for try await event in changeStream {
        // process ChangeStreamEvent
    }
}

// later...
changeStreamTask2.cancel()
```

### Modify Change Stream Output
```swift
let inventory = client.db("example").collection("inventory", withType: Item.self)

let changeStreamTask = Task {
    // Only include events where the changed document's count = 0
    let pipeline: [BSONDocument] = [
        ["$match": ["fullDocument.count": 0]]
    ]
    for try await event in try await inventory.watch(pipeline) {
        // process  `ChangeStream<ChangeStreamEvent<Item>>`
    }
}

// later...
changeStreamTask.cancel()
```

## See Also
- [MongoDB Change Streams documentation](https://docs.mongodb.com/manual/changeStreams/)
