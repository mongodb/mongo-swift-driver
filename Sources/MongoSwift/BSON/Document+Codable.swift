import Foundation

/// An extension of `Document` to implement the `Codable` protocol.
extension Document: Codable {
    public func encode(to encoder: Encoder) throws {
        // if we're using a `BsonEncoder`, we can just short-circuit
        // and directly add the `Document` to its storage.
        if let bsonEncoder = encoder as? _BsonEncoder {
            bsonEncoder.storage.containers.append(self)
            return
        }

        // otherwise, we need to go through each (key, value) pair,
        // and then wrap the values in `AnyBsonValue`s and encode them
        var container = encoder.container(keyedBy: _BsonKey.self)
        for (k, v) in self {
            let key = _BsonKey(stringValue: k)!
            if let val = AnyBsonValue(ifPresent: v) {
                try container.encode(val, forKey: key)
            } else {
                try container.encodeNil(forKey: key)
            }
        }
    }

    /// This method will work with any `Decoder`, but for non-BSON
    /// decoders, we do not support decoding `Date`s, because of limitations
    /// of decoding to `AnyBsonValue`s. See `AnyBsonValue.init(from:)` for 
    /// more information.
    public init(from decoder: Decoder) throws {
        // if it's a `BsonDecoder` we should just short-circuit and 
        // return the container `Document`
        if let bsonDecoder = decoder as? _BsonDecoder {
            let topContainer = bsonDecoder.storage.topContainer
            guard let doc = topContainer as? Document else {
                throw DecodingError._typeMismatch(at: [], expectation: Document.self, reality: topContainer)
            }
            self = doc
            return
        }

        // otherwise, get a keyed container and decode each key as an `AnyBsonValue`,
        // and then extract the wrapped `BsonValue`s and store them in the doc
        let container = try decoder.container(keyedBy: _BsonKey.self)
        var output = Document()
        for key in container.allKeys {
            let k = key.stringValue
            if try container.decodeNil(forKey: key) {
                output[k] = nil
            } else {
                output[k] = try container.decode(AnyBsonValue.self, forKey: key).value
            }
        }
        self = output
    }
}
