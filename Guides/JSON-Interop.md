# JSON Interoperability Guide
It is often useful to convert data that was retrieved from MongoDB to JSON, either for producing a human readable 
version of it or for serving it up via a REST API. [BSON](bsonspec.org) (the format that MongoDB uses to store data) 
supports more types than JSON does though, which means JSON alone can't represent BSON data losslessly. To solve this issue, you can convert your data to [Extended JSON](https://docs.mongodb.com/manual/reference/mongodb-extended-json/), 
which is a standard format of JSON used by the various drivers to represent BSON data in JSON that includes extra 
information indicating the BSON type of a given value. If preserving the type information isn't required, 
then Foundation's `JSONEncoder` and `JSONDecoder` can be used to convert the data to regular JSON, though not all 
BSON types currently support working with them (e.g. `BSONBinary`).

## Extended JSON

As mentioned above, Extended JSON is a form of JSON that preserves type information. There are two forms of extended JSON, and the form used determines how much extra type information is included in the JSON format for a given type.

The two formats of extended JSON are as follows:
- _Relaxed Extended JSON_ - A string format based on the JSON standard that describes BSON documents. 
Relaxed Extended JSON emphasizes readability and interoperability at the expense of type preservation.
   -  example: `{"d": 5.5}`
- _Canonical Extended JSON_ - A string format based on the JSON standard that describes BSON documents. 
Canonical Extended JSON emphasizes type preservation at the expense of readability and interoperability.
    - example: `{"d": {"$numberDouble": 5.5}}`


Here we can see the same data: a key, `"i"` with the value `1` represented in BSON, and two forms of Extended JSON
```
// BSON
"0C0000001069000100000000"

// Relaxed Extended JSON
{"i": 1}

// Canonical Extended JSON
{"i": {"$numberInt":"1"}}
```
To see how all of the BSON types are represented in Canonical and Relaxed Extended JSON Format, see the documentation
[here](https://docs.mongodb.com/manual/reference/mongodb-extended-json/#bson-data-types-and-associated-representations). 

A thorough example Canonical Extended JSON document and its relaxed counterpart can be found 
[here](https://github.com/mongodb/specifications/blob/master/source/extended-json.rst#canonical-extended-json-example).

### Generating and Parsing Extended JSON via `Codable`
The `ExtendedJSONEncoder` and `ExtendedJSONDecoder` provide a way for any custom `Codable` classes to interact with 
canonical or relaxed extended JSON. They can be used just like `JSONEncoder` and `JSONDecoder`.
```swift
let encoder = ExtendedJSONEncoder()
let decoder = ExtendedJSONDecoder()

struct Person: Codable, Equatable {
    let name: String
    let age: Int32
}

let bobExtJSON = try encoder.encode(Person(name: "Bob", age: 25)) // "{\"name\":\"Bob\",\"age\":25}}"
let joe = try decoder.decode(Person.self, from: "{\"name\":\"Joe\",\"age\":34}}".data(using: .utf8)!)
```

The `ExtendedJSONEncoder` produces relaxed Extended JSON by default, but can be configured to produce canonical.
```swift
let bob = Person(name: "Bob", age: 25)
let encoder = ExtendedJSONEncoder()
encoder.mode = .canonical
let canonicalEncoded = try encoder.encode(bob) // "{\"name\":\"Bob\",\"age\":{\"$numberInt\":\"25\"}}"
```
The `ExtendedJSONDecoder` accepts either format, or a mix of both:
```swift
let decoder = ExtendedJSONDecoder()

let canonicalExtJSON = "{\"name\":\"Bob\",\"age\":{\"$numberInt\":\"25\"}}"
let canonicalDecoded = try decoder.decode(Person.self, from: canonicalExtJSON.data(using: .utf8)!) // bob

let relaxedExtJSON = "{\"name\":\"Bob\",\"age\":25}}"
let relaxedDecoded = try decoder.decode(Person.self, from: relaxedExtJSON.data(using: .utf8)!) // bob
```

### Using Extended JSON with Vapor
By default, [Vapor](https://docs.vapor.codes/4.0/) uses `JSONEncoder` and `JSONDecoder` for encoding and decoding its [`Content`](https://docs.vapor.codes/4.0/content/) to and from JSON.
If you are interested in using the `ExtendedJSONEncoder` and `ExtendedJSONDecoder` in your 
Vapor app instead, you can set them as the default encoder and decoder and thereby allow your 
application to serialize and deserialize data to/from Extended JSON, rather than the default plain JSON. 
This is recommended because not all BSON types currently support working with `JSONEncoder` and `JSONDecoder` and 
also so that you can take advantage of the added type information.
From the [Vapor Documentation](https://docs.vapor.codes/4.0/content/#override-defaults): 
you can set the global configuration and change the encoders and decoders Vapor uses by default 
by doing something like this: 

```swift
let encoder = ExtendedJSONEncoder()
let decoder = ExtendedJSONDecoder()
ContentConfiguration.global.use(encoder: encoder, for: .json)
ContentConfiguration.global.use(decoder: decoder, for: .json)
```
 in your `configure.swift`.
 
 In order for this to work, you will also have to include extensions that ensure conformance to Vapor's 
 `ContentEncoder` and `ContentDecoder` protocols. The snippets below should be sufficient for doing that.
 ```swift
extension ExtendedJSONEncoder: ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws 
        where E: Encodable
    {
        headers.contentType = .json
        try body.writeBytes(self.encode(encodable))
    }
}
 ```

```swift
extension ExtendedJSONDecoder: ContentDecoder {
   public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
       where D: Decodable
    {
        let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
        return try self.decode(D.self, from: data)
    }
}
 ```

To see some example Vapor apps using the driver, check out
[Examples/VaporExample](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/VaporExample) or 
[Examples/ComplexVaporExample](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/ComplexVaporExample).

## Using `JSONEncoder` and `JSONDecoder` with BSON Types

Currently, some BSON types (e.g. `BSONBinary`) do not support working with encoders and decoders other than those introduced in `swift-bson`, meaning Foundation's `JSONEncoder` and `JSONDecoder` will throw errors when encoding or decoding such types. There are plans to add general `Codable` support for all BSON types in the future, though. For now, only `BSONObjectID` and any BSON types defined in Foundation or the standard library (e.g. `Date` or `Int32`) will work with other encoder/decoder pairs. If type information is not required in the output JSON and only types that include a general `Codable` conformance are included in your data, you can use `JSONEncoder` and `JSONDecoder` to produce and ingest JSON data.

``` swift
let foo = Foo(x: BSONObjectID(), date: Date(), y: 3.5)
try JSONEncoder().encode(foo) // "{\"x\":<hexstring>,\"date\":<seconds since reference date>,\"y\":3.5}"
```
