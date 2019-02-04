# Swift Driver Error Handling Guide

## Index
* [Error Types](#error-types)
    * [Server Errors](#server-errors)
    * [User Errors](#user-errors)
    * [Runtime Errors](#runtime-errors)
    * [Encoding/Decoding Errors](#encoding-decoding-errors)
* [Examples](#the-code)
    * [All Errors](#handling-any-error-thrown-by-the-driver)
    * [CommandError](#handling-a-commanderror)
    * [WriteError](#handling-a-writeerror)
    * [BulkWriteError](#handling-a-bulkwriteerror)
* [See Also](#see-also)

## Error Types
The driver uses errors to communicate that an operation failed, an assumption wasn't met, or that the user did something incorrectly. Applications that use the driver can in turn catch these errors and respond appropriately without crashing or resulting in an otherwise inconsistent state. To correctly model the different sources of errors, the driver defines three separate types of errors (`ServerError`, `UserError`, `RuntimeError`), each of which conforms to the `MongoError` protocol. These errors are defined in `MongoError.swift` and are outlined here. The documentation for every public function that throws lists some of the errors that could possibly be thrown and the reasons they might be. The errors listed there are not comprehensive but will generally cover the most common cases.

**Error Labels:** Some types of errors may contain more specific information describing the context in which they occured. This information is conveyed through the usage of `errorLabels`. Specifically, any server error or connection related error may contain labels. They are primarily used for classifying errors that occur when performing transactions, so at this point they will largely be unused.


### Server Errors
Server errors correspond to failures that occur in the database itself and are returned to the driver via some response to a command. Each `ServerError` case contains at least one error code representing what went wrong on the server.

For an enumeration of the possible server error codes, [see this list](https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.err).

The `ServerError` cases are as follows:
- `.commandError(code: ServerErrorCode, message: String, errorLabels: [String]?)`:
    - Thrown when commands experience errors server side that prevent execution.
    - Example command failures include failure to parse, operation aborted by the user, and unexpected errors during execution.
- `.writeError(writeError: WriteError?, writeConcernError: WriteConcernError?, errorLabels: [String]?)`
    - Thrown when a single write command fails on the server.
    - Only one of the two optionals will be non-nil.
- `.bulkWriteError(writeErrors: [BulkWriteError]?, writeConcernError: WriteConcernError?, result: BulkWriteResult, errorLabels: [String]?)`
    - Thrown when the server returns errors as part of an executed bulk write.
    - If WriteConcernError is populated, writeErrors may not be.
    - **Note:** `InsertMany` throws a `.bulkWriteError`, _not_ a `.writeError`.


### User Errors
User applications can sometimes cause errors by using the driver incorrectly (e.g. by passing invalid argument combinations). This category of error covers those cases.

The `UserError` cases are as follows:
- `.logicError(message: String)`
    - Thrown when the user uses the driver incorrectly (e.g. advancing a dead cursor).
- `.invalidArgument(message: String)`
    - Thrown when user passes invalid arguments to some driver function.


### Runtime Errors
The driver may experience errors that happen at runtime unexpectedly. These errors don't fit neatly into the categories of occurring only server-side or only as part of the user's fault, so they are represented by their own set of cases.

The `RuntimeError` cases are as follows:
- `.internalError(message: String)`
    - Thrown when something is null when it shouldn't be, the driver has an internal failure, or MongoSwift cannot understand a server response.
    - This is generally indicative of a bug somewhere in the driver stack or a system related failure (e.g. memory allocation failure). If you experience an error that you think is the result of a bug, please file a bug report on GitHub or our Jira project.
- `.connectionError(message: String, errorLabels: [String]?)`
    - Thrown during any connection establishment / socket related errors.
- `.authenticationError(message: String)`
    - Thrown when the driver is not authorized to perform a requested command (e.g. due to invalid credentials)


### Encoding/Decoding Errors
As part of the driver, a BSON encoder and decoder pair is implemented according to the `Encoder` and `Decoder` protocols [defined by Apple](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types). User applications can use them to seamlessly convert between their Swift data structures and the BSON documents stored in the database. While this functionality is obviously useful to the users, the driver itself also makes heavy use of the encoder and decoder internally. During any encoding or decoding operations, errors can occur that prevent the data from being written to or read from BSON. In these cases, the driver throws an `EncodingError` or `DecodingError` as appropriate. These error types are not unique to MongoSwift and are commonly used by other encoder implementations, such as Foundation's `JSONEncoder`, so they do not conform to the `MongoError` protocol.

See the official documentation for both [`EncodingErrors`](https://developer.apple.com/documentation/swift/encodingerror) and [`DecodingErrors`](https://developer.apple.com/documentation/swift/decodingerror) for more information.


## Examples
### Handling any error thrown by the driver
```
do {
    // something involving the driver
} catch let error as MongoSwiftError {
    print("Driver error!")
    if let serverError = error as? ServerError { ... }
    else if let userError = error as? UserError { ... }
    else if let runtimeError = error as? RuntimeError { ... }
} catch is DecodingError {
    print("decoding error")
} catch is EncodingError {
    print("encoding error")
} catch { }
```

### Handling a CommandError
```
do {
    try db.runCommand(["asdfasdf": "sadfsadfasdf"])
} catch let ServerError.commandError(code, message, _) {
    print("Command failed: code: \(code) message: \(message)")
} catch { ... }
```
Output:
```
Command failed: code: 59 message: no such command: 'asdfasdf'
```

### Handling a WriteError
```
// if you want to ignore duplicate key errors
do {
    try coll.insertOne(["_id": 1])
    try coll.insertOne(["_id": 1])
} catch let ServerError.writeError(writeError, _, _) where writeError?.code == 11000 {
    print("duplicate key error: \(1) \(writeError?.message ?? "")")
}
```
Output:
```
duplicate key error: 1 E11000 duplicate key error collection: mydb.mycoll1 index: _id_ dup key: { : 1 }
```

### Handling a BulkWriteError
```
let docs: [Document] = [["_id": 2], ["_id": 1]]
do {
    try coll.insertOne(["_id": 1])
    try coll.insertMany(docs)
} catch let ServerError.bulkWriteError(writeErrors, _, result, _) {
    if let writeErrors = writeErrors {
        writeErrors.forEach { err in print("Write Error inserting \(docs[err.index]), code: \(err.code), message: \(err.message)") }
    }
    if let result = result {
        print("Result: ")
        print("nInserted: \(result.insertedCount)")
        print("InsertedIds: \(result.insertedIds))
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
