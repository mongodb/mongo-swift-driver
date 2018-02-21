import Foundation
@testable import MongoSwift
import XCTest

final class DocumentTests: XCTestCase {
    static var allTests: [(String, (DocumentTests) -> () throws -> Void)] {
        return [
            ("testDocument", testDocument),
            ("testEquatable", testEquatable),
            ("testRawBSON", testRawBSON),
            ("testExtendedJSON", testExtendedJSON)
        ]
    }

    func testDocument() {

        // A Data object to pass into test BSON Binary objects
        guard let testData = Data(base64Encoded: "//8=") else {
            XCTAssert(false, "Failed to create test binary data")
            return
        }

        // Since the NSRegularExpression constructor can throw, create the
        // regex separately first
        let regex: NSRegularExpression?
        let opts = NSRegularExpression.optionsFromString("imx")
        do {
            regex = try NSRegularExpression(pattern: "^abc", options: opts)
        } catch {
            XCTAssert(false, "Failed to create test NSRegularExpression")
            return
        }

        // Set up test document values
        let doc: Document = [
            "string": "test string",
            "true": true,
            "false": false,
            "int": 25,
            "int32": Int32(5),
            "int64": Int64(10),
            "double": Double(15),
            "decimal128": Decimal128("1.2E+10"),
            "minkey": MinKey(),
            "maxkey": MaxKey(),
            "date": Date(timeIntervalSince1970: 5000),
            "timestamp": Timestamp(timestamp: 5, inc: 10),
            "nestedarray": [[1, 2], [Int32(3), Int32(4)]] as [[Int32]],
            "nesteddoc": ["a": 1, "b": 2, "c": false, "d": [3, 4]] as Document,
            "oid": ObjectId(from: "507f1f77bcf86cd799439011"),
            "regex": regex,
            "array1": [1, 2],
            "array2": ["string1", "string2"],
            "null": nil,
            "code": CodeWithScope(code: "console.log('hi');"),
            "codewscope": CodeWithScope(code: "console.log(x);", scope: ["x": 2]),
            "binary0": Binary(data: testData, subtype: BsonSubtype.binary),
            "binary1": Binary(data: testData, subtype: BsonSubtype.function),
            "binary2": Binary(data: testData, subtype: BsonSubtype.binaryDeprecated),
            "binary3": Binary(data: testData, subtype: BsonSubtype.uuidDeprecated),
            "binary4": Binary(data: testData, subtype: BsonSubtype.uuid),
            "binary5": Binary(data: testData, subtype: BsonSubtype.md5),
            "binary6": Binary(data: testData, subtype: BsonSubtype.user)
        ]

        XCTAssertEqual(doc["string"] as? String, "test string")
        XCTAssertEqual(doc["true"] as? Bool, true)
        XCTAssertEqual(doc["false"] as? Bool, false)
        XCTAssertEqual(doc["int"] as? Int, 25)
        XCTAssertEqual(doc["int32"] as? Int, 5)
        XCTAssertEqual(doc["int64"] as? Int64, 10)
        XCTAssertEqual(doc["double"] as? Double, 15)
        XCTAssertEqual(doc["decimal128"] as? Decimal128, Decimal128("1.2E+10"))
        XCTAssertEqual(doc["minkey"] as? MinKey, MinKey())
        XCTAssertEqual(doc["maxkey"] as? MaxKey, MaxKey())
        XCTAssertEqual(doc["date"] as? Date, Date(timeIntervalSince1970: 5000))
        XCTAssertEqual(doc["timestamp"] as? Timestamp, Timestamp(timestamp: 5, inc: 10))
        XCTAssertEqual(doc["oid"] as? ObjectId, ObjectId(from: "507f1f77bcf86cd799439011"))

        let regexReturned = doc["regex"] as! NSRegularExpression
        XCTAssertEqual(regexReturned.pattern as String, "^abc")
        XCTAssertEqual(regexReturned.stringOptions as String, "imx")

        XCTAssertEqual(doc["array1"] as! [Int], [1, 2])
        XCTAssertEqual(doc["array2"] as! [String], ["string1", "string2"])
        XCTAssertNil(doc["null"])

        guard let code = doc["code"] as? CodeWithScope else {
            XCTAssert(false, "Failed to get CodeWithScope value")
            return
        }
        XCTAssertEqual(code.code, "console.log('hi');")
        XCTAssertNil(code.scope)

        guard let codewscope = doc["codewscope"] as? CodeWithScope else {
            XCTAssert(false, "Failed to get CodeWithScope with scope value")
            return
        }
        XCTAssertEqual(codewscope.code, "console.log(x);")
        guard let scope = codewscope.scope else {
            XCTAssert(false, "Failed to get scope value")
            return
        }
        XCTAssertEqual(scope["x"] as? Int, 2)

        XCTAssertEqual(doc["binary0"] as? Binary, Binary(data: testData, subtype: BsonSubtype.binary))
        XCTAssertEqual(doc["binary1"] as? Binary, Binary(data: testData, subtype: BsonSubtype.function))
        XCTAssertEqual(doc["binary2"] as? Binary, Binary(data: testData, subtype: BsonSubtype.binaryDeprecated))
        XCTAssertEqual(doc["binary3"] as? Binary, Binary(data: testData, subtype: BsonSubtype.uuidDeprecated))
        XCTAssertEqual(doc["binary4"] as? Binary, Binary(data: testData, subtype: BsonSubtype.uuid))
        XCTAssertEqual(doc["binary5"] as? Binary, Binary(data: testData, subtype: BsonSubtype.md5))
        XCTAssertEqual(doc["binary6"] as? Binary, Binary(data: testData, subtype: BsonSubtype.user))

        guard let nestedArray = doc["nestedarray"] as? [[Int]] else {
            XCTAssert(false, "Failed to get nested array")
            return
        }
        XCTAssertEqual(nestedArray.count, 2)
        XCTAssertEqual(nestedArray[0], [1, 2])
        XCTAssertEqual(nestedArray[1], [3, 4])

        guard let nestedDoc = doc["nesteddoc"] as? Document else {
            XCTAssert(false, "Failed to get nested document")
            return
        }
        XCTAssertEqual(nestedDoc["a"] as? Int, 1)
        XCTAssertEqual(nestedDoc["b"] as? Int, 2)
        XCTAssertEqual(nestedDoc["c"] as? Bool, false)
        XCTAssertEqual(nestedDoc["d"] as! [Int], [3, 4])

        let doc2 = Document(["hi": true, "hello": "hi", "cat": 2])
        XCTAssertEqual(doc2["hi"] as? Bool, true)
        XCTAssertEqual(doc2["hello"] as? String, "hi")
        XCTAssertEqual(doc2["cat"] as? Int, 2)

    }

