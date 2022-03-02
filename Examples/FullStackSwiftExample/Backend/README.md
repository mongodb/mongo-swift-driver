# MongoDB + Vapor Backend

The backend server is built using [Vapor 4](vapor.codes) along with version 1 of the [MongoDB Swift driver](https://github.com/mongodb/mongo-swift-driver). It utilizes a small library we've written called [mongodb-vapor](https://github.com/mongodb/mongodb-vapor) which includes some helpful code for integrating the two.

The application contains a REST API which the iOS frontend uses to interact with it via HTTP requests.

## Application Endpoints
The backend server supports the following API requests:
1. A GET request at the URL `/` returns a list of kittens.
1. A POST request at the URL `/` adds a new kitten.
1. A GET request at the URL `/{ID}` returns information about the kitten with the specified ID.
1. A PATCH request at the URL `/{ID}` edits the `favoriteFood` and `lastUpdateTime` properties for the kitten with the specified ID.
1. A DELETE request at the URL `/{ID}` deletes the kitten with the specified ID.

### MongoDB Usage
This application connects to the MongoDB server with connection string specified by the environment variable `MONGODB_URI`, or if unspecified, attempts to connect to a MongoDB server running on the default host/port with connection string `mongodb://localhost:27017`.

The application uses the collection "kittens" in the database "home". This collection has a [unique index](https://docs.mongodb.com/manual/core/index-unique/) on the `_id` field, as is the default for MongoDB (more on that [here](https://docs.mongodb.com/manual/core/document/#the-_id-field)).

The call to `app.mongoDB.configure()` in `Sources/App/configure.swift` initializes a global `MongoClient` to back your application. `MongoClient` is implemented with that approach in mind: it is safe to use across threads, and is backed by a [connection pool](https://en.wikipedia.org/wiki/Connection_pool) which enables sharing resources throughout the application.

Throughout the application, the global client is accessible via `app.mongoDB.client`.
### Data Models
The data model types used in the backend are shared with the frontend, and defined in the [Models](../Models) package. In `Sources/App/routes.swift`, we extend the `Kitten` type to conform to Vapor's [`Content`](https://api.vapor.codes/vapor/main/Vapor/Content/) protocol, which specifies types that can be initialized from HTTP requests and serialized to HTTP responses.

We are also able to use these model types directly with the database driver, which makes it straightforward to, for example, insert a new `Kitten` object that was sent to the backend via HTTP directly into a MongoDB collection. To support that, when creating a `MongoCollection`, we pass in the name of the corresponding model type:
```swift
extension Request {
    var kittenCollection: MongoCollection<Kitten> {
        self.application.mongoDB.client.db("home").collection("kittens", withType: Kitten.self)
    }
}
```

This will instantiate a `MongoCollection<Kitten>`. We can then use `Kitten` directly with many API methods -- for example, `insertOne` will directly accept a `Kitten` instance, and `findOne` will return a `Kitten?`. Since `Kitten` is  

In `Sources/Run/main.swift`, we globally configure Vapor to use `swift-bson`'s `ExtendedJSONEncoder` and `ExtendedJSONDecoder` for encoding/decoding JSON data, rather than the default `JSONEncoder` and `JSONDecoder`:
```swift
ContentConfiguration.global.use(encoder: ExtendedJSONEncoder(), for: .json)
ContentConfiguration.global.use(decoder: ExtendedJSONDecoder(), for: .json)
```
This is recommended as [extended JSON](https://docs.mongodb.com/manual/reference/mongodb-extended-json/) is a MongoDB-specific version of JSON which helps with preserving type information. The iOS application also uses extended JSON via `ExtendedJSONEncoder` and `ExtendedJSONDecoder`.
