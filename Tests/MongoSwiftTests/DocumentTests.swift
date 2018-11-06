import Foundation
@testable import MongoSwift
import Nimble
import XCTest

/// Useful extensions to the Data type for testing purposes
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
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

final class DocumentTests: XCTestCase {
    static var allTests: [(String, (DocumentTests) -> () throws -> Void)] {
        return [
            ("testDocument", testDocument),
            ("testDocumentFromArray", testDocumentFromArray),
            ("testEquatable", testEquatable),
            ("testRawBSON", testRawBSON),
            ("testValueBehavior", testValueBehavior),
            ("testIntEncodesAsInt32OrInt64", testIntEncodesAsInt32OrInt64),
            ("testBSONCorpus", testBSONCorpus),
            ("testMerge", testMerge),
            ("testNilInNestedArray", testNilInNestedArray),
            ("testOverwritable", testOverwritable),
            ("testNonOverwritable", testNonOverwritable),
            ("testReplaceValueWithNewType", testReplaceValueWithNewType),
            ("testReplaceValueWithNil", testReplaceValueWithNil),
            ("testReplaceValueNoop", testReplaceValueNoop)
        ]
    }

    func testDocument() throws {
        // A Data object to pass into test BSON Binary objects
        guard let testData = Data(base64Encoded: "//8=") else {
            XCTFail("Failed to create test binary data")
            return
        }

        guard let uuidData = Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==") else {
            XCTFail("Failed to create test UUID data")
            return
        }

        // Set up test document values
        var doc: Document = [
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
            "oid": ObjectId(fromString: "507f1f77bcf86cd799439011"),
            "regex": RegularExpression(pattern: "^abc", options: "imx"),
            "array1": [1, 2],
            "array2": ["string1", "string2"],
            "null": nil,
            "code": CodeWithScope(code: "console.log('hi');"),
            "codewscope": CodeWithScope(code: "console.log(x);", scope: ["x": 2])
        ]

        // splitting this out is necessary because the swift 4.0 compiler 
        // can't handle all the keys being declared together

        let binaryData: Document = [
            "binary0": try Binary(data: testData, subtype: .generic),
            "binary1": try Binary(data: testData, subtype: .function),
            "binary2": try Binary(data: testData, subtype: .binaryDeprecated),
            "binary3": try Binary(data: uuidData, subtype: .uuidDeprecated),
            "binary4": try Binary(data: uuidData, subtype: .uuid),
            "binary5": try Binary(data: testData, subtype: .md5),
            "binary6": try Binary(data: testData, subtype: .userDefined),
            "binary7": try Binary(data: testData, subtype: 200)
        ]
        try doc.merge(binaryData)

        // UUIDs must have 16 bytes
        expect(try Binary(data: testData, subtype: .uuidDeprecated)).to(throwError())
        expect(try Binary(data: testData, subtype: .uuid)).to(throwError())

        let expectedKeys = ["string", "true", "false", "int", "int32", "int64", "double", "decimal128",
                                "minkey", "maxkey", "date", "timestamp", "nestedarray", "nesteddoc", "oid",
                                "regex", "array1", "array2", "null", "code", "codewscope", "binary0", "binary1",
                                "binary2", "binary3", "binary4", "binary5", "binary6", "binary7"]
        expect(doc.count).to(equal(expectedKeys.count))
        expect(doc.keys).to(equal(expectedKeys))

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
        expect(doc["oid"] as? ObjectId).to(equal(ObjectId(fromString: "507f1f77bcf86cd799439011")))

        let regex = doc["regex"] as? RegularExpression
        expect(regex).to(equal(RegularExpression(pattern: "^abc", options: "imx")))
        expect(regex?.nsRegularExpression).to(equal(try NSRegularExpression(pattern: "^abc", options: NSRegularExpression.optionsFromString("imx"))))

