import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class BSONValueTests: MongoSwiftTestCase {
    func testInvalidDecimal128() throws {
        expect(Decimal128("hi")).to(beNil())
        expect(Decimal128("123.4.5")).to(beNil())
        expect(Decimal128("10")).toNot(beNil())
    }

    func testUUIDBytes() throws {
        let twoBytes = Data(base64Encoded: "//8=")!
        let sixteenBytes = Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==")!

        // UUIDs must have 16 bytes
        expect(try Binary(data: twoBytes, subtype: .uuidDeprecated))
                .to(throwError(UserError.invalidArgumentError(message: "")))
        expect(try Binary(data: twoBytes, subtype: .uuid)).to(throwError(UserError.invalidArgumentError(message: "")))
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
        checkTrueAndFalse(val: Decimal128("1.618")!, alternate: Decimal128("2.718")!)
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
        // Check that when an array contains non-BSONValues, we return false
        let arr = [[String: Int]()]
        expect(bsonEquals(arr, arr)).to(beFalse())

        // Different types
        expect(4).toNot(bsonEqual("swift"))

        // Arrays of different sizes should not be equal
        let b0: [BSONValue] = [1, 2]
        let b1: [BSONValue] = [1, 2, 3]
        expect(bsonEquals(b0, b1)).to(beFalse())
    }

    /// Test object for ObjectIdRoundTrip
    private struct TestObject: Codable {
        private let _id: ObjectId
        private let foo = "bar"

        init(id: ObjectId) {
            self._id = id
        }
    }

    func testObjectIdRoundTrip() throws {
        // alloc new bson_oid_t
        var oid_t = bson_oid_t()
        bson_oid_init(&oid_t, nil)

        // read the hex string of the oid_t
        var oid_c = [CChar](repeating: 0, count: 25)
        bson_oid_to_string(&oid_t, &oid_c)
        let oid = String(cString: &oid_c)

        // read the timestamp used to create the oid
        let timestamp = UInt32(bson_oid_get_time_t(&oid_t))

        // initialize a new oid with the oid_t ptr
        // expect the values to be equal
        let objectId = ObjectId(fromPointer: &oid_t)
        expect(objectId.oid).to(equal(oid))
        expect(objectId.timestamp).to(equal(timestamp))

        // round trip the objectId.
        // expect the encoded oid to equal the original
        let testObject = TestObject(id: objectId)
        let encodedTestObject = try BSONEncoder().encode(testObject)

        guard let _id = encodedTestObject["_id"] as? ObjectId else {
            fail("encoded document did not contain objectId _id")
            return
        }

        expect(_id.oid).to(equal(objectId.oid))
        expect(_id.timestamp).to(equal(objectId.timestamp))

        // expect that we can pull the correct timestamp if
        // initialized from the original string
        let objectIdFromString = ObjectId(fromString: oid)
        expect(objectIdFromString.oid).to(equal(oid))
        expect(objectIdFromString.timestamp).to(equal(timestamp))
    }

    /// Test AnyBSONValue Hashable conformance
    func testHashable() throws {
        let expected = try CodecTests.AllBSONTypes.factory()

        let values = Mirror(reflecting: expected).children.map { child in AnyBSONValue(child.value as! BSONValue) }
        let valuesSet = Set<AnyBSONValue>(values)

        expect(Set<Int>(valuesSet.map { abv in abv.hashValue }).count).to(equal(values.count))
        expect(valuesSet.count).to(equal(values.count))
        expect(values).to(contain(Array(valuesSet)))

        let abv1 = AnyBSONValue(Int32(1))
        let abv2 = AnyBSONValue(Int64(1))
        let abv3 = AnyBSONValue(Int32(5))

        var map: [AnyBSONValue: Int] = [abv1: 1, abv2: 2]

        expect(map[abv1]).to(equal(1))
        expect(map[abv2]).to(equal(2))

        map[abv1] = 4
        map[abv2] = 3
        map[abv3] = 5

        expect(map[abv1]).to(equal(4))
        expect(map[abv2]).to(equal(3))
        expect(map[abv3]).to(equal(5))

        let str = AnyBSONValue("world")
        let doc = AnyBSONValue(["value": str.value] as Document)
        let json = AnyBSONValue((doc.value as! Document).extendedJSON)

        map[str] = 12
        map[doc] = 13
        map[json] = 14

        expect(map[str]).to(equal(12))
        expect(map[doc]).to(equal(13))
        expect(map[json]).to(equal(14))

        expect(Set([str.hashValue, doc.hashValue, json.hashValue]).count).to(equal(3))
    }
}
