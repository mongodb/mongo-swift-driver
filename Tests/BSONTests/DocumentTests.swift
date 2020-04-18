import CLibMongoC
import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
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
        reduce("") { $0 + String(format: "%02x", $1) }
    }
}

struct DocElem {
    let key: String
    let value: SwiftBSON
}

enum SwiftBSON {
    case document([DocElem])
    case other(BSON)
}

/// Extension of Document to allow conversion to and from arrays
extension Document {
    internal init(fromArray array: [DocElem]) {
        self.init()

        for elem in array {
            switch elem.value {
            case let .document(els):
                self[elem.key] = .document(Document(fromArray: els))
            case let .other(b):
                self[elem.key] = b
            }
        }
    }

    internal func toArray() -> [DocElem] {
        self.map { kvp in
            if let subdoc = kvp.value.documentValue {
                return DocElem(key: kvp.key, value: .document(subdoc.toArray()))
            }
            return DocElem(key: kvp.key, value: .other(kvp.value))
        }
    }

    /// Gets a string representation of the address of this document's underlying pointer.
    internal var pointerAddress: String {
        self.withBSONPointer { ptr in
            ptr.debugDescription
        }
    }
}

final class DocumentTests: MongoSwiftTestCase {
    // Set up test document values
    static let testDoc: Document = [
        "string": "test string",
        "true": true,
        "false": false,
        "int": 25,
        "int32": .int32(5),
        "int64": .int64(10),
        "double": .double(15),
        "decimal128": .decimal128(Decimal128("1.2E+10")!),
        "minkey": .minKey,
        "maxkey": .maxKey,
        "date": .datetime(Date(timeIntervalSince1970: 500.004)),
        "timestamp": .timestamp(Timestamp(timestamp: 5, inc: 10)),
        "nestedarray": [[1, 2], [.int32(3), .int32(4)]],
        "nesteddoc": ["a": 1, "b": 2, "c": false, "d": [3, 4]],
        "oid": .objectId(ObjectId("507f1f77bcf86cd799439011")!),
        "regex": .regex(RegularExpression(pattern: "^abc", options: "imx")),
        "array1": [1, 2],
        "array2": ["string1", "string2"],
        "null": .null,
        "code": .code(Code(code: "console.log('hi');")),
        "codewscope": .codeWithScope(CodeWithScope(code: "console.log(x);", scope: ["x": 2]))
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
            "binary0": .binary(try Binary(data: testData, subtype: .generic)),
            "binary1": .binary(try Binary(data: testData, subtype: .function)),
            "binary2": .binary(try Binary(data: testData, subtype: .binaryDeprecated)),
            "binary3": .binary(try Binary(data: uuidData, subtype: .uuidDeprecated)),
            "binary4": .binary(try Binary(data: uuidData, subtype: .uuid)),
            "binary5": .binary(try Binary(data: testData, subtype: .md5)),
            "binary6": .binary(try Binary(data: testData, subtype: .userDefined)),
            "binary7": .binary(try Binary(data: testData, subtype: 200))
        ]
        try doc.merge(binaryData)

        // UUIDs must have 16 bytes
        expect(try Binary(data: testData, subtype: .uuidDeprecated))
            .to(throwError(errorType: InvalidArgumentError.self))
        expect(try Binary(data: testData, subtype: .uuid))
            .to(throwError(errorType: InvalidArgumentError.self))

        let expectedKeys = [
            "string", "true", "false", "int", "int32", "int64", "double", "decimal128",
            "minkey", "maxkey", "date", "timestamp", "nestedarray", "nesteddoc", "oid",
            "regex", "array1", "array2", "null", "code", "codewscope", "binary0", "binary1",
            "binary2", "binary3", "binary4", "binary5", "binary6", "binary7"
        ]
        expect(doc.count).to(equal(expectedKeys.count))
        expect(doc.keys).to(equal(expectedKeys))

        expect(doc["string"]).to(equal("test string"))
        expect(doc["true"]).to(equal(true))
        expect(doc["false"]).to(equal(false))
        expect(doc["int"]).to(equal(25))
        expect(doc["int32"]).to(equal(.int32(5)))
        expect(doc["int64"]).to(equal(.int64(10)))
        expect(doc["double"]).to(equal(15.0))
        expect(doc["decimal128"]).to(equal(.decimal128(Decimal128("1.2E+10")!)))
        expect(doc["minkey"]).to(equal(.minKey))
        expect(doc["maxkey"]).to(equal(.maxKey))
        expect(doc["date"]).to(equal(.datetime(Date(timeIntervalSince1970: 500.004))))
        expect(doc["timestamp"]).to(equal(.timestamp(Timestamp(timestamp: 5, inc: 10))))
        expect(doc["oid"]).to(equal(.objectId(ObjectId("507f1f77bcf86cd799439011")!)))

