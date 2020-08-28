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
Previously, the BSON library used the same types of errors as the driver. As of 1.0.0, the BSON library has its own set of errors. Please see the [error handling guide](https://github.com/mongodb/mongo-swift-driver/blob/master/Guides/Error-Handling.md) for more details.

### Migrating from the 0.0.1-0.1.3 API to the 0.2.0 BSON API
In version 0.2.0 of `MongoSwift`, the public API for using BSON values was changed dramatically. This section will describe the process for migrating from the old API (BSON API v1) to this new one (BSON API v2).
#### Overview of BSON API v1
 The previous API was based around the `BSONValue` protocol. Types that conformed to this protocol could be inserted to or read out of `Document` and could aslo be used in `Document` literals. The protocol was also used in various places around the driver as an existential type or conformance requirement. A related protocol, `BSONNumber`, inherited from `BSONValue` and provided some numeric conversion helpers for the various BSON number types (e.g. `Double`, `Int32`, `Int`). 
```swift
var doc: Document = [
    "a": 5
    "b": ObjectId()
]
let value: BSONValue? = doc["a"] // 5
let intValue = (value as? BSONNumber)?.int32Value // Int32(5)
doc["c"] = "i am a string"
```
This API provided a number of benefits, the principal one being the seamless integration of standard Swift types (e.g. `Int`) and driver custom ones (e.g `ObjectId`) into `Document`'s methods. It also had a few drawbacks, however. In order for `BSONValue` to be used as an existential type, it could not have `Self` or associated type requirements. This ended being a big restriction as it meant `BSONValue` could not be `Equatable`, `Hashable`, or `Codable`. Instead, all of this functionaltiy was put onto the separate wrapper type `AnyBSONValue`, which was used instead of an existential `BSONValue` in many places in order to leverage these common protocol conformances.

Another drawback is that subdocument literals could not be inferred and had to be explicitly casted:
```swift
let x: Document = [
    "x": [
        "y": [
            z: 4
        ] as Document
    ] as Document
]
```
#### Required Updates
In BSON API v2, `BSONNumber`, `BSONValue`, and `AnyBSONValue` no longer exist. They are all entirely replaced by the `BSON` enum.

##### Updating `BSONValue` references

Anywhere in the driver that formerly accepted or returned a `BSONValue` will now accept or return a `BSON`. Wherever `BSONValue` is used as an existential value in your application, a `BSON` will probably work as a drop-in replacement. Any casts will need to be updated to call the appropriate helper property instead.
```swift
func foo(x: BSONValue) -> String? {
    guard let stringValue = x as? String else {
        return nil
    }
    return "foo" + stringValue
}
```
becomes:
```swift
func foo(x: BSON) -> String? {
    guard let stringValue = x.stringValue else {
        return nil
    }
    // or
    guard case let .string(stringValue) = x else {
        return nil
    }
    return "foo" + stringValue
}
```
Similarly, `BSON`'s `Equatable` conformance can be leveraged instead of the old `bsonEquals`.
```swift
func foo(x: BSONValue, y: BSONValue) { 
    if x.bsonEquals(y) { ... }
}
```
becomes simply:
```swift
func foo(x: BSON, y: BSON) {
    if x == y { ... }
}
```
**Generic Requirement**
Currently, there is no equivalent protocol in BSON API v2 to `BSONValue`, so if your application was using it as a generic requirement there is no alternative in the driver. You may have to implement your own similar protocol to achieve the same effect. If such a protocol would be useful to you, please [file a ticket on the driver's Jira project](https://github.com/mongodb/mongo-swift-driver#bugs--feature-requests).

##### Updating `BSONNumber` references
`BSON` should be a drop-in replacement for anywhere `BSONNumber` is used, except for as a generic requirement. One thing to note that `BSONNumber`'s properties (e.g. `.int32Value`) are _conversions_, whereas `BSON`'s are simple unwraps. The conversions on `BSON` are implemented as methods (e.g. `asInt32()`).

```swift
// old
func foo(doc: Document) -> Int? {
    // conversion
    guard let int = (doc["a"] as? BSONNumber)?.intValue else {
        return nil
    }
    // cast
    guard let otherInt = doc["b"] as? Int32 else {
        return nil
    }
    return int*Int(otherInt)
}

// new
func foo(doc: Document) -> Int? {
    // conversion
    guard let int = doc["a"]?.asInt() else {
        return nil
    }
    // cast
    guard let otherInt = doc["b"]?.int32Value else {
        return nil
    }
    // or can use case let
    guard case let .int32(otherInt) = doc["b"] else {
        return nil
    }
    return int * Int(otherInt)
}
```
##### Updating `AnyBSONValue` references
`BSON` should be able to serve as a complete replacement for `AnyBSONValue`.
`Codable` usage:
```swift
// old
struct X: Codable {
    let x: AnyBSONValue
}
// new
struct X: Codable {
    let x: BSON
}
```
`Equatable` usage:
```swift
// old 
let a: [BSONValue] = ["1", 2, false]
let b: [BSONValue] = ["not", "equal"]
return a.map { AnyBSONValue($0) } == b.map { AnyBSONValue($0) }
// new
let a: [BSON] = ["1", 2, false]
let b: [BSON] = ["not", "equal"]
return a == b
```
`Hashable` usage:
```swift
// old
let a: [AnyBSONValue: Int] = [AnyBSONValue("hello"): 4, AnyBSONValue(ObjectId()): 26]
print(a[AnyBSONValue(true)] ?? "nil")
// new
let a: [BSON, Int] = ["hello": 4, .objectId(ObjectId()): 26]
print(a[true] ?? "nil")
```

##### Updating `Document` literals
`BSON` can be expressed by a dictionary literal, string literal, integer literal, float literal, boolean literal, and array literal, so document literals consisting of those literals can largely be left alone. All the other types that formerly conformed to `BSONValue` will need to have their cases explicitly constructed. The cast to `Document` will no longer be required for subdocuments and will need to be removed. All runtime variables will also need to have their cases explicitly constructed whereas in BSON API v1 they could just be inserted directly.
```swift
// BSON API v1
let x: Document = [
    "_id": self.getDocument()
    "x": Date()
    "y": [
        "z": [1, 2, false, ["x": 123] as Document]
    ] as Document
]
```
becomes
```swift
// BSON API v2
let x: Document = [
    "_id": .document(self.getDocument())
    "x": .datetime(Date()),
    "y": [
        "z": [1, 2, false, ["x": 123]
    ]
]
```