        expect(doc["array1"] as? [Int]).to(equal([1, 2]))
        expect(doc["array2"] as? [String]).to(equal(["string1", "string2"]))
        expect(doc["null"]).to(beNil())

        let code = doc["code"] as? CodeWithScope
        expect(code?.code).to(equal("console.log('hi');"))
        expect(code?.scope).to(beNil())

        let codewscope = doc["codewscope"] as? CodeWithScope
        expect(codewscope?.code).to(equal("console.log(x);"))
        expect(codewscope?.scope).to(equal(["x": 2]))

        expect(doc["binary0"] as? Binary).to(equal(try Binary(data: testData, subtype: .generic)))
        expect(doc["binary1"] as? Binary).to(equal(try Binary(data: testData, subtype: .function)))
        expect(doc["binary2"] as? Binary).to(equal(try Binary(data: testData, subtype: .binaryDeprecated)))
        expect(doc["binary3"] as? Binary).to(equal(try Binary(data: uuidData, subtype: .uuidDeprecated)))
        expect(doc["binary4"] as? Binary).to(equal(try Binary(data: uuidData, subtype: .uuid)))
        expect(doc["binary5"] as? Binary).to(equal(try Binary(data: testData, subtype: .md5)))
        expect(doc["binary6"] as? Binary).to(equal(try Binary(data: testData, subtype: .userDefined)))
        expect(doc["binary7"] as? Binary).to(equal(try Binary(data: testData, subtype: 200)))

        let nestedArray = doc["nestedarray"] as? [[Int]]
        expect(nestedArray?[0]).to(equal([1, 2]))
        expect(nestedArray?[1]).to(equal([3, 4]))

