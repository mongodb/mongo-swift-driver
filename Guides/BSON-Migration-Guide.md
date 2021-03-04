# Migrating from the 0.2.0 through 1.0.0-rc1 API to the 1.0 Driver API

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
