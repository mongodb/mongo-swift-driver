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
        return reduce("") { $0 + String(format: "%02x", $1) }
    }
}

final class DocumentTests: MongoSwiftTestCase {
    // Set up test document values
    static let testDoc: Document = [
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
        "date": Date(timeIntervalSince1970: 500.004),
        "timestamp": Timestamp(timestamp: 5, inc: 10),
        "nestedarray": [[1, 2], [Int32(3), Int32(4)]] as [[Int32]],
        "nesteddoc": ["a": 1, "b": 2, "c": false, "d": [3, 4]] as Document,
        "oid": ObjectId(fromString: "507f1f77bcf86cd799439011"),
        "regex": RegularExpression(pattern: "^abc", options: "imx"),
        "array1": [1, 2],
        "array2": ["string1", "string2"],
        "null": BSONNull(),
        "code": CodeWithScope(code: "console.log('hi');"),
        "codewscope": CodeWithScope(code: "console.log(x);", scope: ["x": 2])
    ]

    func testDocument() throws {
        var doc = DocumentTests.testDoc // make a copy to mutate in this test

        // A Data object to pass into test BSON Binary objects
        guard let testData = Data(base64Encoded: "//8=") else {
            XCTFail("Failed to create test binary data")
            return
        }

        guard let uuidData = Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==") else {
            XCTFail("Failed to create test UUID data")
            return
        }

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
        expect(try Binary(data: testData, subtype: .uuidDeprecated))
                .to(throwError(UserError.invalidArgumentError(message: "")))
        expect(try Binary(data: testData, subtype: .uuid))
                .to(throwError(UserError.invalidArgumentError(message: "")))

        let expectedKeys = [
            "string", "true", "false", "int", "int32", "int64", "double", "decimal128",
            "minkey", "maxkey", "date", "timestamp", "nestedarray", "nesteddoc", "oid",
            "regex", "array1", "array2", "null", "code", "codewscope", "binary0", "binary1",
            "binary2", "binary3", "binary4", "binary5", "binary6", "binary7"
        ]
        expect(doc.count).to(equal(expectedKeys.count))
        expect(doc.keys).to(equal(expectedKeys))

        expect(doc["string"]).to(bsonEqual("test string"))
        expect(doc["true"]).to(bsonEqual(true))
        expect(doc["false"]).to(bsonEqual(false))
        expect(doc["int"]).to(bsonEqual(25))
        expect(doc["int32"]).to(bsonEqual(5))
        expect(doc["int64"]).to(bsonEqual(Int64(10)))
        expect(doc["double"]).to(bsonEqual(15.0))
        expect(doc["decimal128"]).to(bsonEqual(Decimal128("1.2E+10")))
        expect(doc["minkey"]).to(bsonEqual(MinKey()))
        expect(doc["maxkey"]).to(bsonEqual(MaxKey()))
        expect(doc["date"]).to(bsonEqual(Date(timeIntervalSince1970: 500.004)))
        expect(doc["timestamp"]).to(bsonEqual(Timestamp(timestamp: 5, inc: 10)))
        expect(doc["oid"]).to(bsonEqual(ObjectId(fromString: "507f1f77bcf86cd799439011")))

        let regex = doc["regex"] as? RegularExpression
        expect(regex).to(equal(RegularExpression(pattern: "^abc", options: "imx")))
        expect(try NSRegularExpression(from: regex!)).to(equal(try NSRegularExpression(
            pattern: "^abc",
            options: NSRegularExpression.optionsFromString("imx")
        )))

        expect(doc["array1"]).to(bsonEqual([1, 2]))
        expect(doc["array2"]).to(bsonEqual(["string1", "string2"]))
        expect(doc["null"]).to(bsonEqual(BSONNull()))

        let code = doc["code"] as? CodeWithScope
        expect(code?.code).to(equal("console.log('hi');"))
        expect(code?.scope).to(beNil())

        let codewscope = doc["codewscope"] as? CodeWithScope
        expect(codewscope?.code).to(equal("console.log(x);"))
        expect(codewscope?.scope).to(equal(["x": 2]))

