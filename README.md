[![Build Status](https://travis-ci.org/mongodb/mongo-swift-driver.svg?branch=master)](https://travis-ci.org/mongodb/mongo-swift-driver)
[![Code Coverage](https://codecov.io/gh/mongodb/mongo-swift-driver/branch/master/graph/badge.svg)](https://codecov.io/gh/mongodb/mongo-swift-driver/branch/master)

# MongoSwift
The official [MongoDB](https://www.mongodb.com/) driver for Swift.

### Index
- [Documentation](#documentation)
- [Bugs/Feature Requests](#bugs--feature-requests)
- [Installation](#installation)
    - [Step 1: Install the MongoDB C Driver](#step-1-install-the-mongodb-c-driver)
    - [Step 2: Install MongoSwift](#step-2-install-mongoswift)
- [Example Usage](#example-usage)
    - [Connect to MongoDB and Create a Collection](#connect-to-mongodb-and-create-a-collection)
    - [Create and Insert a Document](#create-and-insert-a-document)
    - [Find Documents](#find-documents)
    - [Work With and Modify Documents](#work-with-and-modify-documents)
    - [Usage With Kitura and Vapor](#usage-with-kitura-and-vapor)
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
`MongoSwift` works with Swift 5.0+ on MacOS and Linux.

Installation is supported via [Swift Package Manager](https://swift.org/package-manager/).

### Step 1: Install the MongoDB C Driver
The driver wraps the MongoDB C driver, and using it requires having the C driver's two components, `libbson` and `libmongoc`, installed on your system. **The minimum required version of the C Driver is 1.15.1**.

*On a Mac*, you can install both components at once using [Homebrew](https://brew.sh/):
`brew install mongo-c-driver`.

*On Linux*: please follow the [instructions](http://mongoc.org/libmongoc/current/installing.html#building-on-unix) from `libmongoc`'s documentation. Note that the versions provided by your package manager may be too old, in which case you can follow the instructions for building and installing from source.

See example installation from source on Ubuntu in [Docker](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/Docker).

### Step 2: Install MongoSwift
*Please follow the instructions in the previous section on installing the MongoDB C Driver before proceeding.*

Add MongoSwift to your dependencies in `Package.swift`:

```swift
// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", from: "VERSION.STRING.HERE"),
    ],
    targets: [
        .target(name: "MyPackage", dependencies: ["MongoSwift"])
    ]
)
```

Then run `swift build` to download, compile, and link all your dependencies.

## Example Usage

Note: You should call `cleanupMongoSwift()` exactly once at the end of your application to release all memory and other resources allocated by `libmongoc`.

### Connect to MongoDB and Create a Collection
```swift
import MongoSwift

let client = try MongoClient("mongodb://localhost:27017")
let db = client.db("myDB")
let collection = try db.createCollection("myCollection")

// free all resources
cleanupMongoSwift()
```

Note: we have included the client `connectionString` parameter for clarity, but if connecting to the default `"mongodb://localhost:27017"`it may be omitted: `let client = try MongoClient()`.

### Create and Insert a Document
```swift
let doc: Document = ["_id": 100, "a": 1, "b": 2, "c": 3]
let result = try collection.insertOne(doc)
print(result?.insertedId ?? "") // prints `.int64(100)`
```

### Find Documents
```swift
let query: Document = ["a": 1]
let documents = try collection.find(query)
for d in documents {
    print(d)
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
The `Examples/` directory contains sample projects that use the driver with [Kitura](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/Kitura), [Vapor](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/Vapor), and [Perfect](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/Perfect).

## Development Instructions

See our [development guide](https://mongodb.github.io/mongo-swift-driver/development.html) for instructions for building and testing the driver.

