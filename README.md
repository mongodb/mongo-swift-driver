# MongoSwift
The official [MongoDB](https://www.mongodb.com/) driver for Swift.

### Index
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


## Bugs / Feature Requests

Think you’ve found a bug? Want to see a new feature in `mongo-swift-driver`? Please open a case in our issue management tool, JIRA:

1. Create an account and login: [jira.mongodb.org](https://jira.mongodb.org)
2. Navigate to the SWIFT project: [jira.mongodb.org/browse/SWIFT](https://jira.mongodb.org/browse/SWIFT)
3. Click **Create Issue** - Please provide as much information as possible about the issue and how to reproduce it.

Bug reports in JIRA for all driver projects (i.e. NODE, PYTHON, CSHARP, JAVA) and the
Core Server (i.e. SERVER) project are **public**.

## Installation

### FIRST: Install the MongoDB C Driver
Because the driver wraps the MongoDB C driver, using it requires having the C driver's two components, `libbson` and `libmongoc`, installed on your system. 

On a Mac, you can install both components at once using [Homebrew](https://brew.sh/): 
`brew install mongo-c-driver`

Or on Linux, use `apt-get` to install each:
`apt get libbson-dev`
 `apt get libmongoc-dev`

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
        .package(url: "https://github.com/10gen/mongo-swift-driver.git", from: "0.0.1"),
    ],
    targets: [
        Target(
            name: "MyPackage",
            dependencies: ["MongoSwift"])
    ]
)
```

Then run `swift build` to download, compile, and link all your dependencies. 

### OR: Install the Driver Using CocoaPods 
*Please make sure you have followed the instructions in the previous section on installing the MongoDB C Driver before proceeding.*

CocoaPods is a dependency manager for Swift and Objective-C. You can install it by running `gem install cocoapods`. See [the CocoaPods documentation](https://cocoapods.org/) for more information.

If you don't already have a `Podfile` for your project, run `pod init` in the main directory to automatically create one with smart defaults. Add `MongoSwift` as follows:

```ruby
platform :ios, '11.0'
use_frameworks!

target 'MyApp' do
    pod 'MongoSwift', '~> 0.0.1'
end
```

Finally, run `pod install` to install your project's dependencies. 

## Example Usage

### Connect to MongoDB and Create a Collection
```swift
import MongoSwift

let client = try MongoClient(connectionString: "mongodb://localhost:27017")
let db = try client.db("myDB")
let collection = try db.createCollection("myCollection")
```

### Create and Insert a Document
```swift
let doc: Document = ["_id": 100, "a": 1, "b": 2, "c": 3]
let result = try collection.insertOne(doc)
print(result?.insertedId ?? "") // prints `100`
```

### Find Documents
```swift
let query = ["a": 1]
let documents = try collection.find(query)
for d in documents {
    print(d)
}
```

### Work With and Modify Documents
```swift
let doc: Document = ["a": 1, "b": 2, "c": 3]

print(doc) // prints `{"a" : 1, "b" : 2, "c" : 3}`

print(doc["a"] ?? "") // prints `1`

// Set a new value
doc["d"] = 4
print(doc) // prints `{"a" : 1, "b" : 2, "c" : 3, "d" : 4}`
```