# Using the Driver in Multithreaded Applications

## Async API
Our asynchronous API is designed to be used in SwiftNIO-based applications running atop `EventLoopGroup`s
composed of one or more `EventLoop`s.

You must pass in your application's `EventLoopGroup` when initializing a `MongoClient`, like:
```swift
let client = try MongoClient("mongodb://localhost:27017", using: myEventLoopGroup)
```

We strongly recommend using a single, global `MongoClient` per application. Each client is backed by a pool of connections per each server in the in MongoDB deployment, and utilizes a background thread to continuously monitor
the state of the MongoDB deployment. Using a single client allows these resources to be efficiently shared
throughout your application.

### Safe Use Across Event Loops
The following types are all designed to be safe to access across multiple threads/event loops:
* `MongoClient`
* `MongoDatabase`
* `MongoCollection`

*We make no guarantees about the safety of using any other type across threads.*

That said: each of these types will, by default, not necessarily always return `EventLoopFuture`s on the
same `EventLoop` you are using them on. Each time an `EventLoopFuture` is generated, they will call
`EventLoopGroup.next()` on the `MongoClient`'s underyling `EventLoopGroup` to select a next `EventLoop` to use.

To ensure thread safety when working with these returned futures, you should call `hop(to:)` on them in order
to "hop" the future over to your current event loop, which ensures any callbacks you register on the future
will fire on your current event loop.

Depending on your use case, a more convenient alternative for you may be to use versions of these core driver
types which are "bound" to particular `EventLoop`s, i.e. that always automatically return `EventLoopFuture`s
on the `EventLoop` they are bound to (as opposed to any `EventLoop` from the underlying `EventLoopGroup`).

To use the "bound" API, you can call `bound(to:)` on your global `MongoClient` to instantiate an `EventLoopBoundMongoClient`, which a small wrapper type around a `MongoClient` that returns futures solely
on its bound `EventLoop`. Any child `MongoDatabase`s or `MongoCollection`s retrieved from the bound client will automatically be bound to the same `EventLoop` as the client.

Please see the [EventLoopFuture](https://apple.github.io/swift-nio/docs/current/NIO/Classes/EventLoopFuture.html)
documentation for more details on multithreading.
### Usage With Server-side Swift Frameworks
See the [`Examples/`](https://github.com/mongodb/mongo-swift-driver/tree/main/Examples) directory in the driver GitHub repository for examples of how to integrate the driver in multithreaded frameworks.

## Sync API
In the synchronous API, we strongly recommend using a single, global `MongoClient` per application. Each client is backed by a pool of connections per each server in the in MongoDB deployment, and utilizes a background thread to continuously monitor
the state of the MongoDB deployment. Using a single client allows these resources to be efficiently shared
throughout your application.

The following types are safe to share across threads:
* `MongoClient`
* `MongoDatabase`
* `MongoCollection`

*We make no guarantees about the safety of using any other type across threads.*
