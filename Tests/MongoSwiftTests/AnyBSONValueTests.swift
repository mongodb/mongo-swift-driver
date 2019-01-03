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
                switch $0.value.value {
                case is MinKey, is MaxKey:
                    if value.value is MinKey || value.value is MaxKey {
                        expect($0.value.hashValue).to(equal(value.hashValue))
                    } else {
                        fallthrough
                    }
                default:
                    if $0.key == key {
                        expect($0.value.hashValue).to(equal(value.hashValue))
                    } else {
                        expect($0.value.hashValue).notTo(equal(value.hashValue))
                    }
                }
            }
        }
    }
}
