import Foundation
@testable import MongoSwift
import Nimble
import XCTest

final class BSONValueTests: XCTestCase {
    static var allTests: [(String, (BSONValueTests) -> () throws -> Void)] {
        return [
            ("testInvalidDecimal128", testInvalidDecimal128),
            ("testUUIDBytes", testUUIDBytes),
            ("testBSONEquals", testBSONEquals)
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

    func testBSONValues(val: BSONValue, alternate: BSONValue) {
        expect(bsonEqual(lhs: val, rhs: val)).to(beTrue())
        expect(bsonEqual(lhs: val, rhs: alternate)).to(beFalse())
    }

    func testBSONEquals() throws {
        // Int
        testBSONValues(val: 1, alternate: 2)
        // Int32
        testBSONValues(val: Int32(32), alternate: Int32(33))
        // Int64
        testBSONValues(val: Int64(64), alternate: Int64(65))
        // Double
        testBSONValues(val: 1.618, alternate: 2.718)
        // Decimal128
        testBSONValues(val: Decimal128("1.618"), alternate: Decimal128("2.718"))
        // Bool
        testBSONValues(val: true, alternate: false)
        // String
        testBSONValues(val: "some", alternate: "not some")
        // RegularExpression
        testBSONValues(
            val: RegularExpression(pattern: ".*", options: ""),
            alternate: RegularExpression(pattern: ".+", options: "")
        )
        // Timestamp
        testBSONValues(val: Timestamp(timestamp: 1, inc: 2), alternate: Timestamp(timestamp: 5, inc: 10))
        // Date
        testBSONValues(
            val: Date(timeIntervalSinceReferenceDate: 5000),
            alternate: Date(timeIntervalSinceReferenceDate: 5001)
        )
        // MinKey & MaxKey
        expect(bsonEqual(lhs: MinKey(), rhs: MinKey())).to(beTrue())
        expect(bsonEqual(lhs: MaxKey(), rhs: MaxKey())).to(beTrue())
        // ObjectId
        testBSONValues(val: ObjectId(), alternate: ObjectId())
        // CodeWithScope
        testBSONValues(
            val: CodeWithScope(code: "console.log('foo');"),
            alternate: CodeWithScope(code: "console.log(x);", scope: ["x": 2])
        )
        // Binary
        testBSONValues(
            val: try Binary(data: Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==")!, subtype: .uuid),
            alternate: try Binary(data: Data(base64Encoded: "c//88KLnfdfefOfR33ddFA==")!, subtype: .uuid)
        )
        // Document
        testBSONValues(
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
    }
}
