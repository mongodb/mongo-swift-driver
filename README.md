[![sswg:incubating|104x20](https://img.shields.io/badge/sswg-incubating-blue.svg)](https://github.com/swift-server/sswg/blob/master/process/incubation.md#incubating-level)

# MongoSwift
The official [MongoDB](https://www.mongodb.com/) driver for Swift applications on macOS and Linux.

### Index
- [Documentation](#documentation)
- [Bugs/Feature Requests](#bugs--feature-requests)
- [Installation](#installation)
    - [Step 1: Install Required System Libraries (Linux Only)](#step-1-install-required-system-libraries-linux-only)
    - [Step 2: Install MongoSwift](#step-2-install-the-driver)
- [Example Usage](#example-usage)
    - [Connect to MongoDB and Create a Collection](#connect-to-mongodb-and-create-a-collection)
    - [Create and Insert a Document](#create-and-insert-a-document)
    - [Find Documents](#find-documents)
    - [Work With and Modify Documents](#work-with-and-modify-documents)
    - [Usage With Kitura, Vapor, and Perfect](#usage-with-kitura-vapor-and-perfect)
- [Development Instructions](#development-instructions)

## Documentation
The latest documentation for the driver is available [here](https://mongodb.github.io/mongo-swift-driver/).
The latest documentation for the driver's BSON library is available [here](https://mongodb.github.io/swift-bson/).

## Bugs / Feature Requests

Think you've found a bug? Want to see a new feature in `mongo-swift-driver`? Please open a case in our issue management tool, JIRA:

1. Create an account and login: [jira.mongodb.org](https://jira.mongodb.org)
2. Navigate to the SWIFT project: [jira.mongodb.org/browse/SWIFT](https://jira.mongodb.org/browse/SWIFT)
3. Click **Create Issue** - Please provide as much information as possible about the issue and how to reproduce it.

Bug reports in JIRA for all driver projects (i.e. NODE, PYTHON, CSHARP, JAVA) and the
Core Server (i.e. SERVER) project are **public**.

## Security Concerns
Please see [SECURITY.md](SECURITY.md) for details on our security process.

## Installation
The driver supports use with Swift 5.1+. The minimum macOS version required to build the driver is 10.14. The driver is tested in continuous integration against macOS 10.14, Ubuntu 16.04, and Ubuntu 18.04.

Installation is supported via [Swift Package Manager](https://swift.org/package-manager/).

You can find details about all our versions in this repo's [releases page](https://github.com/mongodb/mongo-swift-driver/releases).

### Step 1: Install Required System Libraries (Linux Only)
The driver vendors and wraps the MongoDB C driver (`libmongoc`), which depends on a number of external C libraries when built in Linux environments. As a result, these libraries must be installed on your system in order to build MongoSwift.

To install those libraries, please follow the [instructions](http://mongoc.org/libmongoc/current/installing.html#prerequisites-for-libmongoc) from `libmongoc`'s documentation.

### Step 2: Install the driver
The driver contains two modules to support a variety of use cases: an asynchronous API in `MongoSwift`, and a synchronous API in `MongoSwiftSync`. The modules share a number of core types such as options `struct`s.
The driver depends on our library `swift-bson`, containing a BSON implementation. All BSON symbols are re-exported from the drivers' modules, so you do not need to explicitly `import BSON` in your application.

To install the driver, add the package and relevant module as a dependency in your project's `Package.swift` file:

```swift
// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "1.1.0"))
    ],
    targets: [
        // Async module
        .target(name: "MyAsyncTarget", dependencies: ["MongoSwift"]),
        // Sync module
        .target(name: "MySyncTarget", dependencies: ["MongoSwiftSync"])
    ]
)
```

Then run `swift build` to download, compile, and link all your dependencies.

## Example Usage

Note: You should call `cleanupMongoSwift()` exactly once at the end of your application to release all memory and other resources allocated by `libmongoc`.

### Connect to MongoDB and Create a Collection

**Async**:
```swift
import MongoSwift
import NIO

let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let client = try MongoClient("mongodb://localhost:27017", using: elg)

defer {
    // clean up driver resources
    try? client.syncClose()
    cleanupMongoSwift()

    // shut down EventLoopGroup
    try? elg.syncShutdownGracefully()
}

let db = client.db("myDB")
let result = db.createCollection("myCollection").flatMap { collection in
    // use collection...
}
```

**Sync**:
```swift
import MongoSwiftSync

defer {
    // free driver resources
    cleanupMongoSwift()
}

let client = try MongoClient("mongodb://localhost:27017")

let db = client.db("myDB")
let collection = try db.createCollection("myCollection")

// use collection...
```

Note: we have included the client `connectionString` parameter for clarity, but if connecting to the default `"mongodb://localhost:27017"`it may be omitted.

### Create and Insert a Document
**Async**:
```swift
let doc: BSONDocument = ["_id": 100, "a": 1, "b": 2, "c": 3]
collection.insertOne(doc).whenSuccess { result in
    print(result?.insertedID ?? "") // prints `.int64(100)`
}
```

**Sync**:
```swift
let doc: BSONDocument = ["_id": 100, "a": 1, "b": 2, "c": 3]
let result = try collection.insertOne(doc)
print(result?.insertedID ?? "") // prints `.int64(100)`
```

### Find Documents
**Async**:
```swift
let query: BSONDocument = ["a": 1]
// The `sort` option specifies the order in which results are returned
// via the cursor. In this case, `["_id": -1]` indicates that the documents will
// be returned in descending order according to the `_id` field.
let options = FindOptions(sort: ["_id": -1])
let result = collection.find(query, options: options).flatMap { cursor in
    cursor.forEach { doc in
        print(doc)
    }
}
```

**Sync**:
```swift
let query: BSONDocument = ["a": 1]
// The `sort` option specifies the order in which results are returned
// via the cursor. In this case, `["_id": -1]` indicates that the documents will
// be returned in descending order according to the `_id` field.
let options = FindOptions(sort: ["_id": -1])
let documents = try collection.find(query, options: options)
for d in documents {
    print(try d.get())
}
```

### Work With and Modify Documents
```swift
var doc: BSONDocument = ["a": 1, "b": 2, "c": 3]

print(doc) // prints `{"a" : 1, "b" : 2, "c" : 3}`
print(doc["a"] ?? "") // prints `.int64(1)`

// Set a new value
doc["d"] = 4
print(doc) // prints `{"a" : 1, "b" : 2, "c" : 3, "d" : 4}`

// Using functional methods like map, filter:
let evensDoc = doc.filter { elem in
    guard let value = elem.value.asInt() else {
        return false
    }
    return value % 2 == 0
}
print(evensDoc) // prints `{ "b" : 2, "d" : 4 }`

let doubled = doc.map { elem -> Int in
    guard case let value = .int64(value) else {
        return 0
    }

    return Int(value * 2)
}
print(doubled) // prints `[2, 4, 6, 8]`
```

Note that `BSONDocument` conforms to `Collection`, so useful methods from
[`Sequence`](https://developer.apple.com/documentation/swift/sequence) and
[`Collection`](https://developer.apple.com/documentation/swift/collection) are
all available. However, runtime guarantees are not yet met for many of these
methods.

### Usage With Kitura, Vapor, and Perfect
The `Examples/` directory contains sample projects that use the driver with [Kitura](https://github.com/mongodb/mongo-swift-driver/tree/main/Examples/KituraExample), [Vapor](https://github.com/mongodb/mongo-swift-driver/tree/main/Examples/VaporExample), and [Perfect](https://github.com/mongodb/mongo-swift-driver/tree/main/Examples/PerfectExample).

Please note that the driver is built using SwiftNIO 2, and therefore is incompatible with frameworks built upon SwiftNIO 1. SwiftNIO 2 is used as of Vapor 4.0 and Kitura 2.5.

## Development Instructions

See our [development guide](https://github.com/mongodb/mongo-swift-driver/blob/main/Guides/Development.md) for instructions for building and testing the driver.