    func testEquatable() {
        XCTAssertEqual(
            ["hi": true, "hello": "hi", "cat": 2] as Document,
            ["hi": true, "hello": "hi", "cat": 2] as Document
        )
    }

    func testRawBSON() {
        let doc = try? Document(fromJson: "{\"a\" : [{\"$numberInt\": \"10\"}]}")
        let rawBson = doc!.rawBson
        let fromRawBson = Document(fromBson: rawBson)
        XCTAssertEqual(doc, fromRawBson)
    }

    func testExtendedJSON() {
        do {
            var testFiles = try FileManager.default.contentsOfDirectory(atPath: "Tests/Specs/bson-corpus/tests")
            testFiles = testFiles.filter { $0.hasSuffix(".json") }

            for fileName in testFiles {
                let testFilePath = URL(fileURLWithPath: "Tests/Specs/bson-corpus/tests/\(fileName)")
                let testFileData = try String(contentsOf: testFilePath, encoding: .utf8)
                let testFileJson = try JSONSerialization.jsonObject(with: testFileData.data(using: .utf8)!, options: [])
                guard let json = testFileJson as? [String: Any] else {
                    XCTAssert(false, "Unable to convert json to dictionary")
                    return
                }

                guard let validCases = json["valid"] as? [Any] else {
                    continue // there are no valid cases defined in this file
                }

                for valid in validCases {
                    guard let validCase = valid as? [String: Any] else {
                        XCTFail("Unable to interpret valid case as dictionary")
                        return
                    }

                    guard let extJson = validCase["canonical_extjson"] as? String else {
                        XCTFail("Unable to interpret canonical extjson as string")
                        return
                    }

                    guard let doc = try? Document(fromJson: extJson) else {
                        XCTFail("Unable to parse extended json as Document")
                        return
                    }
                }
            }
        } catch {
            XCTFail("Test setup failed")
        }
    }
}
