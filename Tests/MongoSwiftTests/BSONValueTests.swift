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

    internal struct DocumentTest {
        public var header: String
        public var doc: Document

        public init(_ header: String, _ doc: Document) {
            self.header = header
            self.doc = doc
        }
    }

    static var swiftDocHeader = "SWIFT (BSONValue?) ================================="

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

        let docTests = [
            DocumentTest(
                "BSONMissing ========================================",
                [
                    BSONValueTests.hello: 42,
                    BSONValueTests.whatIsUp: "nothing much man",
                    BSONValueTests.meaningOfLife: nil,
                    BSONValueTests.pizza: true
                ]
            ),
            DocumentTest(
                "BSONNull ===========================================",
                 [
                    BSONValueTests.hello: 42,
                    BSONValueTests.whatIsUp: "nothing much man",
                    BSONValueTests.meaningOfLife: BSONNull(),
                    BSONValueTests.pizza: true
                 ]
            ),
            DocumentTest(
                "Both BSONNull and BSONMissing ======================",
                [
                    BSONValueTests.hello: 42,
                    BSONValueTests.whatIsUp: "nothing much man",
                    BSONValueTests.meaningOfLife: BSONNull(),
                    BSONValueTests.pizza: true
                ]
            ),
            DocumentTest(
                "NSNull ======================",
                [
                    BSONValueTests.hello: 42,
                    BSONValueTests.whatIsUp: "nothing much man",
                    BSONValueTests.meaningOfLife: NSNull(),
                    BSONValueTests.pizza: true
                ]
            )
        ]

        // use cases
        // 1. Get existing key's value from document and using it:
        usingExistingKeyValue(swiftDoc, docTests)

        // 2. Distinguishing between nil value for key, missing value for key, and existing value for key
        distinguishingValueKinds(swiftDoc, docTests)

        // 3. Getting the value for a key, where the value is nil
        gettingNilKeyValue(swiftDoc, docTests)
    }

    func usingExistingKeyValue(_ swiftDoc: [String: BSONValue?], _ testDocs: [DocumentTest]) {
        let (bsonMissing, bsonNull, bsonBoth, nsNull) = getDocumentTests(testDocs)
        let msg = "Got back existing key value from: "
        let sumDocMsg = "sumDoc: "

        print("\n=== EXISTING KEY VALUE ===\n")

        print(BSONValueTests.swiftDocHeader)
        let existingSwift = swiftDoc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingSwift))")
        if let existingSwift = existingSwift {
            let sumDict = existingSwift + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }

        print(bsonMissing.header)
        let existingBSONMissing = bsonMissing.doc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingBSONMissing))")
        if let existingBSONMissing = existingBSONMissing {
            let sumDoc = existingBSONMissing + 10
            debugPrint(sumDocMsg + "\(sumDoc)")
        }

        print(bsonNull.header)
        let existingBSONNull = bsonNull.doc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingBSONNull))")
        if let existingBSONNull = existingBSONNull {
            let sumDict = existingBSONNull + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }

        print(bsonBoth.header)
        let existingBSONBoth = bsonBoth.doc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingBSONBoth))")
        if let existingBSONBoth = existingBSONBoth {
            let sumDict = existingBSONBoth + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }

        print(nsNull.header)
        let existingNSNull = nsNull.doc["hello"] as? Int
        debugPrint(msg + "\(String(describing: existingNSNull))")
        if let existingNSNull = existingNSNull {
            let sumDict = existingNSNull + 10
            debugPrint(sumDocMsg + "\(sumDict)")
        }
    }

    func distinguishingValueKinds(_ swiftDoc: [String: BSONValue?], _ testDocs: [DocumentTest]) {
        let (bsonMissing, bsonNull, bsonBoth, nsNull) = getDocumentTests(testDocs)
        let keys = ["hello", "i am missing", "what is the meaning of life"]
        let (dne, exists, null) = ("Key DNE!", "Key exists!", "Key is null!")

        print("\n=== DISTINGUISHING VALUE KINDS ===\n")

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

        print(bsonMissing.header)
        for key in keys {
            let keyVal = bsonMissing.doc[key]
            if let keyVal = keyVal, keyVal == BSONMissing() {
                debugPrint(dne)
            } else if keyVal != nil {
                debugPrint(exists)
            } else {
                debugPrint(null)
            }
        }

        print(bsonNull.header)
        for key in keys {
            let keyVal = bsonNull.doc[key]
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
        print(bsonBoth.header)
        for key in keys {
            let keyVal = bsonBoth.doc[key]
            if let keyVal = keyVal, keyVal == BSONNull() {
                debugPrint(null)
            } else if let keyVal = keyVal, keyVal == BSONMissing() {
                debugPrint(dne)
            } else {
                debugPrint(exists)
            }
        }

        print(nsNull.header)
        for key in keys {
            let keyVal = nsNull.doc[key]
            if let keyVal = keyVal, keyVal == NSNull() {
                debugPrint(null)
            } else if keyVal != nil {
                debugPrint(exists)
            } else {
                debugPrint(dne)
            }
        }
    }

    func gettingNilKeyValue(_ swiftDoc: [String: BSONValue?], _ testDocs: [DocumentTest]) {
        let (bsonMissing, bsonNull, bsonBoth, nsNull) = getDocumentTests(testDocs)
        let nullKey = "what is the meaning of life"
        let msg = "Got back null val: "

        print("\n=== GETTING A NIL VALUE ===\n")

        print(BSONValueTests.swiftDocHeader)
        let swiftVal = swiftDoc[nullKey]
        if let swiftVal = swiftVal {
            if swiftVal == nil {
                debugPrint(msg + "\(String(describing: swiftVal))")
            }
        }

        print(bsonMissing.header)
        let bsonMissingVal = bsonMissing.doc[nullKey]
        if bsonMissingVal == nil {
            debugPrint(msg + "\(String(describing: bsonMissingVal))")
        }

        print(bsonNull.header)
        let bsonNullVal = bsonNull.doc[nullKey]
        if let bsonNullVal = bsonNullVal {
            if bsonNullVal == BSONNull() {
                debugPrint(msg + "\(String(describing: bsonNullVal))")
            }
        }

        print(bsonBoth.header)
        let bsonBothVal = bsonBoth.doc[nullKey]
        if let bsonBothVal = bsonBothVal {
            if bsonBothVal == BSONNull() {
                debugPrint(msg + "\(String(describing: bsonBothVal))")
            }
        }

        print(nsNull.header)
        let nsNullVal = nsNull.doc[nullKey]
        if let nsNullVal = nsNullVal {
            if nsNullVal == NSNull() {
                debugPrint(msg + "\(String(describing: nsNullVal))")
            }
        }
    }

    func getDocumentTests(_ tests: [DocumentTest]) -> (DocumentTest, DocumentTest, DocumentTest, DocumentTest) {
        return (tests[0], tests[1], tests[2], tests[3])
    }
}
