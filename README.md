[![Build Status](https://travis-ci.org/mongodb/mongo-swift-driver.svg?branch=master)](https://travis-ci.org/mongodb/mongo-swift-driver)
[![Code Coverage](https://codecov.io/gh/mongodb/mongo-swift-driver/branch/master/graph/badge.svg)](https://codecov.io/gh/mongodb/mongo-swift-driver/branch/master)
[![sswg:sandbox|94x20](https://img.shields.io/badge/sswg-sandbox-lightgrey.svg)](https://github.com/swift-server/sswg/blob/master/process/incubation.md#sandbox-level)

# MongoSwift
The official [MongoDB](https://www.mongodb.com/) driver for Swift applications on macOS and Linux.

### Index
- [Documentation](#documentation)
- [Bugs/Feature Requests](#bugs--feature-requests)
- [Installation](#installation)
    - [Step 1: Install Required System Libraries (Linux Only)](#step-1-install-required-systems-libraries)
    - [Step 2: Install MongoSwift](#step-2-install-mongoswift)
- [Example Usage](#example-usage)
    - [Connect to MongoDB and Create a Collection](#connect-to-mongodb-and-create-a-collection)
    - [Create and Insert a Document](#create-and-insert-a-document)
    - [Find Documents](#find-documents)
    - [Work With and Modify Documents](#work-with-and-modify-documents)
    - [Usage With Kitura, Vapor, and Perfect](#usage-with-kitura-vapor-and-perfect)
- [Development Instructions](#development-instructions)

## Documentation
The latest documentation is available [here](https://mongodb.github.io/mongo-swift-driver/).

## Bugs / Feature Requests

Think you've found a bug? Want to see a new feature in `mongo-swift-driver`? Please open a case in our issue management tool, JIRA:

1. Create an account and login: [jira.mongodb.org](https://jira.mongodb.org)
2. Navigate to the SWIFT project: [jira.mongodb.org/browse/SWIFT](https://jira.mongodb.org/browse/SWIFT)
3. Click **Create Issue** - Please provide as much information as possible about the issue and how to reproduce it.

Bug reports in JIRA for all driver projects (i.e. NODE, PYTHON, CSHARP, JAVA) and the
Core Server (i.e. SERVER) project are **public**.

## Installation
The driver supports use with Swift 5.1+ on MacOS and Linux.

Installation is supported via [Swift Package Manager](https://swift.org/package-manager/).

### Step 1: Install Required System Libraries (Linux Only)
The driver vendors and wraps the MongoDB C driver (`libmongoc`), which depends on a number of external C libraries when built in Linux environments. As a result, these libraries must be installed on your system in order to build MongoSwift.

To install those libraries, please follow the [instructions](http://mongoc.org/libmongoc/current/installing.html#prerequisites-for-libmongoc) from `libmongoc`'s documentation.

### Step 2: Install MongoSwift
The driver contains two modules to support a variety of use cases: an asynchronous API in `MongoSwift`, and a synchronous API in `MongoSwiftSync`. The modules share a BSON implementation and a number of core types such as options `struct`s.

To install the driver, add the package and relevant module as a dependency in your project's `Package.swift` file:

```swift
// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", from: "VERSION.STRING.HERE"),
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
let doc: Document = ["_id": 100, "a": 1, "b": 2, "c": 3]
collection.insertOne(doc).whenSuccess { result in
    print(result?.insertedId ?? "") // prints `.int64(100)`
}
```

**Sync**:
```swift
let doc: Document = ["_id": 100, "a": 1, "b": 2, "c": 3]
let result = try collection.insertOne(doc)
print(result?.insertedId ?? "") // prints `.int64(100)`
```

### Find Documents
**Async**:
```swift
let query: Document = ["a": 1]
let result = collection.find(query).flatMap { cursor in
    cursor.forEach { doc in
        print(doc)
    }
}
```

**Sync**:
```swift
let query: Document = ["a": 1]
let documents = try collection.find(query)
for d in documents {
    print(try d.get())
}
```

### Work With and Modify Documents
```swift
var doc: Document = ["a": 1, "b": 2, "c": 3]

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

Note that `Document` conforms to `Collection`, so useful methods from
[`Sequence`](https://developer.apple.com/documentation/swift/sequence) and
[`Collection`](https://developer.apple.com/documentation/swift/collection) are
all available. However, runtime guarantees are not yet met for many of these
methods.

### Usage With Kitura, Vapor, and Perfect
The `Examples/` directory contains sample projects that use the driver with [Kitura](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/KituraExample), [Vapor](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/VaporExample), and [Perfect](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/PerfectExample).

Please note that the driver is built using SwiftNIO 2, and therefore is incompatible with frameworks built upon SwiftNIO 1. SwiftNIO 2 is used as of Vapor 4.0 and Kitura 2.5.

## Development Instructions

See our [development guide](https://github.com/mongodb/mongo-swift-driver/blob/master/Guides/Development.md) for instructions for building and testing the driver.

