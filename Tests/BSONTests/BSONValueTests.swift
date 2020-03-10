import CLibMongoC
import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
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
            .to(throwError(errorType: InvalidArgumentError.self))
        expect(try Binary(data: twoBytes, subtype: .uuid)).to(throwError(errorType: InvalidArgumentError.self))
        expect(try Binary(data: sixteenBytes, subtype: .uuidDeprecated)).toNot(throwError())
        expect(try Binary(data: sixteenBytes, subtype: .uuid)).toNot(throwError())
    }

    fileprivate func checkTrueAndFalse(val: BSON, alternate: BSON) {
        expect(val).to(equal(val))
        expect(val).toNot(equal(alternate))
    }

    func testBSONEquatable() throws {
        // Int
        self.checkTrueAndFalse(val: 1, alternate: 2)
        // Int32
        self.checkTrueAndFalse(val: .int32(32), alternate: .int32(33))
        // Int64
        self.checkTrueAndFalse(val: .int64(64), alternate: .int64(65))
        // Double
        self.checkTrueAndFalse(val: 1.618, alternate: 2.718)
        // Decimal128
        self.checkTrueAndFalse(val: .decimal128(Decimal128("1.618")!), alternate: .decimal128(Decimal128("2.718")!))
        // Bool
        self.checkTrueAndFalse(val: true, alternate: false)
        // String
        self.checkTrueAndFalse(val: "some", alternate: "not some")
        // RegularExpression
        self.checkTrueAndFalse(
            val: .regex(RegularExpression(pattern: ".*", options: "")),
            alternate: .regex(RegularExpression(pattern: ".+", options: ""))
        )
        // Timestamp
        self.checkTrueAndFalse(
            val: .timestamp(Timestamp(timestamp: 1, inc: 2)),
            alternate: .timestamp(Timestamp(timestamp: 5, inc: 10))
        )
        // Date
        self.checkTrueAndFalse(
            val: .datetime(Date(timeIntervalSinceReferenceDate: 5000)),
            alternate: .datetime(Date(timeIntervalSinceReferenceDate: 5001))
        )
        // MinKey & MaxKey
        expect(BSON.minKey).to(equal(.minKey))
        expect(BSON.maxKey).to(equal(.maxKey))
        // ObjectId
        self.checkTrueAndFalse(val: .objectId(ObjectId()), alternate: .objectId(ObjectId()))
        // CodeWithScope
        self.checkTrueAndFalse(
            val: .codeWithScope(CodeWithScope(code: "console.log('foo');", scope: [:])),
            alternate: .codeWithScope(CodeWithScope(code: "console.log(x);", scope: ["x": 2]))
        )
        // Binary
        self.checkTrueAndFalse(
            val: .binary(try Binary(data: Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==")!, subtype: .uuid)),
            alternate: .binary(try Binary(data: Data(base64Encoded: "c//88KLnfdfefOfR33ddFA==")!, subtype: .uuid))
        )
        // Document
        self.checkTrueAndFalse(
            val: [
                "foo": 1.414,
                "bar": "swift",
                "nested": ["a": 1, "b": "2"]
            ],
            alternate: [
                "foo": 1.414,
                "bar": "swift",
                "nested": ["a": 1, "b": "different"]
            ]
        )

        // Different types
        expect(BSON.int32(4)).toNot(equal("swift"))

        // Arrays of different sizes should not be equal
        let b0: BSON = [1, 2]
        let b1: BSON = [1, 2, 3]
        expect(b0).toNot(equal(b1))
    }

    /// Test object for ObjectIdRoundTrip
    private struct TestObject: Codable, Equatable {
        private let _id: ObjectId

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
        let objectId = ObjectId(bsonOid: oid_t)
        expect(objectId.hex).to(equal(oid))
        expect(objectId.timestamp).to(equal(timestamp))

        // round trip the objectId.
        // expect the encoded oid to equal the original
        let testObject = TestObject(id: objectId)
        let encodedTestObject = try BSONEncoder().encode(testObject)

        guard let _id = encodedTestObject["_id"]?.objectIdValue else {
            fail("encoded document did not contain objectId _id")
            return
        }

        expect(_id).to(equal(objectId))
        expect(_id.hex).to(equal(objectId.hex))
        expect(_id.timestamp).to(equal(objectId.timestamp))

        // expect that we can pull the correct timestamp if
        // initialized from the original string
        let objectIdFromString = ObjectId(oid)!
        expect(objectIdFromString).to(equal(objectId))
        expect(objectIdFromString.hex).to(equal(oid))
        expect(objectIdFromString.timestamp).to(equal(timestamp))
    }

    func testObjectIdJSONCodable() throws {
        let id = ObjectId()
        let obj = TestObject(id: id)
        let output = try JSONEncoder().encode(obj)
        let outputStr = String(decoding: output, as: UTF8.self)
        expect(outputStr).to(equal("{\"_id\":\"\(id.hex)\"}"))

        let decoded = try JSONDecoder().decode(TestObject.self, from: output)
        expect(decoded).to(equal(obj))

        // expect a decoding error when the hex string is invalid
        let invalidHex = id.hex.dropFirst()
        let invalidJSON = "{\"_id\":\"\(invalidHex)\"}".data(using: .utf8)!
        expect(try JSONDecoder().decode(TestObject.self, from: invalidJSON))
            .to(throwError(errorType: DecodingError.self))
    }

    struct BSONNumberTestCase {
        let int: Int?
        let double: Double?
        let int32: Int32?
        let int64: Int64?
        let decimal: Decimal128?

        static func compare<T: Equatable>(computed: T?, expected: T?) {
            guard computed != nil else {
                expect(expected).to(beNil())
                return
            }
            expect(computed).to(equal(expected))
        }

        func run() {
            let candidates: [BSON?] = [
                self.int.map { BSON(integerLiteral: $0) },
                self.double.map { .double($0) },
                self.int32.map { .int32($0) },
                self.int64.map { .int64($0) },
                self.decimal.map { .decimal128($0) }
            ]

            candidates.compactMap { $0 }.forEach { l in
                // Skip the Decimal128 conversions until they're implemented
                // TODO: don't skip these (SWIFT-367)
                guard l.decimal128Value == nil else {
                    return
                }

                BSONNumberTestCase.compare(computed: l.asInt(), expected: self.int)
                BSONNumberTestCase.compare(computed: l.asInt32(), expected: self.int32)
                BSONNumberTestCase.compare(computed: l.asInt64(), expected: self.int64)
                BSONNumberTestCase.compare(computed: l.asDouble(), expected: self.double)

                // Skip double for this conversion since it generates a Decimal128(5.0) =/= Decimal128(5)
                if l.doubleValue == nil {
                    BSONNumberTestCase.compare(computed: l.asDecimal128(), expected: self.decimal)
                }
            }
        }
    }

    func testBSONNumber() throws {
        let decimal128 = Decimal128("5.5")!
        let double: BSON = 5.5

        expect(double.asDouble()).to(equal(5.5))
        expect(double.asDecimal128()).to(equal(decimal128))

        let cases = [
            BSONNumberTestCase(int: 5, double: 5.0, int32: Int32(5), int64: Int64(5), decimal: Decimal128("5")!),
            BSONNumberTestCase(int: -5, double: -5.0, int32: Int32(-5), int64: Int64(-5), decimal: Decimal128("-5")!),
            BSONNumberTestCase(int: 0, double: 0.0, int32: Int32(0), int64: Int64(0), decimal: Decimal128("0")!),
            BSONNumberTestCase(int: nil, double: 1.234, int32: nil, int64: nil, decimal: Decimal128("1.234")!),
            BSONNumberTestCase(int: nil, double: -31.234, int32: nil, int64: nil, decimal: Decimal128("-31.234")!)
        ]

        cases.forEach { $0.run() }
    }
}
