import Foundation
import libbson

/// Types that conform to the BsonEncodable protocol can be encoded to BSON. 
public protocol BsonEncodable {
    /**
    * Encodes this value to a BsonEncoder.
    *
    * - Parameters:
    *   - to: A `BsonEncoder` with which to encode this value
    */
    func encode(to encoder: BsonEncoder) throws
}

/// A BsonEncoder for encoding BsonEncodable types to BSON documents. 
public class BsonEncoder {
    private var _document: UnsafeMutablePointer<bson_t>!

    // since we have a lot of optional options we want to encode only
    // when they're non-nil, val is BsonValue? type so encode(to:) methods
    // can avoid checking each value individually
    func encode(_ val: BsonValue?, key: String) throws {
        if let v = val {
            assert(v.bsonAppend(data: _document, key: key))
        }
    }

    func encode(_ value: BsonEncodable) throws -> Document {
        _document = bson_new()
        try value.encode(to: self)
        return Document(fromData: _document)
    }
}
