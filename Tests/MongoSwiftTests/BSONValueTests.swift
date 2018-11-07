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

    static var (swiftDocHeader, bsonMissingHeader, bsonNullHeader, bsonBothHeader, nsNullHeader) = (
        "BSONMissing ========================================",
        "SWIFT (BSONValue?) =================================",
        "BSONNull ===========================================",
        "Both BSONNull and BSONMissing ======================",
        "NSNull ======================"
    )

    static var (hello, whatIsUp, meaningOfLife, pizza) = (
        "hello",
        "what is up",
        "what is the meaning of life",
        "why is pizza so good"
    )

    func testBSONInterfaces() throws {
        let swiftDoc: [String: BSONValue?] = [
            BSONValueTests.hello: 42,
            BSONValueTests.whatIsUp: "nothing much man",
            BSONValueTests.meaningOfLife: nil as BSONValue?,
            BSONValueTests.pizza: true
        ]

        let bsonMissingDoc: Document = [
            BSONValueTests.hello: 42,
            BSONValueTests.whatIsUp: "nothing much man",
            BSONValueTests.meaningOfLife: nil,
            BSONValueTests.pizza: true
        ]

        let bsonNullDoc: Document = [
            BSONValueTests.hello: 42,
            BSONValueTests.whatIsUp: "nothing much man",
            BSONValueTests.meaningOfLife: BSONNull(),
            BSONValueTests.pizza: true
        ]

        let bsonBothDoc: Document = [
            BSONValueTests.hello: 42,
            BSONValueTests.whatIsUp: "nothing much man",
            BSONValueTests.meaningOfLife: BSONNull(),
            BSONValueTests.pizza: true
        ]

        let nsNullDoc: Document = [
            BSONValueTests.hello: 42,
            BSONValueTests.whatIsUp: "nothing much man",
            BSONValueTests.meaningOfLife: NSNull(),
            BSONValueTests.pizza: true
        ]

        // use cases
        // 1. Get existing key's value from document and using it:
        usingExistingKeyValue(swiftDoc, bsonMissingDoc, bsonNullDoc, bsonBothDoc, nsNullDoc)

        // 2. Distinguishing between nil value for key, missing value for key, and existing value for key
        distinguishingValueKinds(swiftDoc, bsonMissingDoc, bsonNullDoc, bsonBothDoc, nsNullDoc)

        // 3. Getting the value for a key, where the value is nil
        gettingNilKeyValue(swiftDoc, bsonMissingDoc, bsonNullDoc, bsonBothDoc, nsNullDoc)
    }

    func usingExistingKeyValue(_ swiftDoc: [String: BSONValue?], _ testDocs: Document...) {
        let (bsonMissingDoc, bsonNullDoc, bsonBothDoc, nsNullDoc) = getTestingDocuments(testDocs)
        let msg = "Got back existing key value from: "
        let sumDocMsg = "sumDoc: "

        print("\n=== EXISTING KEY VALUE ===\n")

        print(BSONValueTests.bsonMissingHeader)
        let existingBSONMissing = bsonMissingDoc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingBSONMissing))")
        if let existingBSONMissing = existingBSONMissing {
            let sumDoc = existingBSONMissing + 10
            debugPrint(sumDocMsg + "\(sumDoc)")
        }

        print(BSONValueTests.bsonMissingHeader)
        let existingSwift = swiftDoc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingSwift))")
        if let existingSwift = existingSwift {
            let sumDict = existingSwift + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }

        print(BSONValueTests.bsonNullHeader)
        let existingBSONNull = bsonNullDoc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingBSONNull))")
        if let existingBSONNull = existingBSONNull {
            let sumDict = existingBSONNull + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }

        print(BSONValueTests.bsonBothHeader)
        let existingBSONBoth = bsonBothDoc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingBSONBoth))")
        if let existingBSONBoth = existingBSONBoth {
            let sumDict = existingBSONBoth + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }

        print(BSONValueTests.nsNullHeader)
        let existingNSNull = nsNullDoc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingNSNull))")
        if let existingNSNull = existingNSNull {
            let sumDict = existingNSNull + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }
    }

    func distinguishingValueKinds(_ swiftDoc: [String: BSONValue?], _ testDocs: Document...) {
        let (bsonMissingDoc, bsonNullDoc, bsonBothDoc, nsNullDoc) = getTestingDocuments(testDocs)
        let keys = ["hello", "i am missing", "what is the meaning of life"]
        let (dne, exists, null) = ("Key DNE!", "Key exists!", "Key is null!")

        print("\n=== DISTINGUISHING VALUE KINDS ===\n")

        print(BSONValueTests.bsonMissingHeader)
        for key in keys {
            let keyVal = bsonMissingDoc[key]
            if let keyVal = keyVal, keyVal == BSONMissing() {
                debugPrint(dne)
            } else if keyVal != nil {
                debugPrint(exists)
            } else {
                debugPrint(null)
            }
        }

        print(BSONValueTests.swiftDocHeader)
        for key in keys {
            let keyVal = swiftDoc[key]
            if let keyVal = keyVal {
                if keyVal == nil {
                    debugPrint(null)
                } else {
                    debugPrint(exists)
                }
            } else {
                debugPrint(dne)
            }
        }

        print(BSONValueTests.bsonNullHeader)
        for key in keys {
            let keyVal = bsonNullDoc[key]
            if let keyVal = keyVal, keyVal == BSONNull() {
                debugPrint(null)
            } else if keyVal != nil {
                debugPrint(exists)
            } else {
                debugPrint(dne)
            }
        }

        // Note that one can also combine NSNull with BSONMissing, the semantics are identical, with
        // BSONNull() -> NSNull().
        print(BSONValueTests.bsonBothHeader)
        for key in keys {
            let keyVal = bsonBothDoc[key]
            if let keyVal = keyVal, keyVal == BSONNull() {
                debugPrint(null)
            } else if let keyVal = keyVal, keyVal == BSONMissing() {
                debugPrint(dne)
            } else {
                debugPrint(exists)
            }
        }

        print(BSONValueTests.nsNullHeader)
        for key in keys {
            let keyVal = nsNullDoc[key]
            if let keyVal = keyVal, keyVal == NSNull() {
                debugPrint(null)
            } else if keyVal != nil {
                debugPrint(exists)
            } else {
                debugPrint(dne)
            }
        }
    }

    func gettingNilKeyValue(_ swiftDoc: [String: BSONValue?], _ testDocs: Document...) {
        let (bsonMissingDoc, bsonNullDoc, bsonBothDoc, nsNullDoc) = getTestingDocuments(testDocs)
        let nullKey = "what is the meaning of life"
        let msg = "Got back null val: "

        print("\n=== GETTING A NIL VALUE ===\n")

        print(BSONValueTests.bsonMissingHeader)
        let bsonMissingVal = bsonMissingDoc[nullKey]
        if bsonMissingVal == nil {
            debugPrint(msg + "\(String(describing: bsonMissingVal))")
        }

        print(BSONValueTests.swiftDocHeader)
        let swiftVal = swiftDoc[nullKey]
        if let swiftVal = swiftVal {
            if swiftVal == nil {
                debugPrint(msg + "\(String(describing: swiftVal))")
            }
        }

        print(BSONValueTests.bsonNullHeader)
        let bsonNullVal = bsonNullDoc[nullKey]
        if let bsonNullVal = bsonNullVal {
            if bsonNullVal == BSONNull() {
                debugPrint(msg + "\(String(describing: bsonNullVal))")
            }
        }

        print(BSONValueTests.bsonBothHeader)
        let bsonBothVal = bsonBothDoc[nullKey]
        if let bsonBothVal = bsonBothVal {
            if bsonBothVal == BSONNull() {
                debugPrint(msg + "\(String(describing: bsonBothVal))")
            }
        }

        print(BSONValueTests.nsNullHeader)
        let nsNullVal = nsNullDoc[nullKey]
        if let nsNullVal = nsNullVal {
            if nsNullVal == NSNull() {
                debugPrint(msg + "\(String(describing: nsNullVal))")
            }
        }
    }

    func getTestingDocuments(_ documents: [Document]) -> (Document, Document, Document, Document) {
        return (documents[0], documents[1], documents[2], documents[3])
    }
}
