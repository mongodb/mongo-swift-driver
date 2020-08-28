import CLibMongoC
import Foundation
@testable import MongoSwift
import Nimble
@testable import SwiftBSON
import TestsCommon
import XCTest

final class BSONPointerUtilsTests: MongoSwiftTestCase {
    func testWithBSONPointer() throws {
        let doc: SwiftBSON.BSONDocument = ["x": 1]
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
        var bson = bson_new()!
        defer { bson_free(bson) }

        guard bson_append_int32(bson, "x", Int32(1), 5) else {
            XCTFail("append failed")
            return
        }

        guard bson_append_int32(bson, "y", Int32(1), 5) else {
            XCTFail("append failed")
            return
        }

        let doc = try SwiftBSON.BSONDocument(copying: bson)
        expect(doc).to(equal(["x": .int32(5), "y": .int32(5)]))
    }
}