        let regex = doc["regex"]?.regexValue
        expect(regex).to(equal(RegularExpression(pattern: "^abc", options: "imx")))
        expect(try NSRegularExpression(from: regex!)).to(equal(try NSRegularExpression(
            pattern: "^abc",
            options: NSRegularExpression.optionsFromString("imx")
        )))

        expect(doc["array1"]).to(equal([1, 2]))
        expect(doc["array2"]).to(equal(["string1", "string2"]))
        expect(doc["null"]).to(equal(.null))

        let code = doc["code"]?.codeValue
        expect(code?.code).to(equal("console.log('hi');"))

        let codewscope = doc["codewscope"]?.codeWithScopeValue
        expect(codewscope?.code).to(equal("console.log(x);"))
        expect(codewscope?.scope).to(equal(["x": 2]))

        expect(doc["binary0"]).to(equal(.binary(try Binary(data: testData, subtype: .generic))))
        expect(doc["binary1"]).to(equal(.binary(try Binary(data: testData, subtype: .function))))
        expect(doc["binary2"]).to(equal(.binary(try Binary(data: testData, subtype: .binaryDeprecated))))
        expect(doc["binary3"]).to(equal(.binary(try Binary(data: uuidData, subtype: .uuidDeprecated))))
        expect(doc["binary4"]).to(equal(.binary(try Binary(data: uuidData, subtype: .uuid))))
        expect(doc["binary5"]).to(equal(.binary(try Binary(data: testData, subtype: .md5))))
        expect(doc["binary6"]).to(equal(.binary(try Binary(data: testData, subtype: .userDefined))))
        expect(doc["binary7"]).to(equal(.binary(try Binary(data: testData, subtype: 200))))

        let nestedArray = doc["nestedarray"]?.arrayValue?.compactMap { $0.arrayValue?.compactMap { $0.asInt() } }
        expect(nestedArray?[0]).to(equal([1, 2]))
        expect(nestedArray?[1]).to(equal([3, 4]))

