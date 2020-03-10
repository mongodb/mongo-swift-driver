import Foundation

/// An extension of `Document` to implement the `Codable` protocol.
extension Document: Codable {
    public func encode(to encoder: Encoder) throws {
        guard let bsonEncoder = encoder as? _BSONEncoder else {
            throw bsonEncodingUnsupportedError(value: self, at: encoder.codingPath)
        }

        // directly add the `Document` to the encoder's storage.
        bsonEncoder.storage.containers.append(self)
    }

    /// This method will work with any `Decoder`, but for non-BSON
    /// decoders, we do not support decoding `Date`s, because of limitations
    /// of decoding to `AnyBSONValue`s. See `AnyBSONValue.init(from:)` for
    /// more information.
    public init(from decoder: Decoder) throws {
        // currently we only support decoding to a document using a BSONDecoder.
        guard let bsonDecoder = decoder as? _BSONDecoder else {
            throw getDecodingError(type: Document.self, decoder: decoder)
        }

        // we can just return the top container `Document`.
        let topContainer = bsonDecoder.storage.topContainer
        guard let doc = topContainer.documentValue else {
            throw DecodingError._typeMismatch(at: [], expectation: Document.self, reality: topContainer.bsonValue)
        }
        self = doc
    }
}
