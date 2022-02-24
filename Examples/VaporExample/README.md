# MongoDB + Vapor Example Application

This repository contains an example application built using [Vapor 4](vapor.codes) along with version 1 of the [MongoDB Swift driver](https://github.com/mongodb/mongo-swift-driver).

It is built using a small library we've written called [mongodb-vapor](https://github.com/mongodb/mongodb-vapor) which includes some helpful code for integrating the two.

This application is intended to demonstrate best practices for integrating the driver into your backend. It is **not** production-ready, and does not necessarily follow best HTML or Javascript practices. 

The application contains both a REST API as well as a minimal frontend built with Vapor's templating language [Leaf](https://github.com/vapor/leaf).

This application requires Swift 5.5.2+ and MongoDB 3.6+. It will run on Linux as well as macOS 12+.

If you are looking for an example application that uses older Swift versions prior to the introduction of structured concurrency, please refer to a previous version of this application and README [here](https://github.com/mongodb/mongo-swift-driver/tree/5d9fad121d7cb3ded61087de300ff007766ccd55/Examples/VaporExample).

## Building and Running the Application
1. Install MongoDB on your system if you haven't already. Downloads are available [here](https://www.mongodb.com/download-center/community).
1. Start up MongoDB running locally: `mongod --dbpath some-directory-here`. You may need to specify a `dbpath` directory for the database to use.
1. Run `./loadData.sh` to load example application data into the database.
1. Install Swift 5.5+ on your system if you haven't already. You can download Swift and find instructions for installing it [here](https://swift.org/download/).
1. From the root directory of the project, run `swift build`. This will likely take a while the first time you do so.
1. Once building has completed, run `swift run` from the root directory. You should get a message that the server has started running on `http://127.0.0.1:8080`.
1. Open up your browser and visit `http://127.0.0.1:8080`. You should see the application and be able to test out adding, deleting, and editing data in the collection.

## Application Architecture

This is a fully asynchronous application with both web and REST API interfaces, which support storing a list of kittens and details about them.

The server will handle the following types of web requests:
1. A GET request at the root URL `/` loads the main index page containing a list of kittens.
1. A GET request at the URL `/kittens/{name}` loads a web page with information about the kitten with the specified name.

And the following types of API requests:
1. A GET request at the URL `/rest` returns a list of kittens.
1. A POST request at the URL `/rest` adds a new kitten.
1. A GET request at the URL `/rest/kittens/{name}` returns information about the kitten with the specified name.
1. A PATCH request at the URL `/rest/kittens/{name}` edits the `favoriteFood` property for the kitten with the specified name, and updates the kitten's `lastUpdateTime`.
1. A DELETE request at the URL `/rest/kittens/{name}` deletes the kitten with the specified name.

### MongoDB Usage
This application connects to a local standalone MongoDB server running on the default host/port, `localhost:27017`. It uses the collection "kittens" in the database "home". The "kittens" collection has a [unique index](https://docs.mongodb.com/manual/core/index-unique/) on the "name" field, ensuring that no two kittens in the collection can have the same name.

If you'd like to point the application to a MongoDB server elsewhere (e.g. on [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)) or running on a different port, or change any configuration options for the client, you can edit the call to `app.mongoDB.configure()` in `Sources/App/configure.swift`.

The call to `configure()` initializes a global `MongoClient` to back your application. `MongoClient` is implemented with that approach in mind: it is safe to use across threads, and is backed by a [connection pool](https://en.wikipedia.org/wiki/Connection_pool) which enables sharing resources throughout the application.

Throughout your application, you can access the global client via `app.mongoDB.client`.

For convenience, we recommend adding your own computed properties to `Request` that return `MongoDatabase`s and `MongoCollection`s you frequently access, as is shown in `Sources/App/routes.swift` 
with the `kittenCollection` property:
```swift
extension Request {
    var kittenCollection: MongoCollection<Kitten> {
        self.application.mongoDB.client.db("home").collection("kittens", withType: Kitten.self)
    }
}
```
### Codable Usage
Throughout the application, we frequently use [`Codable`](https://developer.apple.com/documentation/swift/codable) Swift types. These are very useful as they allow us to convert seamlessly from BSON, the format MongoDB stores data in, to Swift types used in the server, to JSON to send to the client. The same is true for the opposite direction.

Note that Vapor's[`Content`](https://api.vapor.codes/vapor/main/Vapor/Content/) protocol, which specifies types that can be initialized from HTTP requests and serialized to HTTP responses, inherits from `Codable`.

#### BSON <-> Swift types
When creating a `MongoCollection`, you can pass in the name of a `Codable` type:
```swift
let collection = req.mongoDB.client.db("home").collection("kittens", withType: Kitten.self)
```

This will instantiate a `MongoCollection<Kitten>`. You can then use `Kitten` directly with many API methods -- for example, `insertOne` will directly accept a `Kitten` instance, and `findOne` will return a `Kitten?`.

Sometimes you may need to work with the `BSONDocument` type as well, for example when providing a query filter. If you want to construct these documents from `Codable` types you may do so using `BSONEncoder`, as we do with the `updateDocument` in the `updateKitten()` method via the `KittenUpdate` struct.

The driver also exposes a `BSONDecoder` for initializing `Decodable` types from `BSONDocument`s if you need to do the reverse.

Please see our [BSON guide](https://mongodb.github.io/swift-bson/docs/current/SwiftBSON/bson-guide.html) for more details on the BSON library.

#### JSON <-> Swift types

When working with MongoDB types, we recommend utilizing [extended JSON](https://docs.mongodb.com/manual/reference/mongodb-extended-json/), 
a MongoDB-specific version of JSON which assists with preserving type information.

For this purpose, we provide an `ExtendedJSONEncoder` and `ExtendedJSONDecoder` in our BSON library.

As shown in `Sources/Run/main.swift`, you can globally configure Vapor to use our  `ExtendedJSONEncoder` and
`ExtendedJSONDecoder` for encoding/decoding JSON data, rather than the default `JSONEncoder` and `JSONDecoder`:
```swift
ContentConfiguration.global.use(encoder: ExtendedJSONEncoder(), for: .json)
ContentConfiguration.global.use(decoder: ExtendedJSONDecoder(), for: .json)
```

On the client side, our web application uses [`js-bson`](https://github.com/mongodb/js-bson), the MongoDB Javascript BSON 
library, for converting the data sent via HTTP requests to extended JSON.

Note that there are two extended JSON formats to choose from, canonical and relaxed: canonical preserves type information at 
the expense of readability, and relaxed is more readable, but loses some type information. You can configure the format
uses by `ExtendedJSONEncoder` by setting the `format` property (the default format is relaxed):
```swift
let encoder = ExtendedJSONEncoder()
encoder.format = .canonical
```

Please see our [JSON Interop Guide](https://mongodb.github.io/swift-bson/docs/current/SwiftBSON/json-interop.html) for
more details on working with JSON and MongoDB types.
