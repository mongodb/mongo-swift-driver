# BSON

Please see [here](https://mongodb.github.io/swift-bson) for the BSON library's API documentation as well as various usage examples in its corresponding [guide](https://mongodb.github.io/swift-bson/BSON/bson.html). For guidance on bridging BSON types with JSON, see our [JSON Interop](https://mongodb.github.io/swift-bson/BSON/json-interop.html) guide.

### `Codable` in MongoSwift and MongoSwiftSync
There are a number of ways for users to leverage `Codable` via driver's API. One such example is through `MongoCollection<T>`. By default, `MongoDatabase.collection` returns a `MongoCollection<BSONDocument>`. Any `find` or `aggregate` method invocation on that returned collection would then return a `MongoCursor<BSONDocument>`, which when iterated returns a `BSONDocument?`:
```swift
let collection = db.collection("person")

// asynchronous API
collection.find(["occupation": "Software Engineer"]).flatMap { cursor in
    cursor.toArray()
}.map { docs in
    docs.forEach { person in
        print(person["name"] ?? "nil")
    }
}
collection.insertOne(["name": "New Hire", "occupation": "Doctor", "projects": []]).whenSuccess { _ in /* ... */ }

// synchronous API
for person in try collection.find(["occupation": "Software Engineer"]) {
    print(try person.get()["name"] ?? "nil")
}
try collection.insertOne(["name": "New Hire", "occupation": "Doctor", "projects": []])
```
However, if the schema of the collection is known, `Codable` structs can be used to work with the data in a more type safe way. To facilitate this, the alternate `collection(name:asType)` method on `MongoDatabase`, which accepts a `Codable` generic type, can be used. The provided type defines the model for all the documents in that collection, and any cursor returned from `find` or `aggregate` on that collection will be generic over that type instead of `BSONDocument`. Iterating such cursors will automatically decode the result documents to the generic type specified. Similarly, `insert` on that collection will accept an instance of that type.
```swift
struct Project: Codable {
    let id: BSON
    let title: String
}

struct Person: Codable {
    let name: String
    let occupation: String
    let projects: [Project]
}

let collection = db.collection("person", withType: Person.self)

// asynchronous API
collection.find(["occupation": "Software Engineer"]).flatMap { cursor in
    cursor.toArray()
}.map { docs in
    docs.forEach { person in
        print(person.name)
    }
}
collection.insertOne(Person(name: "New Hire", occupation: "Doctor", projects: [])).whenSuccess { _ in /* ... */ }

// synchronous API
for person in try collection.find(["occupation": "Software Engineer"]) {
    print(try person.get().name)
}
try collection.insertOne(Person(name: "New Hire", occupation: "Doctor", projects: []))
```
This allows applications that interact with the database to use well-defined Swift types, resulting in clearer and less error-prone code. Similar things can be done with `ChangeStream<T>` and `ChangeStreamEvent<T>`.

## Migration Guides
### Migrating from the 0.2.0 through 1.0.0-rc1 API to the 1.0 API

#### Name Changes
In order to avoid naming conflicts with other libraries, we have prefixed all BSON types that we own with `BSON`:
* `Document` is now `BSONDocument`
* `Binary` is now `BSONBinary`
* `ObjectId` is now `BSONObjectID`
* `RegularExpression` is now `BSONRegularExpression`
* `DBPointer` is now `BSONDBPointer`
* `Symbol` is now `BSONSymbol`
* `Code` is now `BSONCode`
* `CodeWithScope` is now `BSONCodeWithScope`
* `Timestamp` is now `BSONTimestamp`
* `Decimal128` is now `BSONDecimal128`

#### ObjectID Updates

Note that the `D` in `ID` is now capitalized in both the type name `BSONObjectID` and in the `BSON` enum case `.objectID`. We have also provided a default value of `BSONObjectID()` for the `BSON.objectID` case, which simplifies embedding `BSONObjectID`s in `BSONDocument` literals in cases where you are inserting a new ID:
```swift
let doc: Document = ["_id": .objectID(ObjectID())]
let doc: BSONDocument = ["_id": .objectID()] // new
``` 

If you need to use an existing `BSONObjectID` you can still provide one:
```swift
let doc: BSONDocument = ["_id": .objectID(myID)]
```

#### Conversion APIs
The BSON library contains a number of methods for converting between types. Many of these are defined on `BSON` and were previously named `asX()`, e.g. `asInt32()`. These are now all named `toX()` instead.

Additionally, the driver previously supported conversions from `Binary` -> `UUID` and `RegularExpression` -> `NSRegularExpression` through initializers defined in extensions of the type being converted to. For discoverability, this logic has now been moved into `toX()` methods on the source types instead:
```swift
let regExp = try NSRegularExpression(from: myBSONRegExp) // old
let regExp = try myBSONRegExp.toNSRegularExpression() // new

let uuid = try UUID(from: myBSONBinary) // old
let uuid = try myBSONBinary.toUUID() // new
```

#### Extended JSON Conversion
Previously, `Document`/`BSONDocument` had computed properties, `extendedJSON` and `canonicalExtendedJSON`, to support converting to those formats. To better signify that these methods involve a non-constant time conversion, we've converted these properties to methods named `toExtendedJSONString()` and `toCanonicalExtendedJSONString()`, respectively.

#### Errors
Previously, the BSON library used the same types of errors as the driver. As of 1.0.0, the BSON library has its own set of errors. Please see the [error handling guide](https://github.com/mongodb/mongo-swift-driver/blob/main/Guides/Error-Handling.md) for more details.