        expect(doc["nesteddoc"]).to(equal(["a": 1, "b": 2, "c": false, "d": [3, 4]]))
    }

    func testDocumentDynamicMemberLookup() throws {
        // Test reading various types
        expect(DocumentTests.testDoc.string).to(equal("test string"))
        expect(DocumentTests.testDoc.true).to(equal(true))
        expect(DocumentTests.testDoc.false).to(equal(false))
        expect(DocumentTests.testDoc.int).to(equal(25))
        expect(DocumentTests.testDoc.int32).to(equal(.int32(5)))
        expect(DocumentTests.testDoc.int64).to(equal(.int64(10)))
        expect(DocumentTests.testDoc.double).to(equal(15.0))
        expect(DocumentTests.testDoc.decimal128).to(equal(.decimal128(Decimal128("1.2E+10")!)))
        expect(DocumentTests.testDoc.minkey).to(equal(.minKey))
        expect(DocumentTests.testDoc.maxkey).to(equal(.maxKey))
        expect(DocumentTests.testDoc.date).to(equal(.datetime(Date(timeIntervalSince1970: 500.004))))
        expect(DocumentTests.testDoc.timestamp).to(equal(.timestamp(Timestamp(timestamp: 5, inc: 10))))
        expect(DocumentTests.testDoc.oid).to(equal(.objectId(ObjectId("507f1f77bcf86cd799439011")!)))

        let codewscope = DocumentTests.testDoc.codewscope?.codeWithScopeValue
        expect(codewscope?.code).to(equal("console.log(x);"))
        expect(codewscope?.scope).to(equal(["x": 2]))

        let code = DocumentTests.testDoc.code?.codeValue
        expect(code?.code).to(equal("console.log('hi');"))

        expect(DocumentTests.testDoc.array1).to(equal([1, 2]))
        expect(DocumentTests.testDoc.array2).to(equal(["string1", "string2"]))
        expect(DocumentTests.testDoc.null).to(equal(.null))

        let regex = DocumentTests.testDoc.regex?.regexValue
        expect(regex).to(equal(RegularExpression(pattern: "^abc", options: "imx")))
        expect(try NSRegularExpression(from: regex!)).to(equal(try NSRegularExpression(
            pattern: "^abc",
            options: NSRegularExpression.optionsFromString("imx")
        )))

        let nestedArray = DocumentTests.testDoc.nestedarray?.arrayValue?.compactMap {
            $0.arrayValue?.compactMap { $0.asInt() }
        }
        expect(nestedArray?[0]).to(equal([1, 2]))
        expect(nestedArray?[1]).to(equal([3, 4]))

        expect(DocumentTests.testDoc.nesteddoc).to(equal(["a": 1, "b": 2, "c": false, "d": [3, 4]]))
        expect(DocumentTests.testDoc.nesteddoc?.documentValue?.a).to(equal(1))

        // Test assignment
        var doc = Document()
        let subdoc: Document = ["d": 2.5]

        doc.a = 1
        doc.b = "b"
        doc.c = .document(subdoc)

        expect(doc.a).to(equal(1))
        expect(doc.b).to(equal("b"))
        expect(doc.c).to(equal(.document(subdoc)))

        doc.a = 2
        doc.b = "different"

        expect(doc.a).to(equal(2))
        expect(doc.b).to(equal("different"))
    }

    func testEquatable() {
        expect(["hi": true, "hello": "hi", "cat": 2] as Document)
            .to(equal(["hi": true, "hello": "hi", "cat": 2] as Document))
    }

    func testRawBSON() throws {
        let doc = try Document(fromJSON: "{\"a\" : [{\"$numberInt\": \"10\"}]}")
        let fromRawBSON = try Document(fromBSON: doc.rawBSON)
        expect(doc).to(equal(fromRawBSON))
    }

    func testCopyOnWriteBehavior() {
        var doc1: Document? = ["a": 1]
        let originalAddress = doc1?.pointerAddress
        var doc2 = doc1!
        // no mutation has happened, so addresses should be the same
        expect(doc2.pointerAddress).to(equal(originalAddress))

        doc2["b"] = 2

        // only should have mutated doc2
        expect(doc1?["b"]).to(beNil())
        expect(doc2["b"]).to(equal(2))

        // doc1 should have kept original storage, doc2 has a copy
        expect(doc1?.pointerAddress).to(equal(originalAddress))
        expect(doc2.pointerAddress).toNot(equal(originalAddress))

        doc1!["c"] = 3

        // mutating doc1 should not mutate doc2
        expect(doc1?["c"]).to(equal(3))
        expect(doc2["c"]).to(beNil())

        // doc1 keeps same same storage, since no other references
        expect(doc1?.pointerAddress).to(equal(originalAddress))

        var doc3 = doc1!
        expect(doc3.pointerAddress).to(equal(originalAddress))

        doc1 = nil // now doc3 has the only reference to originalAddress
        doc3["d"] = 5
        // since the storage is uniquely referenced, doc3 keeps it
        expect(doc3.pointerAddress).to(equal(originalAddress))
    }

    func testIntEncodesAsInt32OrInt64() {
        guard !MongoSwiftTestCase.is32Bit else {
            return
        }

        let int32min_sub1 = Int64(Int32.min) - Int64(1)
        let int32max_add1 = Int64(Int32.max) + Int64(1)

        let doc: Document = [
            "int32min": BSON(Int(Int32.min)),
            "int32max": BSON(Int(Int32.max)),
            "int32min-1": BSON(Int(int32min_sub1)),
            "int32max+1": BSON(Int(int32max_add1)),
            "int64min": BSON(Int(Int64.min)),
            "int64max": BSON(Int(Int64.max))
        ]

        expect(doc["int32min"]).to(equal(.int64(Int64(Int32.min))))
        expect(doc["int32max"]).to(equal(.int64(Int64(Int32.max))))
        expect(doc["int32min-1"]).to(equal(.int64(int32min_sub1)))
        expect(doc["int32max+1"]).to(equal(.int64(int32max_add1)))
        expect(doc["int64min"]).to(equal(.int64(Int64.min)))
        expect(doc["int64max"]).to(equal(.int64(Int64.max)))
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
        let arr1: BSON = ["a", "b", "c", .null]
        let arr2: BSON = ["d", "e", .null, "f"]

        let doc = ["a1": arr1, "a2": arr2]

        expect(doc["a1"]).to(equal(arr1))
        expect(doc["a2"]).to(equal(arr2))
    }

    // exclude Int64 value on 32-bit platforms
    static let overwritables: Document = [
        "double": 2.5,
        "int32": .int32(32),
        "int64": .int64(Int64.max),
        "bool": false,
        "decimal": .decimal128(Decimal128("1.2E+10")!),
        "oid": .objectId(ObjectId()),
        "timestamp": .timestamp(Timestamp(timestamp: 1, inc: 2)),
        "datetime": .datetime(Date(msSinceEpoch: 1000))
    ]

    static let nonOverwritables: Document = [
        "string": "hello",
        "nil": .null,
        "doc": ["x": 1],
        "arr": [1, 2]
    ]

    // test replacing `Overwritable` types with values of their own type
    func testOverwritable() throws {
        // make a deep copy so we start off with uniquely referenced storage
        var doc = DocumentTests.overwritables.withBSONPointer { ptr in
            Document(copying: ptr)
        }

        // save a reference to original bson_t so we can verify it doesn't change
        let pointer = doc.pointerAddress

        print("pointer is: \(pointer)")

        // overwrite int32 with int32
        doc["int32"] = .int32(15)
        expect(doc["int32"]).to(equal(.int32(15)))
        expect(doc.pointerAddress).to(equal(pointer))

        doc["bool"] = true
        expect(doc.pointerAddress).to(equal(pointer))

        doc["double"] = 3.0
        expect(doc.pointerAddress).to(equal(pointer))

        doc["decimal"] = .decimal128(Decimal128("100")!)
        expect(doc.pointerAddress).to(equal(pointer))

        // overwrite int64 with int64
        doc["int64"] = .int64(Int64.min)
        expect(doc.pointerAddress).to(equal(pointer))

        let newOid = ObjectId()
        doc["oid"] = .objectId(newOid)
        expect(doc.pointerAddress).to(equal(pointer))

        doc["timestamp"] = .timestamp(Timestamp(timestamp: 5, inc: 10))
        expect(doc.pointerAddress).to(equal(pointer))

        doc["datetime"] = .datetime(Date(msSinceEpoch: 2000))
        expect(doc.pointerAddress).to(equal(pointer))

        expect(doc).to(equal([
            "double": 3.0,
            "int32": .int32(15),
            "int64": .int64(Int64.min),
            "bool": true,
            "decimal": .decimal128(Decimal128("100")!),
            "oid": .objectId(newOid),
            "timestamp": .timestamp(Timestamp(timestamp: 5, inc: 10)),
            "datetime": .datetime(Date(msSinceEpoch: 2000))
        ]))

        // return early as we will to use an Int requiring > 32 bits after this
        if MongoSwiftTestCase.is32Bit {
            return
        }

        let bigInt = Int(Int32.max) + 1
        doc["int64"] = BSON(integerLiteral: bigInt)
        expect(doc.pointerAddress).to(equal(pointer))

        // final values
        expect(doc).to(equal([
            "double": 3.0,
            "int32": .int32(15),
            "int64": BSON(integerLiteral: bigInt),
            "bool": true,
            "decimal": .decimal128(Decimal128("100")!),
            "oid": .objectId(newOid),
            "timestamp": .timestamp(Timestamp(timestamp: 5, inc: 10)),
            "datetime": .datetime(Date(msSinceEpoch: 2000))
        ]))

        // should not be able to overwrite an int32 with an int on a 64-bit system
        doc["int32"] = 20
        expect(doc["int32"]).to(equal(.int64(20)))
        expect(doc.pointerAddress).toNot(equal(pointer))
    }

    // test replacing some of the non-Overwritable types with values of their own types
    func testNonOverwritable() throws {
        // make a deep copy so we start off with uniquely referenced storage
        var doc = DocumentTests.nonOverwritables.withBSONPointer { ptr in
            Document(copying: ptr)
        }

        // save a reference to original bson_t so we can verify it changes
        var pointer = doc.pointerAddress

        // save these to compare to at the end
        let newDoc: Document = ["y": 1]

        let newPairs: [(String, BSON)] = [("string", "hi"), ("doc", .document(newDoc)), ("arr", [3, 4])]

        newPairs.forEach { k, v in
            doc[k] = v
            // the storage should change every time
            expect(doc.pointerAddress).toNot(equal(pointer))
            pointer = doc.pointerAddress
        }

        expect(doc).to(equal(["string": "hi", "nil": .null, "doc": .document(newDoc), "arr": [3, 4]]))
    }

    // test replacing both overwritable and nonoverwritable values with values of different types
    func testReplaceValueWithNewType() throws {
        // make a deep copy so we start off with uniquely referenced storage
        var overwritableDoc = DocumentTests.overwritables.withBSONPointer { ptr in
            Document(copying: ptr)
        }

        // save a reference to original bson_t so we can verify it changes
        var overwritablePointer = overwritableDoc.pointerAddress

        let newOid = ObjectId()
        let overwritablePairs: [(String, BSON)] = [
            ("double", BSON(10)),
            ("int32", "hi"),
            ("int64", .decimal128(Decimal128("1.0")!)),
            ("bool", [1, 2, 3]),
            ("decimal", 100),
            ("oid", 25.5),
            ("timestamp", .objectId(newOid)),
            ("datetime", .timestamp(Timestamp(timestamp: 1, inc: 2)))
        ]

        overwritablePairs.forEach { k, v in
            overwritableDoc[k] = v
            expect(overwritableDoc.pointerAddress).toNot(equal(overwritablePointer))
            overwritablePointer = overwritableDoc.pointerAddress
        }

        expect(overwritableDoc).to(equal([
            "double": BSON(10),
            "int32": "hi",
            "int64": .decimal128(Decimal128("1.0")!),
            "bool": [1, 2, 3],
            "decimal": 100,
            "oid": 25.5,
            "timestamp": .objectId(newOid),
            "datetime": .timestamp(Timestamp(timestamp: 1, inc: 2))
        ]))

        // make a deep copy so we start off with uniquely referenced storage
        var nonOverwritableDoc = DocumentTests.nonOverwritables.withBSONPointer { ptr in
            Document(copying: ptr)
        }

        // save a reference to original bson_t so we can verify it changes
        var nonOverwritablePointer = nonOverwritableDoc.pointerAddress

        let nonOverwritablePairs: [(String, BSON)] = [("string", 1), ("nil", "hello"), ("doc", "hi"), ("arr", 5)]

        nonOverwritablePairs.forEach { k, v in
            nonOverwritableDoc[k] = v
            expect(nonOverwritableDoc.pointerAddress).toNot(equal(nonOverwritablePointer))
            nonOverwritablePointer = nonOverwritableDoc.pointerAddress
        }

        expect(nonOverwritableDoc).to(equal(["string": 1, "nil": "hello", "doc": "hi", "arr": 5]))
    }

    // test setting both overwritable and nonoverwritable values to nil
    func testReplaceValueWithNil() throws {
        var overwritableDoc = DocumentTests.overwritables.withBSONPointer { ptr in
            Document(copying: ptr)
        }
        var overwritablePointer = overwritableDoc.pointerAddress

        ["double", "int32", "int64", "bool", "decimal", "oid", "timestamp", "datetime"].forEach {
            overwritableDoc[$0] = .null
            // the storage should change every time
            expect(overwritableDoc.pointerAddress).toNot(equal(overwritablePointer))
            overwritablePointer = overwritableDoc.pointerAddress
        }

        var nonOverwritableDoc = DocumentTests.nonOverwritables.withBSONPointer { ptr in
            Document(copying: ptr)
        }
        var nonOverwritablePointer = nonOverwritableDoc.pointerAddress

        ["string", "doc", "arr"].forEach {
            nonOverwritableDoc[$0] = .null
            // the storage should change every time
            expect(nonOverwritableDoc.pointerAddress).toNot(equal(nonOverwritablePointer))
            nonOverwritablePointer = nonOverwritableDoc.pointerAddress
        }

        expect(nonOverwritableDoc).to(
            equal(["string": .null, "nil": .null, "doc": .null, "arr": .null]))
    }

    // Test types where replacing them with an instance of their own type is a no-op
    func testReplaceValueNoop() throws {
        var noops: Document = ["null": .null, "maxkey": .maxKey, "minkey": .minKey]

        var pointer = noops.pointerAddress

        // replace values with own types. these should all be no-ops
        let newPairs1: [(String, BSON)] = [("null", .null), ("maxkey", .maxKey), ("minkey", .minKey)]

        newPairs1.forEach { k, v in
            noops[k] = v
            // the storage should never change
            expect(noops.pointerAddress).to(equal(pointer))
        }

        // we should still have exactly the same document we started with
        expect(noops).to(equal(["null": .null, "maxkey": .maxKey, "minkey": .minKey]))

        // now try replacing them with values of different types that do require replacing storage
        let newPairs2: [(String, BSON)] = [("null", 5), ("maxkey", "hi"), ("minkey", false)]

        newPairs2.forEach { k, v in
            noops[k] = v
            // the storage should change every time
            expect(noops.pointerAddress).toNot(equal(pointer))
            pointer = noops.pointerAddress
        }

        expect(noops).to(equal(["null": 5, "maxkey": "hi", "minkey": false]))
    }

    func testDocumentDictionarySimilarity() throws {
        var doc: Document = ["hello": "world", "swift": 4.2, "null": .null, "remove_me": "please"]
        let dict: [String: BSON] = ["hello": "world", "swift": 4.2, "null": .null, "remove_me": "please"]

        expect(doc["hello"]).to(equal(dict["hello"]))
        expect(doc["swift"]).to(equal(dict["swift"]))
        expect(doc["nonexistent key"]).to(beNil())
        expect(doc["null"]).to(equal(dict["null"]))

        doc["remove_me"] = nil

        expect(doc["remove_me"]).to(beNil())
        expect(doc.hasKey("remove_me")).to(beFalse())
    }

    func testDefaultSubscript() throws {
        let doc: Document = ["hello": "world"]
        let floatVal = 18.2
        let stringVal = "this is a string"
        expect(doc["DNE", default: .double(floatVal)]).to(equal(.double(floatVal)))
        expect(doc["hello", default: .double(floatVal)]).to(equal(doc["hello"]))
        expect(doc["DNE", default: .string(stringVal)]).to(equal(.string(stringVal)))
        expect(doc["DNE", default: .null]).to(equal(.null))
        expect(doc["autoclosure test", default: .double(floatVal * floatVal)]).to(equal(.double(floatVal * floatVal)))
        expect(doc["autoclosure test", default: .string("\(stringVal) and \(floatVal)" + stringVal)])
            .to(equal(.string("\(stringVal) and \(floatVal)" + stringVal)))
    }

    func testMultibyteCharacterStrings() throws {
        let str = String(repeating: "🇧🇷", count: 10)

        var doc: Document = ["first": .string(str)]
        expect(doc["first"]).to(equal(.string(str)))

        let doc1: Document = [str: "second"]
        expect(doc1[str]).to(equal("second"))

        let abt = try CodecTests.AllBSONTypes.factory()
        Mirror(reflecting: abt).children.forEach { child in
            let value = child.value as! BSONValue
            doc[str] = value.bson
            expect(doc[str]).to(equal(value.bson))
        }
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
        expect(defaultEncoding["uuid"]).to(equal(.binary(binary)))

        encoder.uuidEncodingStrategy = .binary
        let binaryEncoding = try encoder.encode(uuidStruct)
        expect(binaryEncoding["uuid"]).to(equal(.binary(binary)))

        encoder.uuidEncodingStrategy = .deferredToUUID
        let deferred = try encoder.encode(uuidStruct)
        expect(deferred["uuid"]).to(equal(.string(uuid.uuidString)))
    }

    func testUUIDDecodingStrategies() throws {
        // randomly generated uuid
        let uuid = UUID(uuidString: "2c380a6c-7bc5-48cb-84a2-b26777a72276")!

        let decoder = BSONDecoder()

        // UUID default decoder expects a string
        decoder.uuidDecodingStrategy = .deferredToUUID
        let stringDoc: Document = ["uuid": .string(uuid.description)]
        let badString: Document = ["uuid": "hello"]
        let deferredStruct = try decoder.decode(UUIDWrapper.self, from: stringDoc)
        expect(deferredStruct.uuid).to(equal(uuid))
        expect(try decoder.decode(UUIDWrapper.self, from: badString)).to(throwError(CodecTests.dataCorruptedErr))

        decoder.uuidDecodingStrategy = .binary
        let uuidt = uuid.uuid
        let bytes = Data([
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])
        let binaryDoc: Document = ["uuid": .binary(try Binary(data: bytes, subtype: .uuid))]
        let binaryStruct = try decoder.decode(UUIDWrapper.self, from: binaryDoc)
        expect(binaryStruct.uuid).to(equal(uuid))

        let badBinary: Document = ["uuid": .binary(try Binary(data: bytes, subtype: .generic))]
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
        expect(defaultEncoding["date"]).to(equal(.datetime(date)))

        encoder.dateEncodingStrategy = .bsonDateTime
        let bsonDate = try encoder.encode(dateStruct)
        expect(bsonDate["date"]).to(equal(.datetime(date)))

        encoder.dateEncodingStrategy = .secondsSince1970
        let secondsSince1970 = try encoder.encode(dateStruct)
        expect(secondsSince1970["date"]).to(equal(.double(date.timeIntervalSince1970)))

        encoder.dateEncodingStrategy = .millisecondsSince1970
        let millisecondsSince1970 = try encoder.encode(dateStruct)
        expect(millisecondsSince1970["date"]).to(equal(.int64(date.msSinceEpoch)))

        if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            encoder.dateEncodingStrategy = .iso8601
            let iso = try encoder.encode(dateStruct)
            expect(iso["date"]).to(equal(.string(BSONDecoder.iso8601Formatter.string(from: date))))
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .full
        formatter.dateStyle = .short

        encoder.dateEncodingStrategy = .formatted(formatter)
        let formatted = try encoder.encode(dateStruct)
        expect(formatted["date"]).to(equal(.string(formatter.string(from: date))))

        encoder.dateEncodingStrategy = .deferredToDate
        let deferred = try encoder.encode(dateStruct)
        expect(deferred["date"]).to(equal(.double(date.timeIntervalSinceReferenceDate)))

        encoder.dateEncodingStrategy = .custom({ d, e in
            var container = e.singleValueContainer()
            try container.encode(Int64(d.timeIntervalSince1970 + 12))
        })
        let custom = try encoder.encode(dateStruct)
        expect(custom["date"]).to(equal(.int64(Int64(date.timeIntervalSince1970 + 12))))

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let noSecondsDate = DateWrapper(date: dateFormatter.date(from: "1/2/19")!)
        encoder.dateEncodingStrategy = .custom({ d, e in
            var container = e.unkeyedContainer()
            try dateFormatter.string(from: d).split(separator: "/").forEach { component in
                try container.encode(String(component))
            }
        })
        let customArr = try encoder.encode(noSecondsDate)
        expect(dateFormatter.date(from: (customArr["date"]?
                .arrayValue?
                .compactMap { $0.stringValue }
                .joined(separator: "/"))!)
        ).to(equal(noSecondsDate.date))

        enum DateKeys: String, CodingKey {
            case month, day, year
        }

        encoder.dateEncodingStrategy = .custom({ d, e in
            var container = e.container(keyedBy: DateKeys.self)
            let components = dateFormatter.string(from: d).split(separator: "/").map { String($0) }
            try container.encode(components[0], forKey: .month)
            try container.encode(components[1], forKey: .day)
            try container.encode(components[2], forKey: .year)
        })
        let customDoc = try encoder.encode(noSecondsDate)
        expect(customDoc["date"]).to(equal(["month": "1", "day": "2", "year": "19"]))

        encoder.dateEncodingStrategy = .custom({ _, _ in })
        let customNoop = try encoder.encode(noSecondsDate)
        expect(customNoop["date"]).to(equal([:]))
    }

    func testDateDecodingStrategies() throws {
        let decoder = BSONDecoder()

        let date = Date(timeIntervalSince1970: 125.0)

        // Default is .bsonDateTime
        let bsonDate: Document = ["date": .datetime(date)]
        let defaultStruct = try decoder.decode(DateWrapper.self, from: bsonDate)
        expect(defaultStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .bsonDateTime
        let bsonDateStruct = try decoder.decode(DateWrapper.self, from: bsonDate)
        expect(bsonDateStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .millisecondsSince1970
        let msInt64: Document = ["date": .int64(date.msSinceEpoch)]
        let msInt64Struct = try decoder.decode(DateWrapper.self, from: msInt64)
        expect(msInt64Struct.date).to(equal(date))
        expect(try BSONDecoder().decode(DateWrapper.self, from: msInt64)).to(throwError(CodecTests.typeMismatchErr))

        let msDouble: Document = ["date": .double(Double(date.msSinceEpoch))]
        let msDoubleStruct = try decoder.decode(DateWrapper.self, from: msDouble)
        expect(msDoubleStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .secondsSince1970
        let sDouble: Document = ["date": .double(date.timeIntervalSince1970)]
        let sDoubleStruct = try decoder.decode(DateWrapper.self, from: sDouble)
        expect(sDoubleStruct.date).to(equal(date))

        let sInt64: Document = ["date": .double(date.timeIntervalSince1970)]
        let sInt64Struct = try decoder.decode(DateWrapper.self, from: sInt64)
        expect(sInt64Struct.date).to(equal(date))

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "en_US")

        decoder.dateDecodingStrategy = .formatted(formatter)
        let formatted: Document = ["date": .string(formatter.string(from: date))]
        let badlyFormatted: Document = ["date": "this is not a date"]
        let formattedStruct = try decoder.decode(DateWrapper.self, from: formatted)
        expect(formattedStruct.date).to(equal(date))
        expect(try decoder.decode(DateWrapper.self, from: badlyFormatted)).to(throwError(CodecTests.dataCorruptedErr))
        expect(try decoder.decode(DateWrapper.self, from: sDouble)).to(throwError(CodecTests.typeMismatchErr))

        if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            decoder.dateDecodingStrategy = .iso8601
            let isoDoc: Document = ["date": .string(BSONDecoder.iso8601Formatter.string(from: date))]
            let isoStruct = try decoder.decode(DateWrapper.self, from: isoDoc)
            expect(isoStruct.date).to(equal(date))
            expect(try decoder.decode(DateWrapper.self, from: formatted)).to(throwError(CodecTests.dataCorruptedErr))
            expect(try decoder.decode(DateWrapper.self, from: badlyFormatted))
                .to(throwError(CodecTests.dataCorruptedErr))
        }

        decoder.dateDecodingStrategy = .custom({ decode in try Date(from: decode) })
        let customDoc: Document = ["date": .double(date.timeIntervalSinceReferenceDate)]
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
        let arrData = data.map { byte in Int32(byte) }
        let dataStruct = DataWrapper(data: data)

        let defaultDoc = try encoder.encode(dataStruct)
        expect(defaultDoc["data"]?.binaryValue).to(equal(binaryData))
        let roundTripDefault = try decoder.decode(DataWrapper.self, from: defaultDoc)
        expect(roundTripDefault.data).to(equal(data))

        encoder.dataEncodingStrategy = .binary
        decoder.dataDecodingStrategy = .binary
        let binaryDoc = try encoder.encode(dataStruct)
        expect(binaryDoc["data"]?.binaryValue).to(equal(binaryData))
        let roundTripBinary = try decoder.decode(DataWrapper.self, from: binaryDoc)
        expect(roundTripBinary.data).to(equal(data))

        encoder.dataEncodingStrategy = .deferredToData
        decoder.dataDecodingStrategy = .deferredToData
        let deferredDoc = try encoder.encode(dataStruct)
        expect(deferredDoc["data"]?.arrayValue?.compactMap { $0.int32Value }).to(equal(arrData))
        let roundTripDeferred = try decoder.decode(DataWrapper.self, from: deferredDoc)
        expect(roundTripDeferred.data).to(equal(data))
        expect(try decoder.decode(DataWrapper.self, from: defaultDoc)).to(throwError(CodecTests.typeMismatchErr))

        encoder.dataEncodingStrategy = .base64
        decoder.dataDecodingStrategy = .base64
        let base64Doc = try encoder.encode(dataStruct)
        expect(base64Doc["data"]?.stringValue).to(equal(data.base64EncodedString()))
        let roundTripBase64 = try decoder.decode(DataWrapper.self, from: base64Doc)
        expect(roundTripBase64.data).to(equal(data))
        expect(try decoder.decode(DataWrapper.self, from: ["data": "this is not base64 encoded~"]))
            .to(throwError(CodecTests.dataCorruptedErr))

        let customEncodedDoc: Document = [
            "d": .string(data.base64EncodedString()),
            "hash": .int64(Int64(data.hashValue))
        ]
        encoder.dataEncodingStrategy = .custom({ _, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(customEncodedDoc)
        })
        decoder.dataDecodingStrategy = .custom({ decoder in
            let doc = try Document(from: decoder)
            guard let d = Data(base64Encoded: doc["d"]!.stringValue!) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "bad base64"))
            }
            expect(d.hashValue).to(equal(data.hashValue))
            return d
        })
        let customDoc = try encoder.encode(dataStruct)
        expect(customDoc["data"]).to(equal(.document(customEncodedDoc)))
        let roundTripCustom = try decoder.decode(DataWrapper.self, from: customDoc)
        expect(roundTripCustom.data).to(equal(data))

        encoder.dataEncodingStrategy = .custom({ _, _ in })
        expect(try encoder.encode(dataStruct)).to(equal(["data": [:]]))
    }

    func testIntegerLiteral() {
        let doc: Document = ["int": 12]

        if MongoSwiftTestCase.is32Bit {
            expect(doc["int"]).to(equal(.int32(12)))
            expect(doc["int"]?.type).to(equal(.int32))
        } else {
            expect(doc["int"]?.type).to(equal(.int64))
            expect(doc["int"]).to(equal(.int64(12)))
        }

        let bson: BSON = 12
        expect(doc["int"]).to(equal(bson))
    }

    func testInvalidBSON() throws {
        let invalidData = [
            Data(count: 0), // too short
            Data(count: 4), // too short
            Data(hexString: "0100000000")!, // incorrectly sized
            Data(hexString: "0500000001")! // correctly sized, but doesn't end with null byte
        ]

        for data in invalidData {
            expect(try Document(fromBSON: data)).to(throwError(errorType: InvalidArgumentError.self))
        }
    }
}
