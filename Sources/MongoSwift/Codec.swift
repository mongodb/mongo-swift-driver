import Foundation
import libbson

public protocol BsonEncodable {
    func encode(to encoder: BsonEncoder)
}

public class BsonEncoder {
    private var _document: UnsafeMutablePointer<bson_t>!

    // init(fromBsonT: UnsafeMutablePointer<bson_t>) {
    //     _document = fromBsonT
    // }

    // since we have a lot of optional options we want to encode only
    // when they're non-nil, val is BsonValue? type so encode(to:) methods
    // can avoid checking each value individually

    func encode(_ val: BsonValue?, key: String) {
        if let v = val {
            assert(v.bsonAppend(data: _document, key: key))
        }
    }

    func encode(_ value: BsonEncodable) -> UnsafeMutablePointer<bson_t> {
        _document = bson_new()
        value.encode(to: self)
        return _document
    }
}

public struct TestStruct: BsonEncodable {
    let sessionid: Int?
    let nameOnly: Bool?
    let id: String
    let arr: [String]

    public func encode(to encoder: BsonEncoder) {
        encoder.encode(sessionid, key: "sessionid")
        encoder.encode(nameOnly, key: "nameOnly")
        encoder.encode(id, key: "id")
        encoder.encode(arr, key: "arr")
    }
}
