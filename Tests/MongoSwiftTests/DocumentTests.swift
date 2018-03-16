import Foundation
@testable import MongoSwift
import XCTest

/// Useful extensions to the Data type for testing purposes
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }

        self = data
    }

    var hexDescription: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}

/// Cleans and normalizes a given JSON string for comparison purposes
func clean(json: String) -> String {
    do {
        let object = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!, options: [])
        let data = try JSONSerialization.data(withJSONObject: object, options: [])

        guard let string = String(data: data, encoding: .utf8) else {
            print("Unable to convert JSON data to Data: \(json)")
            return String()
        }

        return string
    } catch {
        print("Failed to clean string: \(json)")
        return String()
    }
}

func assertJsonEqual(_ lhs: String, _ rhs: String) {
    XCTAssertEqual(clean(json: lhs), clean(json: rhs))
}

final class DocumentTests: XCTestCase {
    static var allTests: [(String, (DocumentTests) -> () throws -> Void)] {
        return [
            ("testDocument", testDocument),
            ("testEquatable", testEquatable),
            ("testRawBSON", testRawBSON),
            ("testBSONCorpus", testBSONCorpus)
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

        XCTAssertEqual(doc.count, 28)
        XCTAssertEqual(doc.keys, ["string", "true", "false", "int", "int32", "int64", "double", "decimal128",
                                "minkey", "maxkey", "date", "timestamp", "nestedarray", "nesteddoc", "oid",
                                "regex", "array1", "array2", "null", "code", "codewscope", "binary0", "binary1",
                                "binary2", "binary3", "binary4", "binary5", "binary6"])

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

    func testIterator() {
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
            "timestamp": Timestamp(timestamp: 5, inc: 10)
        ]

        for (_, _) in doc { }

    }

    func testEquatable() {
        XCTAssertEqual(
            ["hi": true, "hello": "hi", "cat": 2] as Document,
            ["hi": true, "hello": "hi", "cat": 2] as Document
        )
    }

    func testRawBSON() {
        let doc = try? Document(fromJSON: "{\"a\" : [{\"$numberInt\": \"10\"}]}")
        let rawBson = doc!.rawBSON
        let fromRawBson = Document(fromBSON: rawBson)
        XCTAssertEqual(doc, fromRawBson)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func testBSONCorpus() {
        let SKIPPED_CORPUS_TESTS = [
            /* CDRIVER-1879, can't make Code with embedded NIL */
            "Javascript Code": ["Embedded nulls"],
            "Javascript Code with Scope": ["Unicode and embedded null in code string, empty scope"],
            /* CDRIVER-2223, legacy extended JSON $date syntax uses numbers */
            "Top-level document validity": ["Bad $date (number, not string or hash)"],
            /* VS 2013 and older is imprecise stackoverflow.com/questions/32232331 */
            "Double type": ["1.23456789012345677E+18", "-1.23456789012345677E+18"]
        ]

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

                let testFileDescription = json["description"] as? String ?? "no description"
                guard let validCases = json["valid"] as? [Any] else {
                    continue // there are no valid cases defined in this file
                }

                for valid in validCases {
                    guard let validCase = valid as? [String: Any] else {
                        XCTFail("Unable to interpret valid case as dictionary")
                        return
                    }

                    let description = validCase["description"] as? String ?? "no description"
                    if let skippedTests = SKIPPED_CORPUS_TESTS[testFileDescription] {
                        if skippedTests.contains(description) {
                            continue
                        }
                    }

                    let cB = validCase["canonical_bson"] as? String ?? ""
                    guard let cBData = Data(hexString: cB) else {
                        XCTFail("Unable to interpret canonical_bson as Data")
                        return
                    }

                    let cEJ = validCase["canonical_extjson"] as? String ?? ""
                    guard let cEJData = cEJ.data(using: .utf8) else {
                        XCTFail("Unable to interpret canonical_extjson as Data")
                        return
                    }

                    let lossy = validCase["lossy"] as? Bool ?? false

                    // for cB input:
                    // native_to_bson( bson_to_native(cB) ) = cB
                    XCTAssertEqual(Document(fromBSON: cBData).rawBSON, cBData)

                    // native_to_canonical_extended_json( bson_to_native(cB) ) = cEJ
                    assertJsonEqual(Document(fromBSON: cBData).canonicalExtendedJSON, cEJ)

                    // native_to_relaxed_extended_json( bson_to_native(cB) ) = rEJ (if rEJ exists)
                    if let rEJ = validCase["relaxed_extjson"] as? String {
                        assertJsonEqual(Document(fromBSON: cBData).extendedJSON, rEJ)
                    }

                    // for cEJ input:
                    // native_to_canonical_extended_json( json_to_native(cEJ) ) = cEJ
                    assertJsonEqual(try Document(fromJSON: cEJData).canonicalExtendedJSON, cEJ)

                    // native_to_canonical_extended_json( json_to_native(cEJ) ) = cEJ
                    if !lossy {
                        XCTAssertEqual(try Document(fromJSON: cEJData).rawBSON, cBData)
                    }

                    // for dB input (if it exists):
                    if let dB = validCase["degenerate_bson"] as? String {
                        guard let dBData = Data(hexString: dB) else {
                            XCTFail("Unable to interpret degenerate_bson as Data")
                            return
                        }

                        // bson_to_canonical_extended_json(dB) = cEJ
                        assertJsonEqual(Document(fromBSON: dBData).canonicalExtendedJSON, cEJ)

                        // bson_to_relaxed_extended_json(dB) = rEJ (if rEJ exists)
                        if let rEJ = validCase["relaxed_extjson"] as? String {
                            assertJsonEqual(Document(fromBSON: dBData).extendedJSON, rEJ)
                        }
                    }

                    // for dEJ input (if it exists):
                    if let dEJ = validCase["degenerate_extjson"] as? String {
                        // native_to_canonical_extended_json( json_to_native(dEJ) ) = cEJ
                        assertJsonEqual(try Document(fromJSON: dEJ).canonicalExtendedJSON, cEJ)

                        // native_to_bson( json_to_native(dEJ) ) = cB (unless lossy)
                        if !lossy {
                            XCTAssertEqual(try Document(fromJSON: dEJ).rawBSON, cBData)
                        }
                    }

                    // for rEJ input (if it exists):
                    if let rEJ = validCase["relaxed_extjson"] as? String {
                        // native_to_relaxed_extended_json( json_to_native(rEJ) ) = rEJ
                        assertJsonEqual(try Document(fromJSON: rEJ).extendedJSON, rEJ)
                    }
                }
            }
        } catch {
            XCTFail("Test setup failed: \(error)")
        }
    }
}
