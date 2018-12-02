import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class BSONValueTests: MongoSwiftTestCase {
    static var allTests: [(String, (BSONValueTests) -> () throws -> Void)] {
        return [
            ("testInvalidDecimal128", testInvalidDecimal128),
            ("testUUIDBytes", testUUIDBytes),
            ("testBSONEquals", testBSONEquals),
            ("testObjectIdRoundTrip", testObjectIdRoundTrip)
        ]
    }

    func testInvalidDecimal128() throws {
        expect(Decimal128(ifValid: "hi")).to(beNil())
        expect(Decimal128(ifValid: "123.4.5")).to(beNil())
        expect(Decimal128(ifValid: "10")).toNot(beNil())
    }

    func testUUIDBytes() throws {
        let twoBytes = Data(base64Encoded: "//8=")!
        let sixteenBytes = Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==")!

        // UUIDs must have 16 bytes
        expect(try Binary(data: twoBytes, subtype: .uuidDeprecated)).to(throwError())
        expect(try Binary(data: twoBytes, subtype: .uuid)).to(throwError())
        expect(try Binary(data: sixteenBytes, subtype: .uuidDeprecated)).toNot(throwError())
        expect(try Binary(data: sixteenBytes, subtype: .uuid)).toNot(throwError())
    }

    fileprivate func checkTrueAndFalse(val: BSONValue, alternate: BSONValue) {
        expect(val).to(bsonEqual(val))
        expect(val).toNot(bsonEqual(alternate))
    }

    func testBSONEquals() throws {
        // Int
        checkTrueAndFalse(val: 1, alternate: 2)
        // Int32
        checkTrueAndFalse(val: Int32(32), alternate: Int32(33))
        // Int64
        checkTrueAndFalse(val: Int64(64), alternate: Int64(65))
        // Double
        checkTrueAndFalse(val: 1.618, alternate: 2.718)
        // Decimal128
        checkTrueAndFalse(val: Decimal128("1.618"), alternate: Decimal128("2.718"))
        // Bool
        checkTrueAndFalse(val: true, alternate: false)
        // String
        checkTrueAndFalse(val: "some", alternate: "not some")
        // RegularExpression
        checkTrueAndFalse(
            val: RegularExpression(pattern: ".*", options: ""),
            alternate: RegularExpression(pattern: ".+", options: "")
        )
        // Timestamp
        checkTrueAndFalse(val: Timestamp(timestamp: 1, inc: 2), alternate: Timestamp(timestamp: 5, inc: 10))
        // Date
        checkTrueAndFalse(
            val: Date(timeIntervalSinceReferenceDate: 5000),
            alternate: Date(timeIntervalSinceReferenceDate: 5001)
        )
        // MinKey & MaxKey
        expect(MinKey()).to(bsonEqual(MinKey()))
        expect(MaxKey()).to(bsonEqual(MaxKey()))
        // ObjectId
        checkTrueAndFalse(val: ObjectId(), alternate: ObjectId())
        // CodeWithScope
        checkTrueAndFalse(
            val: CodeWithScope(code: "console.log('foo');"),
            alternate: CodeWithScope(code: "console.log(x);", scope: ["x": 2])
        )
        // Binary
        checkTrueAndFalse(
            val: try Binary(data: Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==")!, subtype: .uuid),
            alternate: try Binary(data: Data(base64Encoded: "c//88KLnfdfefOfR33ddFA==")!, subtype: .uuid)
        )
        // Document
        checkTrueAndFalse(
            val: [
                "foo": 1.414,
                "bar": "swift",
                "nested": [ "a": 1, "b": "2" ] as Document
                ] as Document,
            alternate: [
                "foo": 1.414,
                "bar": "swift",
                "nested": [ "a": 1, "b": "different" ] as Document
                ] as Document
        )
        // [BSONValue?]
        checkTrueAndFalse(val: [4, 5, 1, nil, 3], alternate: [4, 5, 1, 2, 3])
        // Invalid Array type
        expect(bsonEquals([BSONEncoder()], [BSONEncoder(), BSONEncoder()])).to(beFalse())
        // Different types
        expect(4).toNot(bsonEqual("swift"))
    }

    func testObjectIdRoundTrip() throws {
        // alloc new bson_oid_t
        var oid_t = bson_oid_t()
        bson_oid_init(&oid_t, nil)

        // read the hex string of the oid_t
        var oid_c = [CChar].init(repeating: 0, count: 25)
        bson_oid_to_string(&oid_t, &oid_c)
        let oid = String.init(cString: &oid_c)

        // read the timestamp used to create the oid
        let timestamp = TimeInterval(bson_oid_get_time_t(&oid_t))

        // initialize a new oid with the oid_t ptr
        // expect the values to be equal
        let objectId = ObjectId.init(fromPointer: &oid_t)
        expect(objectId.oid).to(equal(oid))
        expect(objectId.timestamp).to(equal(timestamp))

        // round trip the objectId.
        // expect the encoded oid to equal the original
        let encoded = try BSONEncoder().encode(["_id": objectId])
        guard let _id = encoded["_id"] as? ObjectId else {
            fail("encoded document did not contain objectId _id")
            return
        }

        expect(_id.oid).to(equal(objectId.oid))
        expect(_id.timestamp).to(equal(objectId.timestamp))

        // expect that we can pull the correct timestamp if
        // initialized from the original string
        let objectIdFromString = ObjectId.init(fromString: oid)
        expect(objectIdFromString.oid).to(equal(oid))
        expect(objectIdFromString.timestamp).to(equal(timestamp))
    }
}
