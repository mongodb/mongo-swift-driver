# `Codable` Usage in MongoSwift and MongoSwiftSync
There are a number of ways for users to leverage `Codable` via the driver's API. One such example is through `MongoCollection<T>`. By default, `MongoDatabase.collection` returns a `MongoCollection<BSONDocument>`. Any `find` or `aggregate` method invocation on that returned collection would then return a `MongoCursor<BSONDocument>`, which when iterated returns a `BSONDocument?`:

**Async/Await (recommended)**:
```swift
let collection = db.collection("person")

for try await person in try await collection.find(["occupation": "Software Engineer"]) {
    print(person["name"] ?? "nil")
}

try await collection.insertOne(["name": "New Hire", "occupation": "Doctor", "projects": []])
```

**Async (`EventLoopFuture`s)**:
```swift
let collection = db.collection("person")

collection.find(["occupation": "Software Engineer"]).flatMap { cursor in
    cursor.toArray()
}.map { docs in
    docs.forEach { person in
        print(person["name"] ?? "nil")
    }
}
collection.insertOne(["name": "New Hire", "occupation": "Doctor", "projects": []]).whenSuccess { _ in /* ... */ }
```

**Sync**
```swift
let collection = db.collection("person")

for person in try collection.find(["occupation": "Software Engineer"]) {
    print(try person.get()["name"] ?? "nil")
}
try collection.insertOne(["name": "New Hire", "occupation": "Doctor", "projects": []])
```

However, if the schema of the collection is known, `Codable` structs can be used to work with the data in a more type safe way. To facilitate this, the alternate `collection(name:asType)` method on `MongoDatabase`, which accepts a `Codable` generic type, can be used. The provided type defines the model for all the documents in that collection, and any cursor returned from `find` or `aggregate` on that collection will be generic over that type instead of `BSONDocument`. Iterating such cursors will automatically decode the result documents to the generic type specified. Similarly, `insert` on that collection will accept an instance of that type.

First, define custom types matching your collection schema:
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
```

Then, use your custom types along with the driver APIs:

**Async/Await (recommended)**:
```swift
for try await person in try await collection.find(["occupation": "Software Engineer"]) {
    print(person.name)
}

try await collection.insertOne(Person(name: "New Hire", occupation: "Doctor", projects: []))
```

**Async (`EventLoopFuture`s)**:
```swift
collection.find(["occupation": "Software Engineer"]).flatMap { cursor in
    cursor.toArray()
}.map { docs in
    docs.forEach { person in
        print(person.name)
    }
}
collection.insertOne(Person(name: "New Hire", occupation: "Doctor", projects: [])).whenSuccess { _ in /* ... */ }
```

**Sync**
```swift
for person in try collection.find(["occupation": "Software Engineer"]) {
    print(try person.get().name)
}
try collection.insertOne(Person(name: "New Hire", occupation: "Doctor", projects: []))
```
This allows applications that interact with the database to use well-defined Swift types, resulting in clearer and less error-prone code. Similar things can be done with `ChangeStream<T>` and `ChangeStreamEvent<T>`.