        expect(doc["binary0"]).to(bsonEqual(try Binary(data: testData, subtype: .generic)))
        expect(doc["binary1"]).to(bsonEqual(try Binary(data: testData, subtype: .function)))
        expect(doc["binary2"]).to(bsonEqual(try Binary(data: testData, subtype: .binaryDeprecated)))
        expect(doc["binary3"]).to(bsonEqual(try Binary(data: uuidData, subtype: .uuidDeprecated)))
        expect(doc["binary4"]).to(bsonEqual(try Binary(data: uuidData, subtype: .uuid)))
        expect(doc["binary5"]).to(bsonEqual(try Binary(data: testData, subtype: .md5)))
        expect(doc["binary6"]).to(bsonEqual(try Binary(data: testData, subtype: .userDefined)))
        expect(doc["binary7"]).to(bsonEqual(try Binary(data: testData, subtype: 200)))

        let nestedArray = doc["nestedarray"] as? [[Int]]
        expect(nestedArray?[0]).to(equal([1, 2]))
        expect(nestedArray?[1]).to(equal([3, 4]))

        expect(doc["nesteddoc"]).to(bsonEqual(["a": 1, "b": 2, "c": false, "d": [3, 4]] as Document))
    }

    func testDocumentDynamicMemberLookup() throws {
#if swift(>=4.2)
        // Test reading various types
        expect(DocumentTests.testDoc.string).to(bsonEqual("test string"))
        expect(DocumentTests.testDoc.true).to(bsonEqual(true))
        expect(DocumentTests.testDoc.false).to(bsonEqual(false))
        expect(DocumentTests.testDoc.int).to(bsonEqual(25))
        expect(DocumentTests.testDoc.int32).to(bsonEqual(5))
        expect(DocumentTests.testDoc.int64).to(bsonEqual(Int64(10)))
        expect(DocumentTests.testDoc.double).to(bsonEqual(15.0))
        expect(DocumentTests.testDoc.decimal128).to(bsonEqual(Decimal128("1.2E+10")))
        expect(DocumentTests.testDoc.minkey).to(bsonEqual(MinKey()))
        expect(DocumentTests.testDoc.maxkey).to(bsonEqual(MaxKey()))
        expect(DocumentTests.testDoc.date).to(bsonEqual(Date(timeIntervalSince1970: 500.004)))
        expect(DocumentTests.testDoc.timestamp).to(bsonEqual(Timestamp(timestamp: 5, inc: 10)))
        expect(DocumentTests.testDoc.oid).to(bsonEqual(ObjectId(fromString: "507f1f77bcf86cd799439011")))

        let codewscope = DocumentTests.testDoc.codewscope as? CodeWithScope
        expect(codewscope?.code).to(equal("console.log(x);"))
        expect(codewscope?.scope).to(equal(["x": 2]))

        let code = DocumentTests.testDoc.code as? CodeWithScope
        expect(code?.code).to(equal("console.log('hi');"))
        expect(code?.scope).to(beNil())

        expect(DocumentTests.testDoc.array1).to(bsonEqual([1, 2]))
        expect(DocumentTests.testDoc.array2).to(bsonEqual(["string1", "string2"]))
        expect(DocumentTests.testDoc.null).to(bsonEqual(BSONNull()))

        let regex = DocumentTests.testDoc.regex as? RegularExpression
        expect(regex).to(equal(RegularExpression(pattern: "^abc", options: "imx")))
        expect(try NSRegularExpression(from: regex!)).to(equal(try NSRegularExpression(
                pattern: "^abc",
                options: NSRegularExpression.optionsFromString("imx")
        )))

        let nestedArray = DocumentTests.testDoc.nestedarray as? [[Int]]
        expect(nestedArray?[0]).to(equal([1, 2]))
        expect(nestedArray?[1]).to(equal([3, 4]))

        expect(DocumentTests.testDoc.nesteddoc).to(bsonEqual(["a": 1, "b": 2, "c": false, "d": [3, 4]] as Document))
        expect((DocumentTests.testDoc.nesteddoc as? Document)?.a).to(bsonEqual(1))

        // Test assignment
        var doc = Document()
        let subdoc: Document = ["d": 2.5]

        doc.a = 1
        doc.b = "b"
        doc.c = subdoc

        expect(doc.a).to(bsonEqual(1))
        expect(doc.b).to(bsonEqual("b"))
        expect(doc.c).to(bsonEqual(subdoc))

        doc.a = 2
        doc.b = "different"

        expect(doc.a).to(bsonEqual(2))
        expect(doc.b).to(bsonEqual("different"))
#endif
    }

    func testDocumentFromArray() {
       let doc1: Document = ["foo", MinKey(), BSONNull()]

       expect(doc1.keys).to(equal(["0", "1", "2"]))
       expect(doc1["0"]).to(bsonEqual("foo"))
       expect(doc1["1"]).to(bsonEqual(MinKey()))
       expect(doc1["2"]).to(bsonEqual(BSONNull()))

       let elements: [BSONValue] = ["foo", MinKey(), BSONNull()]
       let doc2 = Document(elements)

       expect(doc2.keys).to(equal(["0", "1", "2"]))
       expect(doc2["0"]).to(bsonEqual("foo"))
       expect(doc2["1"]).to(bsonEqual(MinKey()))
       expect(doc2["2"]).to(bsonEqual(BSONNull()))
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
        expect(doc2["b"]).to(bsonEqual(2))
        expect(doc1["b"]).to(beNil())
        expect(doc1).toNot(equal(doc2))
    }

    func testIntEncodesAsInt32OrInt64() {
        guard !MongoSwiftTestCase.is32Bit else {
            return
        }

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

        expect(doc["int32min"]).to(bsonEqual(Int(Int32.min)))
        expect(doc["int32max"]).to(bsonEqual(Int(Int32.max)))
        expect(doc["int32min-1"]).to(bsonEqual(int32min_sub1))
        expect(doc["int32max+1"]).to(bsonEqual(int32max_add1))
        expect(doc["int64min"]).to(bsonEqual(Int64.min))
        expect(doc["int64max"]).to(bsonEqual(Int64.max))
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

        let testFilesPath = MongoSwiftTestCase.specsPath + "/bson-corpus/tests"
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
        let arr1: [BSONValue] = ["a", "b", "c", BSONNull()]
        let arr2: [BSONValue] = ["d", "e", BSONNull(), "f"]

        let doc = ["a1": arr1, "a2": arr2]

        expect(doc["a1"]).to(bsonEqual(arr1))
        expect(doc["a2"]).to(bsonEqual(arr2))
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
        "nil": BSONNull(),
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
        expect(doc["int32"]).to(bsonEqual(15))
        expect(doc.data).to(equal(pointer))

        // overwrite int32 with an int that fits into int32s
        doc["int32"] = 20
        expect(doc["int32"]).to(bsonEqual(20))
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
        if MongoSwiftTestCase.is32Bit {
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

        let newPairs: [(String, BSONValue)] = [("string", "hi"), ("doc", newDoc), ("arr", [3, 4])]

        newPairs.forEach { k, v in
            doc[k] = v
            // the storage should change every time
            expect(doc.data).toNot(equal(pointer))
            pointer = doc.data
        }

        expect(doc).to(equal(["string": "hi", "nil": BSONNull(), "doc": newDoc, "arr": [3, 4] as [Int]]))
    }

    // test replacing both overwritable and nonoverwritable values with values of different types
    func testReplaceValueWithNewType() throws {
        // make a deep copy so we start off with uniquely referenced storage
        var overwritableDoc = Document(fromPointer: DocumentTests.overwritables.data)

        // save a reference to original bson_t so we can verify it changes
        var overwritablePointer = overwritableDoc.data

        let newOid = ObjectId()
        let overwritablePairs: [(String, BSONValue)] = [
            ("double", Int(10)),
            ("int32", "hi"),
            ("int64", Decimal128("1.0")),
            ("bool", [1, 2, 3]),
            ("decimal", 100),
            ("oid", 25.5),
            ("timestamp", newOid),
            ("datetime", Timestamp(timestamp: 1, inc: 2))
        ]

        overwritablePairs.forEach { k, v in
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

        let nonOverwritablePairs: [(String, BSONValue)] = [("string", 1), ("nil", "hello"), ("doc", "hi"), ("arr", 5)]

        nonOverwritablePairs.forEach { k, v in
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
            overwritableDoc[$0] = BSONNull()
            // the storage should change every time 
            expect(overwritableDoc.data).toNot(equal(overwritablePointer))
            overwritablePointer = overwritableDoc.data
        }

        var nonOverwritableDoc = Document(fromPointer: DocumentTests.nonOverwritables.data)
        var nonOverwritablePointer = nonOverwritableDoc.data

        ["string", "doc", "arr"].forEach {
            nonOverwritableDoc[$0] = BSONNull()
            // the storage should change every time 
            expect(nonOverwritableDoc.data).toNot(equal(nonOverwritablePointer))
            nonOverwritablePointer = nonOverwritableDoc.data
        }

        expect(nonOverwritableDoc).to(
                equal(["string": BSONNull(), "nil": BSONNull(), "doc": BSONNull(), "arr": BSONNull()]))
    }

    // Test types where replacing them with an instance of their own type is a no-op
    func testReplaceValueNoop() throws {
        var noops: Document = ["null": BSONNull(), "maxkey": MaxKey(), "minkey": MinKey()]

        var pointer = noops.data

        // replace values with own types. these should all be no-ops
        let newPairs1: [(String, BSONValue)] = [("null", BSONNull()), ("maxkey", MaxKey()), ("minkey", MinKey())]

        newPairs1.forEach { k, v in
            noops[k] = v
            // the storage should never change
            expect(noops.data).to(equal(pointer))
        }

        // we should still have exactly the same document we started with
        expect(noops).to(equal(["null": BSONNull(), "maxkey": MaxKey(), "minkey": MinKey()]))

        // now try replacing them with values of different types that do require replacing storage
        let newPairs2: [(String, BSONValue)] = [("null", 5), ("maxkey", "hi"), ("minkey", false)]

        newPairs2.forEach { k, v in
            noops[k] = v
            // the storage should change every time
            expect(noops.data).toNot(equal(pointer))
            pointer = noops.data
        }

        expect(noops).to(equal(["null": 5, "maxkey": "hi", "minkey": false]))
    }

    func testDocumentDictionarySimilarity() throws {
        var doc: Document = ["hello": "world", "swift": 4.2, "null": BSONNull(), "remove_me": "please"]
        var dict: [String: BSONValue] = ["hello": "world", "swift": 4.2, "null": BSONNull(), "remove_me": "please"]

        expect(doc["hello"]).to(bsonEqual(dict["hello"]))
        expect(doc["swift"]).to(bsonEqual(dict["swift"]))
        expect(doc["nonexistent key"]).to(beNil())
        expect(doc["null"]).to(bsonEqual(dict["null"]))

        doc["remove_me"] = nil

        expect(doc["remove_me"]).to(beNil())
        expect(doc.hasKey("remove_me")).to(beFalse())
    }

    func testDefaultSubscript() throws {
        let doc: Document = ["hello": "world"]
        let floatVal = 18.2
        let stringVal = "this is a string"
        expect(doc["DNE", default: floatVal]).to(bsonEqual(floatVal))
        expect(doc["hello", default: floatVal]).to(bsonEqual(doc["hello"]))
        expect(doc["DNE", default: stringVal]).to(bsonEqual(stringVal))
        expect(doc["DNE", default: BSONNull()]).to(bsonEqual(BSONNull()))
        expect(doc["autoclosure test", default: floatVal * floatVal]).to(bsonEqual(floatVal * floatVal))
        expect(doc["autoclosure test", default: "\(stringVal) and \(floatVal)" + stringVal])
            .to(bsonEqual("\(stringVal) and \(floatVal)" + stringVal))
    }

    struct UUIDWrapper: Codable {
        let uuid: UUID
    }

    func testUUIDEncodingStrategies() throws {
        let uuid = UUID(uuidString: "26cd7610-fd5a-4253-94b7-e8c4ea97b6cb")!

        let binary = try Binary(from: uuid)
        let uuidStruct = UUIDWrapper(uuid: uuid)
        let encoder = BSONEncoder()

        let defaultEncoding = try encoder.encode(uuidStruct)
        expect(defaultEncoding["uuid"] as? Binary).to(equal(binary))

        encoder.uuidEncodingStrategy = .binary
        let binaryEncoding = try encoder.encode(uuidStruct)
        expect(binaryEncoding["uuid"] as? Binary).to(equal(binary))

        encoder.uuidEncodingStrategy = .deferredToUUID
        let deferred = try encoder.encode(uuidStruct)
        expect(deferred["uuid"] as? String).to(equal(uuid.uuidString))
    }

    func testUUIDDecodingStrategies() throws {
        // randomly generated uuid
        let uuid = UUID(uuidString: "2c380a6c-7bc5-48cb-84a2-b26777a72276")!

        let decoder = BSONDecoder()

        // UUID default decoder expects a string
        decoder.uuidDecodingStrategy = .deferredToUUID
        let stringDoc: Document = ["uuid": uuid.description]
        let badString: Document = ["uuid": "hello"]
        let deferredStruct = try decoder.decode(UUIDWrapper.self, from: stringDoc)
        expect(deferredStruct.uuid).to(equal(uuid))
        expect(try decoder.decode(UUIDWrapper.self, from: badString)).to(throwError(CodecTests.dataCorruptedErr))

        decoder.uuidDecodingStrategy = .binary
        let uuidt = uuid.uuid
        let bytes = Data(bytes: [
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])
        let binaryDoc: Document = ["uuid": try Binary(data: bytes, subtype: .uuid)]
        let binaryStruct = try decoder.decode(UUIDWrapper.self, from: binaryDoc)
        expect(binaryStruct.uuid).to(equal(uuid))

        let badBinary: Document = ["uuid": try Binary(data: bytes, subtype: .generic)]
        expect(try decoder.decode(UUIDWrapper.self, from: badBinary)).to(throwError(CodecTests.dataCorruptedErr))

        expect(try decoder.decode(UUIDWrapper.self, from: stringDoc)).to(throwError(CodecTests.typeMismatchErr))
    }

    struct DateWrapper: Codable {
        let date: Date
    }

    func testDateEncodingStrategies() throws {
        let date = Date(timeIntervalSince1970: 123)
        let dateStruct = DateWrapper(date: date)

        let encoder = BSONEncoder()

        let defaultEncoding = try encoder.encode(dateStruct)
        expect(defaultEncoding["date"] as? Date).to(equal(date))

        encoder.dateEncodingStrategy = .bsonDateTime
        let bsonDate = try encoder.encode(dateStruct)
        expect(bsonDate["date"] as? Date).to(equal(date))

        encoder.dateEncodingStrategy = .secondsSince1970
        let secondsSince1970 = try encoder.encode(dateStruct)
        expect(secondsSince1970["date"] as? TimeInterval).to(equal(date.timeIntervalSince1970))

        encoder.dateEncodingStrategy = .millisecondsSince1970
        let millisecondsSince1970 = try encoder.encode(dateStruct)
        expect(millisecondsSince1970["date"] as? Int64).to(equal(date.msSinceEpoch))

        if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            encoder.dateEncodingStrategy = .iso8601
            let iso = try encoder.encode(dateStruct)
            expect(iso["date"] as? String).to(equal(BSONDecoder.iso8601Formatter.string(from: date)))
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .full
        formatter.dateStyle = .short

        encoder.dateEncodingStrategy = .formatted(formatter)
        let formatted = try encoder.encode(dateStruct)
        expect(formatted["date"] as? String).to(equal(formatter.string(from: date)))

        encoder.dateEncodingStrategy = .deferredToDate
        let deferred = try encoder.encode(dateStruct)
        expect(deferred["date"] as? TimeInterval).to(equal(date.timeIntervalSinceReferenceDate))

        encoder.dateEncodingStrategy = .custom({ d, e in
            var container = e.singleValueContainer()
            try container.encode(Int64(d.timeIntervalSince1970 + 12))
        })
        let custom = try encoder.encode(dateStruct)
        expect(custom["date"] as? Int64).to(equal(Int64(date.timeIntervalSince1970 + 12)))

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let noSecondsDate = DateWrapper(date: dateFormatter.date(from: "1/2/19")!)
        encoder.dateEncodingStrategy = .custom({d, e in
            var container = e.unkeyedContainer()
            try dateFormatter.string(from: d).split(separator: "/").forEach { component in
                try container.encode(String(component))
            }
        })
        let customArr = try encoder.encode(noSecondsDate)
        expect(dateFormatter.date(from: (customArr["date"] as! [String]).joined(separator: "/")))
                .to(equal(noSecondsDate.date))

        enum DateKeys: String, CodingKey {
            case month, day, year
        }

        encoder.dateEncodingStrategy = .custom({d, e in
            var container = e.container(keyedBy: DateKeys.self)
            let components = dateFormatter.string(from: d).split(separator: "/").map { String($0) }
            try container.encode(components[0], forKey: .month)
            try container.encode(components[1], forKey: .day)
            try container.encode(components[2], forKey: .year)
        })
        let customDoc = try encoder.encode(noSecondsDate)
        expect(customDoc["date"] as? Document).to(bsonEqual(["month": "1", "day": "2", "year": "19"] as Document))

        encoder.dateEncodingStrategy = .custom({ _, _ in })
        let customNoop = try encoder.encode(noSecondsDate)
        expect(customNoop["date"] as? Document).to(bsonEqual([:] as Document))
    }

    func testDateDecodingStrategies() throws {
        let decoder = BSONDecoder()

        let date = Date(timeIntervalSince1970: 125.0)

        // Default is .bsonDateTime
        let bsonDate: Document = ["date": date]
        let defaultStruct = try decoder.decode(DateWrapper.self, from: bsonDate)
        expect(defaultStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .bsonDateTime
        let bsonDateStruct = try decoder.decode(DateWrapper.self, from: bsonDate)
        expect(bsonDateStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .millisecondsSince1970
        let msInt64: Document = ["date": date.msSinceEpoch]
        let msInt64Struct = try decoder.decode(DateWrapper.self, from: msInt64)
        expect(msInt64Struct.date).to(equal(date))
        expect(try BSONDecoder().decode(DateWrapper.self, from: msInt64)).to(throwError(CodecTests.typeMismatchErr))

        let msDouble: Document = ["date": Double(date.msSinceEpoch)]
        let msDoubleStruct = try decoder.decode(DateWrapper.self, from: msDouble)
        expect(msDoubleStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .secondsSince1970
        let sDouble: Document = ["date": date.timeIntervalSince1970]
        let sDoubleStruct = try decoder.decode(DateWrapper.self, from: sDouble)
        expect(sDoubleStruct.date).to(equal(date))

        let sInt64: Document = ["date": Int64(date.timeIntervalSince1970)]
        let sInt64Struct = try decoder.decode(DateWrapper.self, from: sInt64)
        expect(sInt64Struct.date).to(equal(date))

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "en_US")

        decoder.dateDecodingStrategy = .formatted(formatter)
        let formatted: Document = ["date": formatter.string(from: date)]
        let badlyFormatted: Document = ["date": "this is not a date"]
        let formattedStruct = try decoder.decode(DateWrapper.self, from: formatted)
        expect(formattedStruct.date).to(equal(date))
        expect(try decoder.decode(DateWrapper.self, from: badlyFormatted)).to(throwError(CodecTests.dataCorruptedErr))
        expect(try decoder.decode(DateWrapper.self, from: sDouble)).to(throwError(CodecTests.typeMismatchErr))

        if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            decoder.dateDecodingStrategy = .iso8601
            let isoDoc: Document = ["date": BSONDecoder.iso8601Formatter.string(from: date)]
            let isoStruct = try decoder.decode(DateWrapper.self, from: isoDoc)
            expect(isoStruct.date).to(equal(date))
            expect(try decoder.decode(DateWrapper.self, from: formatted)).to(throwError(CodecTests.dataCorruptedErr))
            expect(try decoder.decode(DateWrapper.self, from: badlyFormatted))
                    .to(throwError(CodecTests.dataCorruptedErr))
        }

        decoder.dateDecodingStrategy = .custom({ decode in try Date(from: decode) })
        let customDoc: Document = ["date": date.timeIntervalSinceReferenceDate]
        let customStruct = try decoder.decode(DateWrapper.self, from: customDoc)
        expect(customStruct.date).to(equal(date))
        expect(try decoder.decode(DateWrapper.self, from: badlyFormatted)).to(throwError(CodecTests.typeMismatchErr))

        decoder.dateDecodingStrategy = .deferredToDate
        let deferredStruct = try decoder.decode(DateWrapper.self, from: customDoc)
        expect(deferredStruct.date).to(equal(date))
        expect(try decoder.decode(DateWrapper.self, from: badlyFormatted)).to(throwError(CodecTests.typeMismatchErr))
    }

    func testDataCodingStrategies() throws {
        struct DataWrapper: Codable {
            let data: Data
        }

        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        let data = Data(base64Encoded: "dGhlIHF1aWNrIGJyb3duIGZveCBqdW1wZWQgb3ZlciB0aGUgbGF6eSBzaGVlcCBkb2cu")!
        let binaryData = try Binary(data: data, subtype: .generic)
        let arrData = data.map { byte in Int(byte) }
        let dataStruct = DataWrapper(data: data)

        let defaultDoc = try encoder.encode(dataStruct)
        expect(defaultDoc["data"] as? Binary).to(equal(binaryData))
        let roundTripDefault = try decoder.decode(DataWrapper.self, from: defaultDoc)
        expect(roundTripDefault.data).to(equal(data))

        encoder.dataEncodingStrategy = .binary
        decoder.dataDecodingStrategy = .binary
        let binaryDoc = try encoder.encode(dataStruct)
        expect(binaryDoc["data"] as? Binary).to(bsonEqual(binaryData))
        let roundTripBinary = try decoder.decode(DataWrapper.self, from: binaryDoc)
        expect(roundTripBinary.data).to(equal(data))

        encoder.dataEncodingStrategy = .deferredToData
        decoder.dataDecodingStrategy = .deferredToData
        let deferredDoc = try encoder.encode(dataStruct)
        expect(deferredDoc["data"]).to(bsonEqual(arrData))
        let roundTripDeferred = try decoder.decode(DataWrapper.self, from: deferredDoc)
        expect(roundTripDeferred.data).to(equal(data))
        expect(try decoder.decode(DataWrapper.self, from: defaultDoc)).to(throwError(CodecTests.typeMismatchErr))

        encoder.dataEncodingStrategy = .base64
        decoder.dataDecodingStrategy = .base64
        let base64Doc = try encoder.encode(dataStruct)
        expect(base64Doc["data"]).to(bsonEqual(data.base64EncodedString()))
        let roundTripBase64 = try decoder.decode(DataWrapper.self, from: base64Doc)
        expect(roundTripBase64.data).to(equal(data))
        expect(try decoder.decode(DataWrapper.self, from: ["data": "this is not base64 encoded~"]))
                .to(throwError(CodecTests.dataCorruptedErr))

        let customEncodedDoc = ["d": data.base64EncodedString(), "hash": data.hashValue] as Document
        encoder.dataEncodingStrategy = .custom({ d, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(customEncodedDoc)
        })
        decoder.dataDecodingStrategy = .custom({ decoder in
            let doc = try Document(from: decoder)
            guard let d = Data(base64Encoded: doc["d"] as! String) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "bad base64"))
            }
            expect(d.hashValue).to(equal(data.hashValue))
            return d
        })
        let customDoc = try encoder.encode(dataStruct)
        expect(customDoc["data"]).to(bsonEqual(customEncodedDoc))
        let roundTripCustom = try decoder.decode(DataWrapper.self, from: customDoc)
        expect(roundTripCustom.data).to(equal(data))

        encoder.dataEncodingStrategy = .custom({ _, _ in })
        expect(try encoder.encode(dataStruct)).to(bsonEqual(["data": [:] as Document] as Document))
    }
}
