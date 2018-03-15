@testable import MongoSwift
import Quick
import Nimble
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
func clean(json: String?) -> String {

    guard let str = json else { return "" }
    do {
        let object = try JSONSerialization.jsonObject(with: str.data(using: .utf8)!, options: [])
        let data = try JSONSerialization.data(withJSONObject: object, options: [])

        guard let string = String(data: data, encoding: .utf8) else {
            print("Unable to convert JSON data to Data: \(str)")
            return String()
        }

        return string
    } catch {
        print("Failed to clean string: \(str)")
        return String()
    }
}

// Adds a custom "cleanEqual" predicate that compares two JSON strings for equality after normalizing
// them with the "clean" function
public func cleanEqual(_ expectedValue: String?) -> Predicate<String> {
    return Predicate.define("cleanEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()
        let matches = clean(json: actualValue) == clean(json: expectedValue) && expectedValue != nil
        if expectedValue == nil || actualValue == nil {
            if expectedValue == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

class DocumentTests: QuickSpec {

    override func setUp() {
        continueAfterFailure = false
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func spec() {

        it("Should correctly store all BSON types") {
            // A Data object to pass into test BSON Binary objects
            let data = Data(base64Encoded: "//8=")
            expect(data).toNot(beNil())
            let testData = data!

            let opts = NSRegularExpression.optionsFromString("imx")
            let regex = try? NSRegularExpression(pattern: "^abc", options: opts)
            expect(regex).toNot(beNil())

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

            expect(doc["string"] as? String).to(equal("test string"))
            expect(doc["true"] as? Bool).to(beTrue())
            expect(doc["false"] as? Bool).to(beFalse())
            expect(doc["int"] as? Int).to(equal(25))
            expect(doc["int32"] as? Int).to(equal(5))
            expect(doc["int64"] as? Int64).to(equal(10))
            expect(doc["double"] as? Double).to(equal(15))
            expect(doc["decimal128"] as? Decimal128).to(equal(Decimal128("1.2E+10")))
            expect(doc["minkey"] as? MinKey).to(beAnInstanceOf(MinKey.self))
            expect(doc["maxkey"] as? MaxKey).to(beAnInstanceOf(MaxKey.self))
            expect(doc["date"] as? Date).to(equal(Date(timeIntervalSince1970: 5000)))
            expect(doc["timestamp"] as? Timestamp).to(equal(Timestamp(timestamp: 5, inc: 10)))
            expect(doc["oid"] as? ObjectId).to(equal(ObjectId(from: "507f1f77bcf86cd799439011")))

            let regexReturned = doc["regex"] as? NSRegularExpression
            expect(regexReturned?.pattern).to(equal("^abc"))
            expect(regexReturned?.stringOptions).to(equal("imx"))

            expect(doc["array1"] as? [Int]).to(equal([1, 2]))
            expect(doc["array2"] as? [String]).to(equal(["string1", "string2"]))
            expect(doc["null"]).to(beNil())

            let code = doc["code"] as? CodeWithScope
            expect(code?.code).to(equal("console.log('hi');"))
            expect(code?.scope).to(beNil())

            let codewscope = doc["codewscope"] as? CodeWithScope
            expect(codewscope?.code).to(equal("console.log(x);"))
            expect(codewscope?.scope).to(equal(["x": 2]))

            expect(doc["binary0"] as? Binary).to(equal(Binary(data: testData, subtype: BsonSubtype.binary)))
            expect(doc["binary1"] as? Binary).to(equal(Binary(data: testData, subtype: BsonSubtype.function)))
            expect(doc["binary2"] as? Binary).to(equal(Binary(data: testData, subtype: BsonSubtype.binaryDeprecated)))
            expect(doc["binary3"] as? Binary).to(equal(Binary(data: testData, subtype: BsonSubtype.uuidDeprecated)))
            expect(doc["binary4"] as? Binary).to(equal(Binary(data: testData, subtype: BsonSubtype.uuid)))
            expect(doc["binary5"] as? Binary).to(equal(Binary(data: testData, subtype: BsonSubtype.md5)))
            expect(doc["binary6"] as? Binary).to(equal(Binary(data: testData, subtype: BsonSubtype.user)))

            let nestedArray = doc["nestedarray"] as? [[Int]]
            expect(nestedArray?[0]).to(equal([1, 2]))
            expect(nestedArray?[1]).to(equal([3, 4]))

            expect(doc["nesteddoc"] as? Document).to(equal(["a": 1, "b": 2, "c": false, "d": [3, 4]]))
        }

        it("Should correctly equate documents") {
            expect(["hi": true, "hello": "hi", "cat": 2] as Document)
            .to(equal(["hi": true, "hello": "hi", "cat": 2] as Document))
        }

        it("Should successfully iterate through a document") {
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

        it("Should correctly create a document from raw BSON") {
            let doc = try? Document(fromJSON: "{\"a\" : [{\"$numberInt\": \"10\"}]}")
            let rawBson = doc!.rawBSON
            let fromRawBson = Document(fromBSON: rawBson)
            expect(doc).to(equal(fromRawBson))
        }

        it("BSON Corpus Tests") {
            let SKIPPED_CORPUS_TESTS = [
                /* CDRIVER-1879, can't make Code with embedded NIL */
                "Javascript Code": ["Embedded nulls"],
                "Javascript Code with Scope": ["Unicode and embedded null in code string, empty scope"],
                /* CDRIVER-2223, legacy extended JSON $date syntax uses numbers */
                "Top-level document validity": ["Bad $date (number, not string or hash)"],
                /* VS 2013 and older is imprecise stackoverflow.com/questions/32232331 */
                "Double type": ["1.23456789012345677E+18", "-1.23456789012345677E+18"]
            ]

            var testFiles = try? FileManager.default.contentsOfDirectory(atPath: "Tests/Specs/bson-corpus/tests")
            expect(testFiles).toNot(beNil())
            testFiles = testFiles!.filter { $0.hasSuffix(".json") }

            for fileName in testFiles! {
                let testFilePath = URL(fileURLWithPath: "Tests/Specs/bson-corpus/tests/\(fileName)")
                let testFileData = try? String(contentsOf: testFilePath, encoding: .utf8)
                expect(testFileData).toNot(beNil())
                let testFileJson = try? JSONSerialization.jsonObject(with: testFileData!.data(using: .utf8)!, options: [])
                guard let json = testFileJson as? [String: Any] else {
                    XCTFail("Unable to convert json to dictionary")
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
                    expect(Document(fromBSON: cBData).rawBSON).to(equal(cBData))

                    // native_to_canonical_extended_json( bson_to_native(cB) ) = cEJ
                    expect(Document(fromBSON: cBData).canonicalExtendedJSON).to(cleanEqual(cEJ))

                    // native_to_relaxed_extended_json( bson_to_native(cB) ) = rEJ (if rEJ exists)
                    if let rEJ = validCase["relaxed_extjson"] as? String {
                        expect(Document(fromBSON: cBData).extendedJSON).to(cleanEqual(rEJ))
                    }

                    // for cEJ input:
                    // native_to_canonical_extended_json( json_to_native(cEJ) ) = cEJ
                    expect { try Document(fromJSON: cEJData).canonicalExtendedJSON }.to(cleanEqual(cEJ))

                    // native_to_canonical_extended_json( json_to_native(cEJ) ) = cEJ
                    if !lossy {
                        expect { try Document(fromJSON: cEJData).rawBSON }.to(equal(cBData))
                    }

                    // for dB input (if it exists):
                    if let dB = validCase["degenerate_bson"] as? String {
                        guard let dBData = Data(hexString: dB) else {
                            XCTFail("Unable to interpret degenerate_bson as Data")
                            return
                        }

                        // bson_to_canonical_extended_json(dB) = cEJ
                        expect(Document(fromBSON: dBData).canonicalExtendedJSON).to(cleanEqual(cEJ))

                        // bson_to_relaxed_extended_json(dB) = rEJ (if rEJ exists)
                        if let rEJ = validCase["relaxed_extjson"] as? String {
                            expect(Document(fromBSON: dBData).extendedJSON).to(cleanEqual(rEJ))
                        }
                    }

                    // for dEJ input (if it exists):
                    if let dEJ = validCase["degenerate_extjson"] as? String {
                        // native_to_canonical_extended_json( json_to_native(dEJ) ) = cEJ
                        expect { try Document(fromJSON: dEJ).canonicalExtendedJSON }.to(cleanEqual(cEJ))

                        // native_to_bson( json_to_native(dEJ) ) = cB (unless lossy)
                        if !lossy {
                            expect { try Document(fromJSON: dEJ).rawBSON }.to(equal(cBData))
                        }
                    }

                    // for rEJ input (if it exists):
                    if let rEJ = validCase["relaxed_extjson"] as? String {
                        // native_to_relaxed_extended_json( json_to_native(rEJ) ) = rEJ
                        expect { try Document(fromJSON: rEJ).extendedJSON }.to(cleanEqual(rEJ))
                    }
                }
            }
        }
    }
}