        expect(doc["nesteddoc"] as? Document).to(equal(["a": 1, "b": 2, "c": false, "d": [3, 4]]))
    }

    func testDocumentFromArray() {
       let doc1: Document = ["foo", MinKey(), nil]

       expect(doc1.keys).to(equal(["0", "1", "2"]))
       expect(doc1["0"] as? String).to(equal("foo"))
       expect(doc1["1"] as? MinKey).to(beAnInstanceOf(MinKey.self))
       expect(doc1["2"]).to(beNil())

       let elements: [BSONValue?] = ["foo", MinKey(), nil]
       let doc2 = Document(elements)

       expect(doc2.keys).to(equal(["0", "1", "2"]))
       expect(doc2["0"] as? String).to(equal("foo"))
       expect(doc2["1"] as? MinKey).to(beAnInstanceOf(MinKey.self))
       expect(doc2["2"]).to(beNil())
    }

    func testEquatable() {
        expect(["hi": true, "hello": "hi", "cat": 2] as Document)
        .to(equal(["hi": true, "hello": "hi", "cat": 2] as Document))
    }

    func testRawBSON() throws {
        let doc = try Document(fromJSON: "{\"a\" : [{\"$numberInt\": \"10\"}]}")
        let fromRawBSON = Document(fromBSON: doc.rawBSON)
        expect(doc).to(equal(fromRawBSON))
    }

    func testValueBehavior() {
        let doc1: Document = ["a": 1]
        var doc2 = doc1
        doc2["b"] = 2
        XCTAssertEqual(doc2["b"] as? Int, 2)
        XCTAssertNil(doc1["b"])
        XCTAssertNotEqual(doc1, doc2)
    }

    func testIntEncodesAsInt32OrInt64() {
        if XCTestCase.is32Bit { return }

        let int32min_sub1 = Int64(Int32.min) - Int64(1)
        let int32max_add1 = Int64(Int32.max) + Int64(1)

        var doc: Document = [
            "int32min": Int(Int32.min),
            "int32max": Int(Int32.max),
            "int32min-1": Int(int32min_sub1),
            "int32max+1": Int(int32max_add1),
            "int64min": Int(Int64.min),
            "int64max": Int(Int64.max)
        ]

        expect(doc["int32min"] as? Int).to(equal(Int(Int32.min)))
        expect(doc["int32max"] as? Int).to(equal(Int(Int32.max)))
        expect(doc["int32min-1"] as? Int64).to(equal(int32min_sub1))
        expect(doc["int32max+1"] as? Int64).to(equal(int32max_add1))
        expect(doc["int64min"] as? Int64).to(equal(Int64.min))
        expect(doc["int64max"] as? Int64).to(equal(Int64.max))
    }

    // swiftlint:disable:next cyclomatic_complexity
    func testBSONCorpus() throws {
        let SKIPPED_CORPUS_TESTS = [
            /* CDRIVER-1879, can't make Code with embedded NIL */
            "Javascript Code": ["Embedded nulls"],
            "Javascript Code with Scope": ["Unicode and embedded null in code string, empty scope"],
            /* CDRIVER-2223, legacy extended JSON $date syntax uses numbers */
            "Top-level document validity": ["Bad $date (number, not string or hash)"],
            /* VS 2013 and older is imprecise stackoverflow.com/questions/32232331 */
            "Double type": ["1.23456789012345677E+18", "-1.23456789012345677E+18"]
        ]

        let testFilesPath = XCTestCase.specsPath + "/bson-corpus/tests"
        var testFiles = try FileManager.default.contentsOfDirectory(atPath: testFilesPath)
        testFiles = testFiles.filter { $0.hasSuffix(".json") }

        for fileName in testFiles {
            let testFilePath = URL(fileURLWithPath: "\(testFilesPath)/\(fileName)")
            let testFileData = try String(contentsOf: testFilePath, encoding: .utf8)
            let testFileJson = try JSONSerialization.jsonObject(with: testFileData.data(using: .utf8)!, options: [])
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
                expect(try Document(fromJSON: cEJData).canonicalExtendedJSON).to(cleanEqual(cEJ))

                // native_to_canonical_extended_json( json_to_native(cEJ) ) = cEJ
                if !lossy {
                    expect(try Document(fromJSON: cEJData).rawBSON).to(equal(cBData))
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
                    expect(try Document(fromJSON: dEJ).canonicalExtendedJSON).to(cleanEqual(cEJ))

                    // native_to_bson( json_to_native(dEJ) ) = cB (unless lossy)
                    if !lossy {
                        expect(try Document(fromJSON: dEJ).rawBSON).to(equal(cBData))
                    }
                }

                // for rEJ input (if it exists):
                if let rEJ = validCase["relaxed_extjson"] as? String {
                    // native_to_relaxed_extended_json( json_to_native(rEJ) ) = rEJ
                    expect(try Document(fromJSON: rEJ).extendedJSON).to(cleanEqual(rEJ))
                }
            }
        }
    }

    func testMerge() throws {
        // test documents are merged correctly
        var doc1: Document = ["a": 1]
        try doc1.merge(["b": 2])
        expect(doc1).to(equal(["a": 1, "b": 2]))

        // ensure merging into a copy doesn't modify original
        var doc2 = doc1
        try doc2.merge(["c": 3])
        expect(doc1).to(equal(["a": 1, "b": 2]))
        expect(doc2).to(equal(["a": 1, "b": 2, "c": 3]))
    }

    func testNilInNestedArray() throws {
        let arr1 = ["a", "b", "c", nil]
        let arr2 = ["d", "e", nil, "f"]

        let doc = ["a1": arr1, "a2": arr2]

        expect(doc["a1"]).to(equal(arr1))
        expect(doc["a2"]).to(equal(arr2))
    }

    // exclude Int64 value on 32-bit platforms
    static let overwritables: Document = [
        "double": 2.5,
        "int32": Int32(32),
        "int64": Int64.max,
        "bool": false,
        "decimal": Decimal128("1.2E+10"),
        "oid": ObjectId(),
        "timestamp": Timestamp(timestamp: 1, inc: 2),
        "datetime": Date(msSinceEpoch: 1000)
    ]

    static let nonOverwritables: Document = [
        "string": "hello",
        "nil": nil,
        "doc": ["x": 1] as Document,
        "arr": [1, 2] as [Int]
    ]

    // test replacing `Overwritable` types with values of their own type
    func testOverwritable() throws {
        // make a deep copy so we start off with uniquely referenced storage
        var doc = Document(fromPointer: DocumentTests.overwritables.data)

        // save a reference to original bson_t so we can verify it doesn't change
        let pointer = doc.data

        // overwrite int32 with int32
        doc["int32"] = Int32(15)
        expect(doc["int32"] as? Int).to(equal(15))
        expect(doc.data).to(equal(pointer))

        // overwrite int32 with an int that fits into int32s
        doc["int32"] = 20
        expect(doc["int32"] as? Int).to(equal(20))
        expect(doc.data).to(equal(pointer))

        doc["bool"] = true
        expect(doc.data).to(equal(pointer))

        doc["double"] = 3.0
        expect(doc.data).to(equal(pointer))

        doc["decimal"] = Decimal128("100")
        expect(doc.data).to(equal(pointer))

        // overwrite int64 with int64
        doc["int64"] = Int64.min
        expect(doc.data).to(equal(pointer))

        let newOid = ObjectId()
        doc["oid"] = newOid
        expect(doc.data).to(equal(pointer))

        doc["timestamp"] = Timestamp(timestamp: 5, inc: 10)
        expect(doc.data).to(equal(pointer))

        doc["datetime"] = Date(msSinceEpoch: 2000)
        expect(doc.data).to(equal(pointer))

        expect(doc).to(equal([
            "double": 3.0,
            "int32": 20,
            "int64": Int64.min,
            "bool": true,
            "decimal": Decimal128("100"),
            "oid": newOid,
            "timestamp": Timestamp(timestamp: 5, inc: 10),
            "datetime": Date(msSinceEpoch: 2000)
        ]))

        // return early as we will to use an Int requiring > 32 bits after this 
        if XCTestCase.is32Bit {
            return
        }

        let bigInt = Int(Int32.max) + 1
        doc["int64"] = bigInt
        expect(doc.data).to(equal(pointer))

        // final values
        expect(doc).to(equal([
            "double": 3.0,
            "int32": 20,
            "int64": bigInt,
            "bool": true,
            "decimal": Decimal128("100"),
            "oid": newOid,
            "timestamp": Timestamp(timestamp: 5, inc: 10),
            "datetime": Date(msSinceEpoch: 2000)
        ]))
    }

    // test replacing some of the non-Overwritable types with values of their own types
    func testNonOverwritable() throws {
        // make a deep copy so we start off with uniquely referenced storage
        var doc = Document(fromPointer: DocumentTests.nonOverwritables.data)

        // save a reference to original bson_t so we can verify it changes
        var pointer = doc.data

        // save these to compare to at the end
        let newDoc: Document = ["y": 1]

        let newPairs: [(String, BSONValue?)] = [("string", "hi"), ("doc", newDoc), ("arr", [3, 4])]

        newPairs.forEach { (k, v) in
            doc[k] = v
            // the storage should change every time
            expect(doc.data).toNot(equal(pointer))
            pointer = doc.data
        }

        expect(doc).to(equal(["string": "hi", "nil": nil, "doc": newDoc, "arr": [3, 4] as [Int]]))
    }

    // test replacing both overwritable and nonoverwritable values with values of different types
    func testReplaceValueWithNewType() throws {
        // make a deep copy so we start off with uniquely referenced storage
        var overwritableDoc = Document(fromPointer: DocumentTests.overwritables.data)

        // save a reference to original bson_t so we can verify it changes
        var overwritablePointer = overwritableDoc.data

        let newOid = ObjectId()
        let overwritablePairs: [(String, BSONValue?)] = [
            ("double", Int(10)),
            ("int32", "hi"),
            ("int64", Decimal128("1.0")),
            ("bool", [1, 2, 3]),
            ("decimal", 100),
            ("oid", 25.5),
            ("timestamp", newOid),
            ("datetime", Timestamp(timestamp: 1, inc: 2))
        ]

        overwritablePairs.forEach { (k, v) in
            overwritableDoc[k] = v
            expect(overwritableDoc.data).toNot(equal(overwritablePointer))
            overwritablePointer = overwritableDoc.data
        }

        expect(overwritableDoc).to(equal([
            "double": 10,
            "int32": "hi",
            "int64": Decimal128("1.0"),
            "bool": [1, 2, 3] as [Int],
            "decimal": 100,
            "oid": 25.5,
            "timestamp": newOid,
            "datetime": Timestamp(timestamp: 1, inc: 2)
        ]))

        // make a deep copy so we start off with uniquely referenced storage
        var nonOverwritableDoc = Document(fromPointer: DocumentTests.nonOverwritables.data)

        // save a reference to original bson_t so we can verify it changes
        var nonOverwritablePointer = nonOverwritableDoc.data

        let nonOverwritablePairs: [(String, BSONValue?)] = [("string", 1), ("nil", "hello"), ("doc", "hi"), ("arr", 5)]

        nonOverwritablePairs.forEach { (k, v) in
            nonOverwritableDoc[k] = v
            expect(nonOverwritableDoc.data).toNot(equal(nonOverwritablePointer))
            nonOverwritablePointer = nonOverwritableDoc.data
        }

        expect(nonOverwritableDoc).to(equal(["string": 1, "nil": "hello", "doc": "hi", "arr": 5]))
    }

    // test setting both overwritable and nonoverwritable values to nil
    func testReplaceValueWithNil() throws {
        var overwritableDoc = Document(fromPointer: DocumentTests.overwritables.data)
        var overwritablePointer = overwritableDoc.data

        ["double", "int32", "int64", "bool", "decimal", "oid", "timestamp", "datetime"].forEach {
            overwritableDoc[$0] = nil
            // the storage should change every time 
            expect(overwritableDoc.data).toNot(equal(overwritablePointer))
            overwritablePointer = overwritableDoc.data
        }

        var nonOverwritableDoc = Document(fromPointer: DocumentTests.nonOverwritables.data)
        var nonOverwritablePointer = nonOverwritableDoc.data

        ["string", "doc", "arr"].forEach {
            nonOverwritableDoc[$0] = nil
            // the storage should change every time 
            expect(nonOverwritableDoc.data).toNot(equal(nonOverwritablePointer))
            nonOverwritablePointer = nonOverwritableDoc.data
        }

        expect(nonOverwritableDoc).to(equal(["string": nil, "nil": nil, "doc": nil, "arr": nil]))
    }

    // Test types where replacing them with an instance of their own type is a no-op
    func testReplaceValueNoop() throws {
        var noops: Document = ["null": nil, "maxkey": MaxKey(), "minkey": MinKey()]

        var pointer = noops.data

        // replace values with own types. these should all be no-ops
        let newPairs1: [(String, BSONValue?)] = [("null", nil), ("maxkey", MaxKey()), ("minkey", MinKey())]

        newPairs1.forEach { (k, v) in
            noops[k] = v
            // the storage should never change
            expect(noops.data).to(equal(pointer))
        }

        // we should still have exactly the same document we started with
        expect(noops).to(equal(["null": nil, "maxkey": MaxKey(), "minkey": MinKey()]))

        // now try replacing them with values of different types that do require replacing storage
        let newPairs2: [(String, BSONValue?)] = [("null", 5), ("maxkey", "hi"), ("minkey", false)]

        newPairs2.forEach { (k, v) in
            noops[k] = v
            // the storage should change every time
            expect(noops.data).toNot(equal(pointer))
            pointer = noops.data
        }

        expect(noops).to(equal(["null": 5, "maxkey": "hi", "minkey": false]))
    }
}
