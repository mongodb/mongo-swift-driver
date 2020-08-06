# JSON Interoperability Guide
If you want to work with your MongoDB data as JSON, you can use Extended JSON.


Extended JSON is a string format for representing [BSON](bsonspec.org) documents, which is the format MongoDB uses.
For more information about working with BSON, 
see our [BSON Guide](https://github.com/mongodb/mongo-swift-driver/blob/master/Guides/BSON.md). 
ExtendedJSON allows you to have your database interact with a REST API or anything else that works with JSON. 
This is great for serving your MongoDB data to a client. This also allows you to look at your data in 
a readable and comprehensible form (unlike BSON). ExtendedJSON defines a standard way to represent all 
of the type info that BSON stores in the familiar JSON format. 

There are two types of Extended JSON: relaxed and canonical. 

The `ExtendedJSONEncoder` and `ExtendedJSONDecoder` provide a way for any custom `Codable` classes to interact with 
canonical or relaxed extended JSON.
 
See the example below for an overview of working with these classes. 
```swift
struct Person: Codable, Equatable {
    let name: String
    let age: Int32
}
let bob = Person(name: "Bob", age: 25)

// Try the canonical encoder
let encoder = ExtendedJSONEncoder()
encoder.mode = .canonical
let canonicalEncoded = try encoder.encode(bob) // "{\"name\":\"Bob\",\"age\":{\"$numberInt\":\"25\"}}"

// Try the relaxed encoder
encoder.mode = .relaxed
let relaxedEncoded = try encoder.encode(bob) // "{\"name\":\"Bob\",\"age\":25}}"

// Try decoding the results
let decoder = ExtendedJSONDecoder()
let canonicalExtJSON = "{\"name\":\"Bob\",\"age\":{\"$numberInt\":\"25\"}}"
let canonicalDecoded = try decoder.decode(Person.self, from: canonicalExtJSON.data(using: .utf8)!) // bob
let relaxedExtJSON = "{\"name\":\"Bob\",\"age\":25}}"
let relaxedDecoded = try decoder.decode(Person.self, from: relaxedExtJSON.data(using: .utf8)!) // bob
// you decode from relaxed or canonical extended json and get the same result back (bob in this case)
```
Invalid input to both the `encode` and `decode` methods will result in error messages describing the invalid portion of 
the input and what kind of input would be accepted in its place.

### Relaxed and Canonical Extended JSON

- _Relaxed Extended JSON_ - A string format based on the JSON standard that describes BSON documents. 
Relaxed Extended JSON emphasizes readability and interoperability at the expense of type preservation.

- _Canonical Extended JSON_ - A string format based on the JSON standard that describes BSON documents. 
Canonical Extended JSON emphasizes type preservation at the expense of readability and interoperability.

The example above illustrates the difference if you look at how the `age` field is represented in `canonicalExtJSON`
versus how it is represented in `relaxedExtJSON`. 

To see how all of the BSON types are represented in Canonical and Relaxed Extended JSON Format see this 
[Conversion Table](https://github.com/mongodb/specifications/blob/master/source/extended-json.rst#conversion-table).

A thorough example Canonical Extended JSON document and its relaxed counterpart can be found 
[here](https://github.com/mongodb/specifications/blob/master/source/extended-json.rst#canonical-extended-json-example).

### Vapor
If you are interested in using the `ExtendedJSONEncoder` and `ExtendedJSONDecoder` in your 
[Vapor](https://docs.vapor.codes/4.0/) app, you can set them as the default encoder and decoder and thereby allow your 
application to serialize data as ExtendedJSON, rather than the default plain JSON. 
This way you can more easily interact with MongoDB and take advantage of the added type information.

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

To see a some example Vapor Apps, check out
[/Examples/VaporExample](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/VaporExample) or 
[Examples/ComplexVaporExample](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples/ComplexVaporExample).

