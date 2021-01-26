import CLibMongoC
import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

final class BSONPointerUtilsTests: MongoSwiftTestCase {
    func testWithBSONPointer() throws {
        let doc: BSONDocument = ["x": 1]
        doc.withBSONPointer { bsonPtr in
            guard let json = bson_as_relaxed_extended_json(bsonPtr, nil) else {
                XCTFail("failed to get extjson")
                return
            }
            defer { bson_free(json) }
            expect(String(cString: json)).to(equal("{ \"x\" : 1 }"))
        }
        expect(doc["x"]).to(equal(1))
    }

    func testBSONPointerInitializer() throws {
        let bson = bson_new()!
        defer { bson_free(bson) }

        guard bson_append_int32(bson, "x", Int32(1), 5) else {
            XCTFail("append failed")
            return
        }

        guard bson_append_int32(bson, "y", Int32(1), 5) else {
            XCTFail("append failed")
            return
        }

        let doc = BSONDocument(copying: bson)
        expect(doc).to(equal(["x": .int32(5), "y": .int32(5)]))
    }

    func testInitializeBSONObjectIDFromMongoCObjectID() throws {
        var oid = bson_oid_t()
        bson_oid_init(&oid, nil)

        let objectID = BSONObjectID(bsonOid: oid)

        var backOid = bson_oid_t()
        bson_oid_init_from_string(&backOid, objectID.description)

        // oid.bytes is stored as a tuple of 12 elements, which has no Equatable conformance
        // instead we just rely on the hash for equality
        expect(bson_oid_hash(&oid)).to(equal(bson_oid_hash(&backOid)))
        expect(oid.hex).to(equal(backOid.hex))
    }
}
