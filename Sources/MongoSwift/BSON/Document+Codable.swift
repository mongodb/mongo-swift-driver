import Foundation

/// An extension of `Document` to implement the `Codable` protocol.
extension Document: Codable {
    public func encode(to encoder: Encoder) throws {
        // if we're using a `BSONEncoder`, we can just short-circuit
        // and directly add the `Document` to its storage.
        if let bsonEncoder = encoder as? _BSONEncoder {
            bsonEncoder.storage.containers.append(self)
            return
        }

        // otherwise, we need to go through each (key, value) pair,
        // and then wrap the values in `AnyBSONValue`s and encode them
        var container = encoder.container(keyedBy: _BSONKey.self)
        for (k, v) in self {
            // swiftlint:disable:next force_unwrapping
            let key = _BSONKey(stringValue: k)! // the initializer never actually returns nil.
            if v is BSONNull {
                try container.encodeNil(forKey: key)
            } else {
                let val = AnyBSONValue(v)
                try container.encode(val, forKey: key)
            }
        }
    }

    /// This method will work with any `Decoder`, but for non-BSON
    /// decoders, we do not support decoding `Date`s, because of limitations
    /// of decoding to `AnyBSONValue`s. See `AnyBSONValue.init(from:)` for
    /// more information.
    public init(from decoder: Decoder) throws {
        // if it's a `BSONDecoder` we should just short-circuit and
        // return the container `Document`
        if let bsonDecoder = decoder as? _BSONDecoder {
            let topContainer = bsonDecoder.storage.topContainer
            guard let doc = topContainer as? Document else {
                throw DecodingError._typeMismatch(at: [], expectation: Document.self, reality: topContainer)
            }
            self = doc
            return
        }

        // otherwise, get a keyed container and decode each key as an `AnyBSONValue`,
        // and then extract the wrapped `BSONValue`s and store them in the doc
        let container = try decoder.container(keyedBy: _BSONKey.self)
        var output = Document()
        for key in container.allKeys {
            let k = key.stringValue
            if try container.decodeNil(forKey: key) {
                try output.setValue(for: k, to: BSONNull())
            } else {
                let val = try container.decode(AnyBSONValue.self, forKey: key).value
                try output.setValue(for: k, to: val)
            }
        }
        self = output
    }
}
