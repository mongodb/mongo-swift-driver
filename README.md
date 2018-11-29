[![Build Status](https://travis-ci.org/mongodb/mongo-swift-driver.svg?branch=master)](https://travis-ci.org/mongodb/mongo-swift-driver)

# MongoSwift
The official [MongoDB](https://www.mongodb.com/) driver for Swift.

### Index
- [Documentation](#documentation)
- [Bugs/Feature Requests](#bugs--feature-requests)
- [Installation](#installation)
    - [FIRST: Install the MongoDB C Driver](#first-install-the-mongodb-c-driver)
    -  [NEXT: Install the Driver Using Swift Package Manager](#next-install-the-driver-using-swift-package-manager)
    - [OR: Install the Driver Using CocoaPods](#or-install-the-driver-using-cocoapods)
- [Example Usage](#example-usage)
    - [Connect to MongoDB and Create a Collection](#connect-to-mongodb-and-create-a-collection)
    - [Create and Insert a Document](#create-and-insert-a-document)
    - [Find Documents](#find-documents)
    - [Work With and Modify Documents](#work-with-and-modify-documents)
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
`MongoSwift` works with Swift 4.0+.

### FIRST: Install the MongoDB C Driver
Because the driver wraps the MongoDB C driver, using it requires having the C driver's two components, `libbson` and `libmongoc`, installed on your system. The minimum required version of the C Driver is **1.13.0**.

On a Mac, you can install both components at once using [Homebrew](https://brew.sh/):
`brew install mongo-c-driver`.

Or on Linux, use `apt-get` to install `libmongoc` (which includes `libbson` as a dependency) and `pkg-config` (which enables Swift Package Manager to find the components):
```
sudo apt-get install pkg-config
sudo apt-get install libmongoc-1.0.0
```

Alternatively, see the [installation guide](http://mongoc.org/libmongoc/current/installing.html) from libmongoc's documentation.

Next, see instructions for installation with either Swift Package Manager or CocoaPods in the following sections.

### NEXT: Install the Driver Using Swift Package Manager
*Please make sure you have followed the instructions in the previous section on installing the MongoDB C Driver before proceeding.*

The Swift Package Manager is integrated with the Swift build system in Swift 3.0+. See the [documentation](https://swift.org/package-manager/) for more information.

Add MongoSwift to your dependencies in `Package.swift`:

```swift
// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", from: "0.0.5"),
    ],
    targets: [
        .target(name: "MyPackage", dependencies: ["MongoSwift"])
    ]
)
```

Then run `swift build` to download, compile, and link all your dependencies.

### OR: Install the Driver Using CocoaPods
*Please make sure you have followed the instructions in the previous section on installing the MongoDB C Driver before proceeding.*

CocoaPods is a dependency manager for Swift and Objective-C. You can install it by running `gem install cocoapods`. See [the CocoaPods documentation](https://cocoapods.org/) for more information.

If you don't already have a `Podfile` for your project, run `pod init` in the main directory to automatically create one with smart defaults. Add `MongoSwift` as follows:

```ruby
platform :osx, '10.10'
use_frameworks!

target 'MyApp' do
    pod 'MongoSwift', '~> 0.0.2'
end
```

Finally, run `pod install` to install your project's dependencies.

## Example Usage

### Initialization
You *must* call `MongoSwift.initialize()` once at the start of your application to
initialize `libmongoc`. This initializes global state, such as process counters. Subsequent calls will have no effect.

You should call `MongoSwift.cleanup()` exactly once at the end of your application to release all memory and other resources allocated by `libmongoc`. `MongoSwift.initialize()`
will *not* reinitialize the driver after `MongoSwift.cleanup()`.

### Connect to MongoDB and Create a Collection
```swift
import MongoSwift

// initialize global state
MongoSwift.initialize()

let client = try MongoClient(connectionString: "mongodb://localhost:27017")
let db = try client.db("myDB")
let collection = try db.createCollection("myCollection")

// free all resources
MongoSwift.cleanup()
```

Note: we have included the client `connectionString` for clarity, but if connecting to the default `"mongodb://localhost:27017"`it may be omitted: `let client = try MongoClient()`.

### Create and Insert a Document
```swift
let doc: Document = ["_id": 100, "a": 1, "b": 2, "c": 3]
let result = try collection.insertOne(doc)
print(result?.insertedId ?? "") // prints `100`
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
print(doc["a"] ?? "") // prints `1`

// Set a new value
doc["d"] = 4
print(doc) // prints `{"a" : 1, "b" : 2, "c" : 3, "d" : 4}`

// Using functional methods like map, filter:
let evensDoc = doc.filter { elem in
    guard let value = elem.value as? Int else {
        return false
    }
    return value % 2 == 0
}
print(evensDoc) // prints `{ "b" : 2, "d" : 4 }`

let doubled = doc.map { elem -> Int in
    guard let value = elem.value as? Int else {
        return 0
    }

    return value * 2
}
print(doubled) // prints `[2, 4, 6, 8]`
```
Note that `Document` conforms to `Collection`, so useful methods from
[`Sequence`](https://developer.apple.com/documentation/swift/sequence) and
[`Collection`](https://developer.apple.com/documentation/swift/collection) are
all available. However, runtime guarantees are not yet met for many of these
methods.

## Development Instructions

See our [development guide](https://mongodb.github.io/mongo-swift-driver/development.html) for instructions for building and testing the driver.

