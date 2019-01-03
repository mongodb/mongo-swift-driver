import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class AnyBSONValueTests: MongoSwiftTestCase {
    static var allTests: [(String, (AnyBSONValueTests) -> () throws -> Void)] {
        return [
            ("testHash", testHash)
        ]
    }

    func testHash() throws {
        let expected = CodecTests.AllBSONTypes(
            double: Double(2),
            string: "hi",
            doc: ["x": 1],
            arr: [1, 2],
            binary: try Binary(base64: "//8=", subtype: .generic),
            oid: ObjectId(fromString: "507f1f77bcf86cd799439011"),
            bool: true,
            date: Date(timeIntervalSinceReferenceDate: 5000),
            code: CodeWithScope(code: "hi", scope: ["x": 1]),
            int: 1,
            ts: Timestamp(timestamp: 1, inc: 2),
            int32: 5,
            int64: 6,
            dec: Decimal128("1.2E+10"),
            minkey: MinKey(),
            maxkey: MaxKey(),
            regex: RegularExpression(pattern: "^abc", options: "imx"))

        let mirror = Mirror(reflecting: expected)
        let children: [String: AnyBSONValue] = mirror.children.reduce(into: [:]) { (result, child) in
            guard let value = child.value as? BSONValue else {
                fail("AllBSONTypes struct contains non-BSON type")
                return
            }
            result[child.label!] = AnyBSONValue(value)
        }

        expect(children.count).to(equal(17))

        children.forEach { child in
            let (key, value) = child
            children.forEach {
                let eval = { (keyMatch: Bool, value1: AnyHashable, value2: AnyHashable) in
                    if keyMatch {
                        expect(value1.hashValue).to(equal(value2.hashValue))
                    } else {
                        expect(value1.hashValue).notTo(equal(value2.hashValue))
                    }
                }
                switch $0.value.value {
                case is Int, is Bool:
                    eval(value.value is Int || value.value is Bool || $0.key == key, $0.value, value)
                case is MinKey, is MaxKey:
                    eval(value.value is MinKey || value.value is MaxKey || $0.key == key, $0.value, value)
                default:
                    eval($0.key == key, $0.value, value)
                }
            }
        }

        let doc: [AnyHashable: AnyHashable] = [
            expected.double: Double(2),
            expected.string: "hi",
            expected.doc: ["x": 1] as Document,
            expected.binary: try Binary(base64: "//8=", subtype: .generic),
            expected.oid: ObjectId(fromString: "507f1f77bcf86cd799439011"),
            expected.bool: true,
            expected.date: Date(timeIntervalSinceReferenceDate: 5000),
            expected.code: CodeWithScope(code: "hi", scope: ["x": 1]),
            expected.int: 1,
            expected.ts: Timestamp(timestamp: 1, inc: 2),
            expected.int32: Int32(5),
            expected.int64: Int64(6),
            expected.dec: Decimal128("1.2E+10"),
            expected.maxkey: MaxKey(),
            expected.regex: RegularExpression(pattern: "^abc", options: "imx")
        ]

        expect(doc[expected.double]).to(equal(expected.double))
        expect(doc[expected.string]).to(equal(expected.string))
        expect(doc[expected.doc]).to(equal(expected.doc))
        expect(doc[expected.binary]).to(equal(expected.binary))
        expect(doc[expected.oid]).to(equal(expected.oid))
        expect(doc[expected.bool]).to(equal(expected.bool))
        expect(doc[expected.date]).to(equal(expected.date))
        expect(doc[expected.code]).to(equal(expected.code))
        expect(doc[expected.int]).to(equal(expected.int))
        expect(doc[expected.ts]).to(equal(expected.ts))
        expect(doc[expected.int32]).to(equal(expected.int32))
        expect(doc[expected.int64]).to(equal(expected.int64))
        expect(doc[expected.dec]).to(equal(expected.dec))
        expect(doc[expected.maxkey]).to(equal(expected.maxkey))
        expect(doc[expected.regex]).to(equal(expected.regex))

        let oid1 = ObjectId()
        let oid2 = ObjectId()

        let dict = [oid1: 1, oid2: 2]
        expect(dict[oid1]).to(equal(1))
        expect(dict[oid2]).to(equal(2))
    }
}
