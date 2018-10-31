import Foundation
@testable import MongoSwift
import Nimble
import XCTest

final class BSONValueTests: XCTestCase {
    static var allTests: [(String, (BSONValueTests) -> () throws -> Void)] {
        return [
            ("testInvalidDecimal128", testInvalidDecimal128),
            ("testUUIDBytes", testUUIDBytes),
            ("testBSONEquals", testBSONEquals),
            ("testBSONInterfaces", testBSONInterfaces)
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

    func testBSONInterfaces() throws {
        var dict: [String: BSONValue?] = [:]
        dict["hello"] = 42
        dict["what is up"] = "nothing much man"
        dict["what is the meaning of life"] = nil as BSONValue?
        dict["why is pizza so good"] = true

        var doc: Document = [
            "hello": 42,
            "what is up": "nothing much man",
            "what is the meaning of life": nil,
            "why is pizza so good": true
        ]

        // use cases
        // 1. Get existing key's value from document:
        let existingKeyValueDoc = doc["hello"] as? Int
        debugPrint("Got back existing key value from doc: \(existingKeyValueDoc)")
        if let existingKeyValueDoc = existingKeyValueDoc {
            let sumDoc = existingKeyValueDoc + 10
            debugPrint("sumDoc: \(sumDoc)")
        }

        let existingKeyValueDict = dict["hello"] as? Int
        debugPrint("Got back existing key value from dict: \(existingKeyValueDict)")
        if let existingKeyValueDoc = existingKeyValueDoc {
            let sumDict = existingKeyValueDoc + 10
            debugPrint("sumDoc: \(sumDict)")
        }

        // 2. Distinguishing between nil value for key, missing value for key, and existing value for key
        let keys = ["hello", "i am missing", "what is the meaning of life"]
        print("DOING FOR DOC=========================")
        for key in keys {
            let keyVal = doc[key]
            if let keyVal = keyVal, keyVal == BSONMissing() {
                debugPrint("Key DNE!")
            } else if keyVal != nil {
                debugPrint("Key exists!")
            } else {
                debugPrint("Key is nil!")
            }
        }

        print("Doing for DICT=====================")
        for key in keys {
            let keyVal = dict[key]
            if let keyVal = keyVal {
                if keyVal == nil {
                    debugPrint("Key is nil!")
                } else {
                    debugPrint("Key exists!")
                }
            } else {
                debugPrint("Key DNE!")
            }
        }

        // 3. Getting the value for a key, where the value is nil

        let nulValDoc = doc["what is the meaning of life"]
        debugPrint("Got back null val from doc: \(nulValDoc)")

        let nulValDict = dict["what is the meaning of life"]
        if let nulValDict = nulValDict {
            debugPrint("Got back null val from dict: \(nulValDict)")
        }
    }
}
