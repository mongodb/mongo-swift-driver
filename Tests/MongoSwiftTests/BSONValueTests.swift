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
        let swiftDoc: [String: BSONValue?] = [
            "hello": 42,
            "what is up": "nothing much man",
            "what is the meaning of life": nil as BSONValue?,
            "why is pizza so good": true
        ]

        let bsonMissingDoc: Document = [
            "hello": 42,
            "what is up": "nothing much man",
            "what is the meaning of life": nil,
            "why is pizza so good": true
        ]

        let bsonNullDoc: Document = [
            "hello": 42,
            "what is up": "nothing much man",
            "what is the meaning of life": BSONNull(),
            "why is pizza so good": true
        ]

        let bsonBothDoc: Document = [
            "hello": 42,
            "what is up": "nothing much man",
            "what is the meaning of life": BSONNull(),
            "why is pizza so good": true
        ]

        // use cases
        // 1. Get existing key's value from document and using it:
        usingExistingKeyValue(swiftDoc, bsonMissingDoc, bsonNullDoc, bsonBothDoc)

        // 2. Distinguishing between nil value for key, missing value for key, and existing value for key
        distinguishingValueKinds(swiftDoc, bsonMissingDoc, bsonNullDoc, bsonBothDoc)

        // 3. Getting the value for a key, where the value is nil
        gettingNilKeyValue(swiftDoc, bsonMissingDoc, bsonNullDoc, bsonBothDoc)
    }

    func usingExistingKeyValue(_ swiftDoc: [String: BSONValue?], _ testDocs: Document...) {
        let (bsonMissingDoc, bsonNullDoc, bsonBothDoc) = getTestingDocuments(testDocs)

        let existingBSONMissing = bsonMissingDoc["hello"] as? Int
        debugPrint("Got back existing key value from bsonMissingDoc: \(String(describing: existingBSONMissing))")
        if let existingBSONMissing = existingBSONMissing {
            let sumDoc = existingBSONMissing + 10
            debugPrint("sumDoc: \(sumDoc)")
        }

        let existingSwift = swiftDoc["hello"] as? Int
        debugPrint("Got back existing key value from swiftDoc: \(String(describing: existingSwift))")
        if let existingSwift = existingSwift {
            let sumDict = existingSwift + 10
            debugPrint("sumDoc: \(sumDict)")
        }

        let existingBSONNull = bsonNullDoc["hello"] as? Int
        debugPrint("Got back existing key value from bsonNullDoc: \(String(describing: existingBSONNull))")
        if let existingBSONNull = existingBSONNull {
            let sumDict = existingBSONNull + 10
            debugPrint("sumDoc: \(sumDict)")
        }

        let existingBSONBoth = bsonBothDoc["hello"] as? Int
        debugPrint("Got back existing key value from bsonBothDoc: \(String(describing: existingBSONBoth))")
        if let existingBSONBoth = existingBSONBoth {
            let sumDict = existingBSONBoth + 10
            debugPrint("sumDoc: \(sumDict)")
        }
    }

    func distinguishingValueKinds(_ swiftDoc: [String: BSONValue?], _ testDocs: Document...) {
        let (bsonMissingDoc, bsonNullDoc, bsonBothDoc) = getTestingDocuments(testDocs)
        let keys = ["hello", "i am missing", "what is the meaning of life"]

        print("BSONMissing =========================")
        for key in keys {
            let keyVal = bsonMissingDoc[key]
            if let keyVal = keyVal, keyVal == BSONMissing() {
                debugPrint("Key DNE!")
            } else if keyVal != nil {
                debugPrint("Key exists!")
            } else {
                debugPrint("Key is null!")
            }
        }

        print("SWIFT (BSONValue?) =====================")
        for key in keys {
            let keyVal = swiftDoc[key]
            if let keyVal = keyVal {
                if keyVal == nil {
                    debugPrint("Key is null!")
                } else {
                    debugPrint("Key exists!")
                }
            } else {
                debugPrint("Key DNE!")
            }
        }

        print("BSONNull =====================")
        for key in keys {
            let keyVal = bsonNullDoc[key]
            if let keyVal = keyVal, keyVal == BSONNull() {
                debugPrint("Key is null!")
            } else if keyVal != nil {
                debugPrint("Key exists!")
            } else {
                debugPrint("Key DNE!")
            }
        }

        print("Both BSONNull and BSONMissing ==========s===========")
        for key in keys {
            let keyVal = bsonBothDoc[key]
            debugPrint("\(key) -> \(keyVal)")
            if let keyVal = keyVal, keyVal == BSONNull() {
                debugPrint("Key is null!")
            } else if let keyVal = keyVal, keyVal == BSONMissing() {
                debugPrint("Key DNE!")
            } else {
                debugPrint("Key exists!")
            }
        }
    }

    func gettingNilKeyValue(_ swiftDoc: [String: BSONValue?], _ testDocs: Document...) {
        let (bsonMissingDoc, bsonNullDoc, bsonBothDoc) = getTestingDocuments(testDocs)

        let bsonMissingVal = bsonMissingDoc["what is the meaning of life"]
        if bsonMissingVal == nil {
            debugPrint("Got back null val from doc: \(String(describing: bsonMissingVal))")
        }

        let swiftVal = swiftDoc["what is the meaning of life"]
        if let swiftVal = swiftVal {
            if swiftVal == nil {
                debugPrint("Got back null val from dict: \(String(describing: swiftVal))")
            }
        }

        let bsonNullVal = bsonNullDoc["what is the meaning of life"]
        if let bsonNullVal = bsonNullVal {
            if bsonNullVal == BSONNull() {
                debugPrint("Got back null val from doc: \(String(describing: bsonNullVal))")
            }
        }

        let bsonBothVal = bsonBothDoc["what is the meaning of life"]
        if let bsonBothVal = bsonBothVal {
            if bsonBothVal == BSONNull() {
                debugPrint("Got back null val from doc: \(String(describing: bsonBothVal))")
            }
        }
    }

    func getTestingDocuments(_ documents: [Document]) -> (Document, Document, Document) {
        return (documents[0], documents[1], documents[2])
    }
}
