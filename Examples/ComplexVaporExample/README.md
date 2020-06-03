# MongoDB + Vapor Example Application

This repository contains an example application built using [Vapor 4](vapor.codes) along with version 1.0 of the [MongoDB Swift driver](https://github.com/mongodb/mongo-swift-driver).

This application is intended to demonstrate best practices for integrating the driver into your backend. It is **not** production-ready, and does not necessarily follow best HTML or Javascript practices. The frontend implementation is a minimal amount of code built with Vapor's templating language [Leaf](https://github.com/vapor/leaf) to allow you to interact with all of the application's HTTP endpoints.

This application require Swift 5.2 and MongoDB 3.6+. It will run on Linux as well as macOS 10.15+.

## Building and Running the Application
1. Install MongoDB on your system if you haven't already. Downloads are available [here](https://www.mongodb.com/download-center/community).
1. Start up MongoDB running locally: `mongod --dbpath some-directory-here`. You may need to specify a `dbpath` directory for the database to use.
1. Run `./loadData.sh` to load example application data into the database.
1. Install Swift 5.2 on your system if you haven't already. You can download Swift and find instructions for installing it [here](https://swift.org/download/).
1. From the root directory of the project, run `swift build`. This will likely take a while the first time you do so.
1. Once building has completed, run `swift run` from the root directory. You should get a message that the server has started running on `http://127.0.0.1:8080`.
1. Open up your browser and visit `http://127.0.0.1:8080`. You should see the application and be able to test out adding, deleting, and editing data in the collection.

## Application Architecture

This is a fully asynchronous application. At its core is [SwiftNIO](https://github.com/apple/swift-nio), which is used to implement both Vapor and the MongoDB driver.

The application is a basic HTTP server combined with a minimal frontend, which supports storing a list of kittens and details about them. The server will handle the following types of requests:
1. A GET request at the root URL `/` loads the main index page containing a list of kittens.
1. A POST request at the root URL `/` adds a new kitten.
1. A GET request at the URL `/kittens/{name}` loads information about the kitten with the specified name.
1. A PATCH request at the URL `/kittens/{name}` edits the `favoriteFood` property for the kitten with the specified name.
1. A DELETE request  at the URL `/kittens/{name}` deletes the kitten with the specified name.

### MongoDB Usage
This application connects to a local standalone MongoDB server. It uses the collection "kittens" in the database "home". The "kittens" collection has a [unique index](https://docs.mongodb.com/manual/core/index-unique/) on the "name" field, ensuring that no two kittens in the collection can have the same name.

If you'd like to point the application to a MongoDB server elsewhere (e.g. on [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)) or running on a different port, or change any configuration options for the client, you can edit the code where the client is created in `Sources/App/configure.swift`.

This application uses a single `MongoClient` for the entire application. `MongoClient` is implemented with that approach in mind: it is safe to use across threads, and is backed by a [connection pool](https://en.wikipedia.org/wiki/Connection_pool) which enables sharing resources throughout the application.

We recommend storing the client in `Application.storage` and adding a computed property to access it in an extension of `Application`, to allow easy shared access throughout the application. You can see an example of how to do this in `Sources/App/configure.swift`.

The application also uses a single shared `MongoCollection` object for the entire application, defined in `routes.swift`. `MongoCollection` is also thread-safe, and is essentially a wrapper around a `MongoClient` specifying a namespace and providing access to collection-specific API methods.

#### Important Note on `EventLoop` hopping
Anywhere we call a MongoDB API method returning an `EventLoopFuture`, we use `hop(to: req.eventLoop)` after to return to the request's `EventLoop`. As `MongoClient` is backed by an `EventLoopGroup`, the `EventLoopFuture`s it (as well as its child `MongoDatabase`s and `MongoCollection`s) returns may fire on any `EventLoop` in the group. However, per Vapor's [documentation](https://docs.vapor.codes/4.0/async/):
> Vapor expects that route closures will stay on `req.eventLoop`. If you hop threads, you must ensure access to `Request` and the final response future all happen on the request's event loop.

Therefore, we must always `hop` when we are done calling a driver API. Please see the `EventLoopFuture` [documentation](https://apple.github.io/swift-nio/docs/current/NIO/Classes/EventLoopFuture.html) for more details on this method.

### Codable Usage
Throughout the application, we frequently use [`Codable`](https://developer.apple.com/documentation/swift/codable) Swift types. These are very useful as they allow us to convert seamlessly from BSON, the format MongoDB stores data in, to Swift types used in the server, to JSON to send to the client. The same is true for the opposite direction.

Note that Vapor's[`Content`](https://api.vapor.codes/vapor/master/Vapor/Protocols/Content.html) protocol, which specifies types that can be initialized from HTTP requests and serialized to HTTP responses, inherits from `Codable`.

When creating a `MongoCollection` object in the driver, you can pass in the name of a `Codable` type:
```swift
let collection = client.db("home").collection("kittens", withType: Kitten.self)
```

This will instantiate a `MongoCollection<Kitten>`. You can then use `Kitten` directly with many API methods -- for example, `insertOne` will directly accept a `Kitten` instance, and `findOne` will return an `EventLoopFuture<Kitten>`.

Sometimes you may need to work with the `BSONDocument` type as well, for example when providing a query filter. If you want to construct these documents from `Codable` types you may do so using `BSONEncoder`, as we do with the `updateDocument` in our PATCH handler for `/kittens/{name}`.

The driver also exposes a `BSONDecoder` for initializing `Decodable` types from `BSONDocument`s if you need to do the reverse.

Please see our [BSON guide](https://mongodb.github.io/mongo-swift-driver/MongoSwift/bson.html) for more details on the BSON library.
