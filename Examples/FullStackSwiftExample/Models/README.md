# Models

This is a small [SwiftPM](https://www.swift.org/package-manager/) library containing data model types, which is a dependency of both the frontend and backend. An advantage of building the full application in Swift is that we can share the definitions of these types and avoid having to keep duplicate logic in sync.

This package contains three model types. Two of them correspond to data types stored in the database: `Kitten` and `CatFood`. The third, `KittenUpdate` models the information used when an update is performed in the application.

All of these types are `Codable`, which allows them to be serialized to and deserialized from external data formats. For the purpose of this application, there are two external data formats used:

1) [`Extended JSON`](https://docs.mongodb.com/manual/reference/mongodb-extended-json/), a version of JSON with some MongoDB-specific extensions. Both the frontend and backend use [swift-bson](https://github.com/mongodb/swift-bson) and its [`ExtendedJSONEncoder`](https://mongodb.github.io/swift-bson/docs/current/SwiftBSON/Classes/ExtendedJSONEncoder.html) and [`ExtendedJSONDecoder`](https://mongodb.github.io/swift-bson/docs/current/SwiftBSON/Classes/ExtendedJSONDecoder.html) types to perform serialization and deserialization of the data transmitted via HTTP. This is helpful as extended JSON makes it straightforward to preserve type information. For example, in extended JSON dates are expressed as `{"$date": "<ISO-8601 Date/Time Format>"}`. Swift `Date` objects will automatically be serialized in this form by `ExtendedJSONEncoder`, and `ExtendedJSONDecoder` will decode such JSON input back into a Swift `Date`.

2) [`BSON`](https://docs.mongodb.com/manual/reference/bson-types/) is the binary serialization format MongoDB uses to store data. Serialization to and deserialization from BSON is handled automatically in the backend by the MongoDB driver -- the driver API accepts and returns `Codable` types, and under the hood handles serializing those types to and from BSON for storage in and retrieval from the database.

For an example of how all of this comes together, when a new kitten is added via the iOS application, the flow of data is as follows:
1) The iOS app creates a new instance of `Kitten` containing the user-provided data
2) The iOS app serializes the `Kitten` instance to extended JSON using `ExtendedJSONEncoder`
3) The iOS app sends a POST request to the backend server containing the extended JSON data
4) The backend deserializes the extended JSON data into a `Kitten` using `ExtendedJSONDecoder`
5) The `Kitten` instance is passed to `MongoCollection.insertOne`
6) The database driver uses `BSONEncoder` to convert the `Kitten` to BSON data
7) The BSON data is sent to the database via the MongoDB wire protocol
