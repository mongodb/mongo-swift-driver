# Swift Driver Error Handling Guide

## Index
* [Error Types](#error-types)
    * [Server Errors](#server-errors)
    * [User Errors](#user-errors)
    * [Runtime Errors](#runtime-errors)
    * [Error Labels](#error-labels)
    * [Encoding/Decoding Errors](#encoding-decoding-errors)
* [Examples](#the-code)
    * [All Errors](#handling-any-error-thrown-by-the-driver)
    * [CommandError](#handling-a-commanderror)
    * [WriteError](#handling-a-writeerror)
    * [BulkWriteError](#handling-a-bulkwriteerror)
* [See Also](#see-also)

## Error Types
The driver uses errors to communicate that an operation failed, an assumption wasn't met, or that the user did something incorrectly. Applications that use the driver can in turn catch these errors and respond appropriately without crashing or resulting in an otherwise inconsistent state. To correctly model the different sources of errors, the driver defines three separate caregories of errors (`ServerError`, `UserError`, `RuntimeError`), each of which are protocols that inherit from the `MongoError` protocol. These protocols are defined in `MongoError.swift`, and the structs that conform to them are outlined here. The documentation for every public function that throws lists some of the errors that could possibly be thrown and the reasons they might be. The errors listed there are not comprehensive but will generally cover the most common cases.


### Server Errors
Server errors correspond to failures that occur in the database itself and are returned to the driver via some response to a command. Each error that conforms to `ServerError` contains at least one error code representing what went wrong on the server.

For an enumeration of the possible server error codes, [see this list](https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.yml).

The possible errors that conform to `ServerError` are as follows:
- `CommandError`:
    - Thrown when commands experience errors server side that prevent execution.
    - Example command failures include failure to parse, operation aborted by the user, and unexpected errors during execution.
- `WriteError`
    - Thrown when a single write command fails on the server (e.g. insertOne, updateOne, updateMany).
- `BulkWriteError`
    - Thrown when the server returns errors as part of an executed bulk write.
    - If WriteConcernFailure is populated, writeErrors may not be.
    - **Note:** `InsertMany` throws a `BulkWriteError`, _not_ a `WriteError`.


### User Errors
User applications can sometimes cause errors by using the driver incorrectly (e.g. by passing invalid argument combinations). This category of error covers those cases.

The possible errors that conform to `UserError` are as follows:
- `LogicError`
    - Thrown when the user uses the driver incorrectly (e.g. advancing a dead cursor).
- `InvalidArgumentError`
    - Thrown when user passes invalid arguments to some driver function.


### Runtime Errors
The driver may experience errors that happen at runtime unexpectedly. These errors don't fit neatly into the categories of occurring only server-side or only as part of the user's fault, so they are represented by their own set of cases.

The `RuntimeError` cases are as follows:
- `InternalError`
    - Thrown when something is null when it shouldn't be, the driver has an internal failure, or MongoSwift cannot understand a server response.
    - This is generally indicative of a bug somewhere in the driver stack or a system related failure (e.g. a memory allocation failure). If you experience an error that you think is the result of a bug, please file a bug report on GitHub or our Jira project.
- `ConnectionError`
    - Thrown during any connection establishment / socket related errors.
    - This error also conforms to `LabeledError`.
- `AuthenticationError`
    - Thrown when the driver is not authorized to perform a requested command (e.g. due to invalid credentials)
- `ServerSelectionError`
    - Thrown when the driver was unable to select a server for an operation (e.g. due to a timeout or unsatisfiable read preference)
    - See [the official MongoDB documentation](https://docs.mongodb.com/manual/core/read-preference-mechanics/) for more information.


### Error Labels
Some types of errors may contain more specific information describing the context in which they occured. Such errors conform to the `LabeledError` protocol, and the extra information is conveyed through the `errorLabels` property. Specifically, any server error or connection related error may contain labels.

The following error labels are currently defined. Future versions of MongoDB may introduce new labels:
- `TransientTransactionError`:
    - Within a multi-document transaction, certain errors can leave the transaction in an unknown or aborted state. These include write conflicts, primary stepdowns, and network errors. In response, the application should abort the transaction and try the same sequence of operations again in a new transaction.
- `UnknownTransactionCommitResult`:
    - When `commitTransaction()` encounters a network error or certain server errors, it is not known whether the transaction was committed. Applications should attempt to commit the transaction again until (i) the commit succeeds, (ii) the commit fails with an error *not* labeled `UnknownTransactionCommitResult`, or (iii) the application chooses to give up.


### Encoding/Decoding Errors
As part of the driver, `BSONEncoder` and `BSONDecoder` are implemented according to the `Encoder` and `Decoder` protocols [defined in Apple's Foundation](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types). User applications can use them to seamlessly convert between their Swift data structures and the BSON documents stored in the database. While this functionality is part of the public API, the driver itself also makes heavy use of it internally. During any encoding or decoding operations, errors can occur that prevent the data from being written to or read from BSON. In these cases, the driver throws an `EncodingError` or `DecodingError` as appropriate. These error types are not unique to MongoSwift and are commonly used by other encoder implementations, such as Foundation's `JSONEncoder`, so they do not conform to the `MongoError` protocol or any of the other error protocols defined in the driver.

See the official documentation for both [`EncodingErrors`](https://developer.apple.com/documentation/swift/encodingerror) and [`DecodingErrors`](https://developer.apple.com/documentation/swift/decodingerror) for more information.


## Examples
### Handling any error thrown by the driver
```swift
do {
    // something involving the driver
} catch let error as MongoError {
    print("Driver error!")
    switch error.self {
    case let runtimeError as RuntimeError:
        // handle RuntimeError
    case let serverError as ServerError:
        // handle ServerError
    case let userError as UserError:
        // handle UserError
    default:
        // should never get here
    }
} catch let error as DecodingError {
    // handle DecodingError
} catch let error as EncodingError {
    // handle EncodingError
} catch { ... }
```

### Handling a CommandError
```swift
do {
    try db.runCommand(["asdfasdf": "sadfsadfasdf"])
} catch let commandError as CommandError {
    print("Command failed: code: \(commandError.code) message: \(commandError.message)")
} catch { ... }
```
Output:
```
Command failed: code: 59 message: no such command: 'asdfasdf'
```

### Handling a WriteError
```swift
// if you want to ignore duplicate key errors
do {
    try coll.insertOne(["_id": 1])
    try coll.insertOne(["_id": 1])
} catch let writeError as WriteError where writeError.writeFailure?.code == 11000 {
    print("duplicate key error: \(1) \(writeError.writeFailure?.message ?? "")")
}
```
Output:
```
duplicate key error: 1 E11000 duplicate key error collection: mydb.mycoll1 index: _id_ dup key: { : 1 }
```

### Handling a BulkWriteError
```swift
let docs: [Document] = [["_id": 2], ["_id": 1]]
do {
    try coll.insertOne(["_id": 1])
    try coll.insertMany(docs)
} catch let bwe as BulkWriteError {
    if let writeErrors = bwe.writeFailures {
        writeErrors.forEach { err in print("Write Error inserting \(docs[err.index]), code: \(err.code), message: \(err.message)") }
    }
    if let result = bwe.result {
        print("Result: ")
        print("nInserted: \(result.insertedCount)")
        print("InsertedIds: \(result.insertedIds)")
    }
} catch { ... }
```
Output:
```
Write Error inserting { "_id" : 1 }, code: 11000, message: E11000 duplicate key error collection: mydb.mycoll1 index: _id_ dup key: { : 1 }
Result:
nInserted: 1
InsertedIds: [0: 2]
```
## See Also
- [Error handling in Swift](https://docs.swift.org/swift-book/LanguageGuide/ErrorHandling.html)
- [List of server error codes](https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err)
- [CRUD Spec error definitions](https://github.com/mongodb/specifications/blob/master/source/crud/crud.rst#error-handling)
- [EncodingError documentation](https://developer.apple.com/documentation/swift/encodingerror)
- [DecodingError documentation](https://developer.apple.com/documentation/swift/decodingerror)
