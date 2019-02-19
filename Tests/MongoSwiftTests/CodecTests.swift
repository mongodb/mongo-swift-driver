@testable import MongoSwift
import Nimble
import XCTest

final class CodecTests: MongoSwiftTestCase {
    // generic decoding/encoding errors for error matching. Only the case is considered.
    static let typeMismatchErr = DecodingError._typeMismatch(at: [], expectation: Int.self, reality: 0)
    static let invalidValueErr =
            EncodingError.invalidValue(0, EncodingError.Context(codingPath: [], debugDescription: "dummy error"))
    static let dataCorruptedErr = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "dummy error"))

    func testEncodeListDatabasesOptions() throws {
        let options = ListDatabasesOptions(filter: ["a": 10], nameOnly: true, session: ClientSession())
        let expected: Document = ["filter": ["a": 10] as Document, "nameOnly": true, "session": Document()]
        expect(try BSONEncoder().encode(options)).to(equal(expected))
    }

    struct TestClass: Encodable {
        let val1 = "a"
        let val2 = 0
        let val3 = [[1, 2], [3, 4]]
        let val4 = TestClass2()
        let val5 = [TestClass2()]
    }

    struct TestClass2: Encodable {
        let x = 1
        let y = 2
    }

    struct BasicStruct: Codable, Equatable {
        let int: Int
        let string: String

        public static func == (lhs: BasicStruct, rhs: BasicStruct) -> Bool {
            return lhs.int == rhs.int && lhs.string == rhs.string
        }
    }

    struct NestedStruct: Codable, Equatable {
        let s1: BasicStruct
        let s2: BasicStruct

        public static func == (lhs: NestedStruct, rhs: NestedStruct) -> Bool {
            return lhs.s1 == rhs.s1 && lhs.s2 == rhs.s2
        }
    }

    struct NestedArray: Codable, Equatable {
        let array: [BasicStruct]

        public static func == (lhs: NestedArray, rhs: NestedArray) -> Bool {
            return lhs.array == rhs.array
        }
    }

    struct NestedNestedStruct: Codable, Equatable {
        let s: NestedStruct

        public static func == (lhs: NestedNestedStruct, rhs: NestedNestedStruct) -> Bool {
            return lhs.s == rhs.s
        }
    }

    /// Test encoding/decoding a variety of structs containing simple types that have 
    /// built in Codable support (strings, arrays, ints, and structs composed of them.)
    func testStructs() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        let expected: Document = [
            "val1": "a",
            "val2": 0,
            "val3": [[1, 2], [3, 4]],
            "val4": ["x": 1, "y": 2] as Document,
            "val5": [["x": 1, "y": 2] as Document]
        ]

        expect(try encoder.encode(TestClass())).to(equal(expected))

        // a basic struct 
        let basic1 = BasicStruct(int: 1, string: "hello")
        let basic1Doc: Document = ["int": 1, "string": "hello"]
        expect(try encoder.encode(basic1)).to(equal(basic1Doc))
        expect(try decoder.decode(BasicStruct.self, from: basic1Doc)).to(equal(basic1))

        // a struct storing two nested structs as properties
        let basic2 = BasicStruct(int: 2, string: "hi")
        let basic2Doc: Document = ["int": 2, "string": "hi"]

        let nestedStruct = NestedStruct(s1: basic1, s2: basic2)
        let nestedStructDoc: Document = ["s1": basic1Doc, "s2": basic2Doc]
        expect(try encoder.encode(nestedStruct)).to(equal(nestedStructDoc))
        expect(try decoder.decode(NestedStruct.self, from: nestedStructDoc)).to(equal(nestedStruct))

        // a struct storing two nested structs in an array
        let nestedArray = NestedArray(array: [basic1, basic2])
        let nestedArrayDoc: Document = ["array": [basic1Doc, basic2Doc]]
        expect(try encoder.encode(nestedArray)).to(equal(nestedArrayDoc))
        expect(try decoder.decode(NestedArray.self, from: nestedArrayDoc)).to(equal(nestedArray))

        // one more level of nesting
        let nestedNested = NestedNestedStruct(s: nestedStruct)
        let nestedNestedDoc: Document = ["s": nestedStructDoc]
        expect(try encoder.encode(nestedNested)).to(equal(nestedNestedDoc))
        expect(try decoder.decode(NestedNestedStruct.self, from: nestedNestedDoc)).to(equal(nestedNested))
    }

    struct OptionalsStruct: Codable, Equatable {
        let int: Int?
        let bool: Bool?
        let string: String

        public static func == (lhs: OptionalsStruct, rhs: OptionalsStruct) -> Bool {
            return lhs.int == rhs.int && lhs.bool == rhs.bool && lhs.string == rhs.string
        }
    }

    /// Test encoding/decoding a struct containing optional values.
    func testOptionals() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        let s1 = OptionalsStruct(int: 1, bool: true, string: "hi")
        let s1Doc: Document = ["int": 1, "bool": true, "string": "hi"]
        expect(try encoder.encode(s1)).to(equal(s1Doc))
        expect(try decoder.decode(OptionalsStruct.self, from: s1Doc)).to(equal(s1))

        let s2 = OptionalsStruct(int: nil, bool: true, string: "hi")
        let s2Doc1: Document = ["bool": true, "string": "hi"]
        expect(try encoder.encode(s2)).to(equal(s2Doc1))
        expect(try decoder.decode(OptionalsStruct.self, from: s2Doc1)).to(equal(s2))

        // test with key in doc explicitly set to BSONNull
        let s2Doc2: Document = ["int": BSONNull(), "bool": true, "string": "hi"]
        expect(try decoder.decode(OptionalsStruct.self, from: s2Doc2)).to(equal(s2))
    }

    struct Numbers: Codable, Equatable {
        let int8: Int8?
        let int16: Int16?
        let uint8: UInt8?
        let uint16: UInt16?
        let uint32: UInt32?
        let uint64: UInt64?
        let uint: UInt?
        let float: Float?

        static let keys = ["int8", "int16", "uint8", "uint16", "uint32", "uint64", "uint", "float"]

        public static func == (lhs: Numbers, rhs: Numbers) -> Bool {
            return lhs.int8 == rhs.int8 && lhs.int16 == rhs.int16 &&
                    lhs.uint8 == rhs.uint8 && lhs.uint16 == rhs.uint16 &&
                    lhs.uint32 == rhs.uint32 && lhs.uint64 == rhs.uint64 &&
                    lhs.uint == rhs.uint && lhs.float == rhs.float
        }

        init(int8: Int8? = nil,
             int16: Int16? = nil,
             uint8: UInt8? = nil,
             uint16: UInt16? = nil,
             uint32: UInt32? = nil,
             uint64: UInt64? = nil,
             uint: UInt? = nil,
             float: Float? = nil) {
            self.int8 = int8
            self.int16 = int16
            self.uint8 = uint8
            self.uint16 = uint16
            self.uint32 = uint32
            self.uint64 = uint64
            self.uint = uint
            self.float = float
        }
    }

    /// Test encoding where the struct's numeric types are non-BSON
    /// and require conversions.
    func testEncodingNonBSONNumbers() throws {
        let encoder = BSONEncoder()

        let s1 = Numbers(int8: 42, int16: 42, uint8: 42, uint16: 42, uint32: 42, uint64: 42, uint: 42, float: 42)
        // all should be stored as Int32s, except the float should be stored as a double
        let doc1: Document = [
            "int8": 42, "int16": 42, "uint8": 42, "uint16": 42,
            "uint32": 42, "uint64": 42, "uint": 42, "float": 42.0
        ]

        expect(try encoder.encode(s1)).to(equal(doc1))

        // check that a UInt32 too large for an Int32 gets converted to Int64
        expect(try encoder.encode(Numbers(uint32: 4294967295))).to(equal(["uint32": Int64(4294967295)]))

        // check that UInt, UInt64 too large for an Int32 gets converted to Int64
        expect(try encoder.encode(Numbers(uint64: 4294967295))).to(equal(["uint64": Int64(4294967295)]))
        expect(try encoder.encode(Numbers(uint: 4294967295))).to(equal(["uint": Int64(4294967295)]))

        // check that UInt, UInt64 too large for an Int64 gets converted to Double
        expect(try encoder.encode(Numbers(uint64: UInt64(Int64.max) + 1))).to(equal(["uint64": 9223372036854775808.0]))
        expect(try encoder.encode(Numbers(uint: UInt(Int64.max) + 1))).to(equal(["uint": 9223372036854775808.0]))

        // check that we fail gracefully with a UInt, UInt64 that can't fit in any type.
        // Swift 4.0 is unable to properly handle these edge cases and returns incorrect
        // values from `Double(exactly:)`.
        // 4.1 fixes this -- see https://bugs.swift.org/browse/SR-7056.
        #if swift(>=4.1)
        expect(try encoder.encode(Numbers(uint64: UInt64.max))).to(throwError(CodecTests.invalidValueErr))
        expect(try encoder.encode(Numbers(uint: UInt.max))).to(throwError(CodecTests.invalidValueErr))
        #endif
    }

    /// Test decoding where the requested numeric types are non-BSON
    /// and require conversions.
    func testDecodingNonBSONNumbers() throws {
        let decoder = BSONDecoder()

        // the struct we expect to get back
        let s = Numbers(int8: 42, int16: 42, uint8: 42, uint16: 42, uint32: 42, uint64: 42, uint: 42, float: 42)

        // store all values as Int32s and decode them to their requested types
        var doc1 = Document()
        for k in Numbers.keys {
            doc1[k] = 42
        }
        let res1 = try decoder.decode(Numbers.self, from: doc1)
        expect(res1).to(equal(s))

        // store all values as Int64s and decode them to their requested types.
        var doc2 = Document()
        for k in Numbers.keys {
            doc2[k] = Int64(42)
        }

        let res2 = try decoder.decode(Numbers.self, from: doc2)
        expect(res2).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        var doc3 = Document()
        for k in Numbers.keys {
            doc3[k] = Double(42)
        }

        let res3 = try decoder.decode(Numbers.self, from: doc3)
        expect(res3).to(equal(s))

        // test for each type that we fail gracefully when values cannot be represented because they are out of bounds
        expect(try decoder.decode(Numbers.self, from: ["int8": Int(Int8.max) + 1]))
                .to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["int16": Int(Int16.max) + 1]))
                .to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint8": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: [ "uint16": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint32": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint64": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["float": Double.greatestFiniteMagnitude]))
                .to(throwError(CodecTests.typeMismatchErr))
    }

     struct BSONNumbers: Codable, Equatable {
        let int: Int
        let int32: Int32
        let int64: Int64
        let double: Double

        public static func == (lhs: BSONNumbers, rhs: BSONNumbers) -> Bool {
            return lhs.int == rhs.int && lhs.int32 == rhs.int32 &&
                    lhs.int64 == rhs.int64 && lhs.double == rhs.double
        }
    }

    /// Test that BSON number types are encoded properly, and can be decoded from any type they are stored as
    func testBSONNumbers() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()
        // the struct we expect to get back
        let s = BSONNumbers(int: 42, int32: 42, int64: 42, double: 42)
        expect(try encoder.encode(s)).to(equal([
            "int": Int(42),
            "int32": Int32(42),
            "int64": Int64(42),
            "double": Double(42)
        ]))

        // store all values as Int32s and decode them to their requested types
        let doc1: Document = ["int": Int32(42), "int32": Int32(42), "int64": Int32(42), "double": Int32(42)]
        expect(try decoder.decode(BSONNumbers.self, from: doc1)).to(equal(s))

        // store all values as Int64s and decode them to their requested types
        let doc2: Document = ["int": Int64(42), "int32": Int64(42), "int64": Int64(42), "double": Int64(42)]
        expect(try decoder.decode(BSONNumbers.self, from: doc2)).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        let doc3: Document = ["int": Double(42), "int32": Double(42), "int64": Double(42), "double": Double(42)]
        expect(try decoder.decode(BSONNumbers.self, from: doc3)).to(equal(s))
    }

    struct AllBSONTypes: Codable, Equatable {
        let double: Double
        let string: String
        let doc: Document
        let arr: [Int]
        let binary: Binary
        let oid: ObjectId
        let bool: Bool
        let date: Date
        let code: CodeWithScope
        let int: Int
        let ts: Timestamp
        let int32: Int32
        let int64: Int64
        let dec: Decimal128
        let minkey: MinKey
        let maxkey: MaxKey
        let regex: RegularExpression

        public static func == (lhs: AllBSONTypes, rhs: AllBSONTypes) -> Bool {
            return lhs.double == rhs.double && lhs.string == rhs.string &&
                    lhs.doc == rhs.doc && lhs.arr == rhs.arr && lhs.binary == rhs.binary &&
                    lhs.oid == rhs.oid && lhs.bool == rhs.bool && lhs.code == rhs.code &&
                    lhs.int == rhs.int && lhs.ts == rhs.ts && lhs.int32 == rhs.int32 &&
                    lhs.int64 == rhs.int64 && lhs.dec == rhs.dec && lhs.minkey == rhs.minkey &&
                    lhs.maxkey == rhs.maxkey && lhs.regex == rhs.regex && lhs.date == rhs.date
        }
    }

    /// Test decoding/encoding to all possible BSON types
    func testBSONValues() throws {
        let expected = AllBSONTypes(
                            double: Double(2),
                            string: "hi",
                            doc: ["x": 1],
                            arr: [1, 2],
                            binary: try Binary(base64: "//8=", subtype: .generic),
                            oid: ObjectId(fromString: "507f1f77bcf86cd799439011"),
                            bool: true,
                            date: Date(timeIntervalSinceReferenceDate: 5000),
                            code: CodeWithScope(code: "hi", scope: ["x": 1]),
                            int: 1,
                            ts: Timestamp(timestamp: 1, inc: 2),
                            int32: 5,
                            int64: 6,
                            dec: Decimal128("1.2E+10"),
                            minkey: MinKey(),
                            maxkey: MaxKey(),
                            regex: RegularExpression(pattern: "^abc", options: "imx")
                        )

        let decoder = BSONDecoder()

        let doc: Document = [
            "double": Double(2),
            "string": "hi",
            "doc": ["x": 1] as Document,
            "arr": [1, 2],
            "binary": try Binary(base64: "//8=", subtype: .generic),
            "oid": ObjectId(fromString: "507f1f77bcf86cd799439011"),
            "bool": true,
            "date": Date(timeIntervalSinceReferenceDate: 5000),
            "code": CodeWithScope(code: "hi", scope: ["x": 1]),
            "int": 1,
            "ts": Timestamp(timestamp: 1, inc: 2),
            "int32": 5,
            "int64": Int64(6),
            "dec": Decimal128("1.2E+10"),
            "minkey": MinKey(),
            "maxkey": MaxKey(),
            "regex": RegularExpression(pattern: "^abc", options: "imx")
        ]

        let res = try decoder.decode(AllBSONTypes.self, from: doc)
        expect(res).to(equal(expected))

        expect(try BSONEncoder().encode(expected)).to(equal(doc))

        let base64 = "//8="
        let extjson = """
        {
            "double" : 2.0,
            "string" : "hi",
            "doc" : { "x" : 1 },
            "arr" : [ 1, 2 ],
            "binary" : { "$binary" : { "base64": "\(base64)", "subType" : "00" } },
            "oid" : { "$oid" : "507f1f77bcf86cd799439011" },
            "bool" : true,
            "date" : { "$date" : "2001-01-01T01:23:20Z" },
            "code" : { "$code" : "hi", "$scope" : { "x" : 1 } },
            "int" : 1,
            "ts" : { "$timestamp" : { "t" : 1, "i" : 2 } },
            "int32" : 5, "int64" : 6,
            "dec" : { "$numberDecimal" : "1.2E+10" },
            "minkey" : { "$minKey" : 1 },
            "maxkey" : { "$maxKey" : 1 },
            "regex" : { "$regularExpression" : { "pattern" : "^abc", "options" : "imx" } }
        }
        """

        let res2 = try decoder.decode(AllBSONTypes.self, from: extjson)
        expect(res2).to(equal(expected))
    }

    /// Test decoding extJSON and JSON for standalone values
    func testDecodeScalars() throws {
        let decoder = BSONDecoder()

        expect(try decoder.decode(Int32.self, from: "42")).to(equal(Int32(42)))
        expect(try decoder.decode(Int32.self, from: "{\"$numberInt\": \"42\"}")).to(equal(Int32(42)))

        let oid = ObjectId(fromString: "507f1f77bcf86cd799439011")
        expect(try decoder.decode(ObjectId.self, from: "{\"$oid\": \"507f1f77bcf86cd799439011\"}")).to(equal(oid))

        expect(try decoder.decode(String.self, from: "\"somestring\"")).to(equal("somestring"))

        expect(try decoder.decode(Int64.self, from: "42")).to(equal(Int64(42)))
        expect(try decoder.decode(Int64.self, from: "{\"$numberLong\": \"42\"}")).to(equal(Int64(42)))

        expect(try decoder.decode(Double.self, from: "42.42")).to(equal(42.42))
        expect(try decoder.decode(Double.self, from: "{\"$numberDouble\": \"42.42\"}")).to(equal(42.42))

        expect(try decoder.decode(Decimal128.self,
                                  from: "{\"$numberDecimal\": \"1.2E+10\"}")).to(equal(Decimal128("1.2E+10")))

        let binary = try Binary(base64: "//8=", subtype: .generic)
        expect(
            try decoder.decode(Binary.self,
                               from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}")
        ).to(equal(binary))

        expect(try decoder.decode(CodeWithScope.self, from: "{\"code\": \"hi\" }")).to(equal(CodeWithScope(code: "hi")))
        let cws = CodeWithScope(code: "hi", scope: ["x": 1])
        expect(try decoder.decode(CodeWithScope.self,
                                  from: "{\"code\": \"hi\", \"scope\": {\"x\" : 1} }")).to(equal(cws))
        expect(try decoder.decode(Document.self, from: "{\"x\": 1}")).to(equal(["x": 1]))

        let ts = Timestamp(timestamp: 1, inc: 2)
        expect(try decoder.decode(Timestamp.self, from: "{ \"$timestamp\" : { \"t\" : 1, \"i\" : 2 } }")).to(equal(ts))

        let regex = RegularExpression(pattern: "^abc", options: "imx")
        expect(
            try decoder.decode(RegularExpression.self,
                               from: "{ \"$regularExpression\" : { \"pattern\" :\"^abc\", \"options\" : \"imx\" } }")
        ).to(equal(regex))

        expect(try decoder.decode(MinKey.self, from: "{\"$minKey\": 1}")).to(equal(MinKey()))
        expect(try decoder.decode(MaxKey.self, from: "{\"$maxKey\": 1}")).to(equal(MaxKey()))

        expect(try decoder.decode(Bool.self, from: "false")).to(beFalse())
        expect(try decoder.decode(Bool.self, from: "true")).to(beTrue())

        expect(try decoder.decode([Int].self, from: "[1, 2, 3]")).to(equal([1, 2, 3]))
    }

    // test that Document.init(from decoder: Decoder) works with a non BSON decoder and that
    // Document.encode(to encoder: Encoder) works with a non BSON encoder
    func testDocumentIsCodable() throws {
#if os(macOS) // presently skipped on linux due to nondeterministic key ordering
        // note: instead of doing this, one can and should just initialize a Document with the `init(fromJSON:)`
        // constructor, and conver to JSON using the .extendedJSON property. this test is just to demonstrate 
        // that a Document can theoretically work with any encoder/decoder.
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let json = """
        {
            "name": "Durian",
            "points": 600,
            "pointsDouble": 600.5,
            "description": "A fruit with a distinctive scent.",
            "array": ["a", "b", "c"],
            "doc": { "x" : 2.0 }
        }
        """

        let expected: Document = [
            "name": "Durian",
            "points": 600,
            "pointsDouble": 600.5,
            "description": "A fruit with a distinctive scent.",
            "array": ["a", "b", "c"],
            "doc": ["x": 2] as Document
        ]

        let decoded = try decoder.decode(Document.self, from: json.data(using: .utf8)!)
        expect(decoded).to(sortedEqual(expected))

        let encoded = try String(data: encoder.encode(expected), encoding: .utf8)
        expect(encoded).to(cleanEqual(json))
#endif
    }

    func testEncodeArray() throws {
        let encoder = BSONEncoder()

        let values1 = [BasicStruct(int: 1, string: "hello"), BasicStruct(int: 2, string: "hi")]
        expect(try encoder.encode(values1)).to(equal([["int": 1, "string": "hello"], ["int": 2, "string": "hi"]]))

        let values2 = [BasicStruct(int: 1, string: "hello"), nil]
        expect(try encoder.encode(values2)).to(equal([["int": 1, "string": "hello"], nil]))
    }

    struct AnyBSONStruct: Codable {
        let x: AnyBSONValue

        init(_ x: BSONValue) {
            self.x = AnyBSONValue(x)
        }
    }

    // test encoding/decoding AnyBSONValues with BSONEncoder and Decoder
    func testAnyBSONValueIsBSONCodable() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        // standalone document
        let doc: Document = ["y": 1]
        expect(try encoder.encode(AnyBSONValue(doc))).to(equal(doc))
        expect(try decoder.decode(AnyBSONValue.self, from: doc).value).to(bsonEqual(doc))
        expect(try decoder.decode(AnyBSONValue.self, from: doc.canonicalExtendedJSON).value).to(bsonEqual(doc))
        // doc wrapped in a struct

        let wrappedDoc: Document = ["x": doc]
        expect(try encoder.encode(AnyBSONStruct(doc))).to(equal(wrappedDoc))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDoc).x.value).to(bsonEqual(doc))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedDoc.canonicalExtendedJSON).x.value).to(bsonEqual(doc))

        // values wrapped in an `AnyBSONStruct`
        let double = 42.0
        expect(try decoder.decode(AnyBSONValue.self,
                                  from: "{\"$numberDouble\": \"42\"}").value).to(bsonEqual(double))

        let wrappedDouble: Document = ["x": double]
        expect(try encoder.encode(AnyBSONStruct(double))).to(equal(wrappedDouble))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDouble).x.value).to(bsonEqual(double))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedDouble.canonicalExtendedJSON).x.value).to(bsonEqual(double))

        // string
        let string = "hi"
        expect(try decoder.decode(AnyBSONValue.self, from: "\"hi\"").value).to(bsonEqual(string))

        let wrappedString: Document = ["x": string]
        expect(try encoder.encode(AnyBSONStruct(string))).to(equal(wrappedString))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedString).x.value).to(bsonEqual(string))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedString.canonicalExtendedJSON).x.value).to(bsonEqual(string))

        // array
        let array: [BSONValue] = [1, 2, "hello"]

        let decodedArray = try decoder.decode(AnyBSONValue.self, from: "[1, 2, \"hello\"]").value as? [BSONValue]
        expect(decodedArray?[0]).to(bsonEqual(1))
        expect(decodedArray?[1]).to(bsonEqual(2))
        expect(decodedArray?[2]).to(bsonEqual("hello"))

        let wrappedArray: Document = ["x": array]
        expect(try encoder.encode(AnyBSONStruct(array))).to(equal(wrappedArray))
        let decodedWrapped = try decoder.decode(AnyBSONStruct.self, from: wrappedArray).x.value as? [BSONValue]
        expect(decodedWrapped?[0]).to(bsonEqual(1))
        expect(decodedWrapped?[1]).to(bsonEqual(2))
        expect(decodedWrapped?[2]).to(bsonEqual("hello"))

        // an array with a non-BSONValue
        let arrWithNonBSONValue: [Any?] = [1, "hi", BSONNull(), Int16(4)]
        expect(try arrWithNonBSONValue.encode(to: DocumentStorage(), forKey: "arrWithNonBSONValue"))
                .to(throwError(UserError.logicError(message: "")))

        // binary
        let binary = try Binary(base64: "//8=", subtype: .generic)

        expect(
            try decoder.decode(AnyBSONValue.self,
                               from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}").value as? Binary
        ).to(equal(binary))

        let wrappedBinary: Document = ["x": binary]
        expect(try encoder.encode(AnyBSONStruct(binary))).to(equal(wrappedBinary))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedBinary).x.value).to(bsonEqual(binary))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedBinary.canonicalExtendedJSON).x.value).to(bsonEqual(binary))

        // objectid
        let oid = ObjectId()

        expect(try decoder.decode(AnyBSONValue.self,
                                  from: "{\"$oid\": \"\(oid.oid)\"}").value).to(bsonEqual(oid))

        let wrappedOid: Document = ["x": oid]
        expect(try encoder.encode(AnyBSONStruct(oid))).to(equal(wrappedOid))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedOid).x.value).to(bsonEqual(oid))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedOid.canonicalExtendedJSON).x.value).to(bsonEqual(oid))

        // bool
        let bool = true

        expect(try decoder.decode(AnyBSONValue.self, from: "true").value).to(bsonEqual(bool))

        let wrappedBool: Document = ["x": bool]
        expect(try encoder.encode(AnyBSONStruct(bool))).to(equal(wrappedBool))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedBool).x.value).to(bsonEqual(bool))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedBool.canonicalExtendedJSON).x.value).to(bsonEqual(bool))

        // date
        let date = Date(timeIntervalSince1970: 5000)

        expect(
            try decoder.decode(AnyBSONValue.self,
                               from: "{ \"$date\" : { \"$numberLong\" : \"5000000\" } }").value as? Date
        ).to(equal(date))

        let wrappedDate: Document = ["x": date]
        expect(try encoder.encode(AnyBSONStruct(date))).to(equal(wrappedDate))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDate).x.value).to(bsonEqual(date))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedDate.canonicalExtendedJSON).x.value).to(bsonEqual(date))

        let dateEncoder = BSONEncoder()
        dateEncoder.dateEncodingStrategy = .millisecondsSince1970
        expect(try dateEncoder.encode(AnyBSONStruct(date))).to(bsonEqual(["x": date.msSinceEpoch] as Document))

        let dateDecoder = BSONDecoder()
        dateDecoder.dateDecodingStrategy = .millisecondsSince1970
        expect(try dateDecoder.decode(AnyBSONStruct.self, from: wrappedDate))
                .to(throwError(CodecTests.typeMismatchErr))

        // regex
        let regex = RegularExpression(pattern: "abc", options: "imx")

        expect(try decoder.decode(AnyBSONValue.self,
                                  from: "{ \"$regularExpression\" : { \"pattern\" : \"abc\", \"options\" : \"imx\" } }")
            .value).to(bsonEqual(regex))

        let wrappedRegex: Document = ["x": regex]
        expect(try encoder.encode(AnyBSONStruct(regex))).to(equal(wrappedRegex))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedRegex).x.value).to(bsonEqual(regex))
        expect(
            try decoder.decode(AnyBSONStruct.self,
                               from: wrappedRegex.canonicalExtendedJSON).x.value as? RegularExpression
        ).to(equal(regex))

        // codewithscope
        let code = CodeWithScope(code: "console.log(x);", scope: ["x": 1])

        expect(
            try decoder.decode(AnyBSONValue.self,
                               from: "{ \"$code\" : \"console.log(x);\", "
                                     + "\"$scope\" : { \"x\" : { \"$numberInt\" : \"1\" } } }").value as? CodeWithScope
        ).to(equal(code))

        let wrappedCode: Document = ["x": code]
        expect(try encoder.encode(AnyBSONStruct(code))).to(equal(wrappedCode))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedCode).x.value).to(bsonEqual(code))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedCode.canonicalExtendedJSON).x.value).to(bsonEqual(code))

        // int32
        let int32 = Int32(5)

        expect(try decoder.decode(AnyBSONValue.self, from: "{ \"$numberInt\" : \"5\" }").value).to(bsonEqual(5))

        let wrappedInt32: Document = ["x": int32]
        expect(try encoder.encode(AnyBSONStruct(int32))).to(equal(wrappedInt32))
        // as int because we convert Int32 -> Int when decoding
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt32).x.value).to(bsonEqual(5))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedInt32.canonicalExtendedJSON).x.value).to(bsonEqual(5))

        // int
        let int = 5

        expect(try decoder.decode(AnyBSONValue.self, from: "{ \"$numberInt\" : \"5\" }").value).to(bsonEqual(int))

        let wrappedInt: Document = ["x": int]
        expect(try encoder.encode(AnyBSONStruct(int))).to(equal(wrappedInt))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt).x.value).to(bsonEqual(int))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedInt.canonicalExtendedJSON).x.value).to(bsonEqual(int))

        // int64
        let int64 = Int64(5)

        expect(
            try decoder.decode(AnyBSONValue.self, from: "{ \"$numberLong\" : \"5\" }").value as? Int64
        ).to(equal(int64))

        let wrappedInt64: Document = ["x": int64]
        expect(try encoder.encode(AnyBSONStruct(Int64(5)))).to(equal(wrappedInt64))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt64).x.value).to(bsonEqual(int64))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedInt64.canonicalExtendedJSON).x.value).to(bsonEqual(int64))

        // decimal128
        let decimal = Decimal128("1.2E+10")

        expect(
            try decoder.decode(AnyBSONValue.self, from: "{ \"$numberDecimal\" : \"1.2E+10\" }").value as? Decimal128
        ).to(equal(decimal))

        let wrappedDecimal: Document = ["x": decimal]
        expect(try encoder.encode(AnyBSONStruct(decimal))).to(equal(wrappedDecimal))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDecimal).x.value).to(bsonEqual(decimal))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedDecimal.canonicalExtendedJSON).x.value).to(bsonEqual(decimal))

        // maxkey
        let maxKey = MaxKey()

        expect(try decoder.decode(AnyBSONValue.self, from: "{ \"$maxKey\" : 1 }").value).to(bsonEqual(maxKey))

        let wrappedMaxKey: Document = ["x": maxKey]
        expect(try encoder.encode(AnyBSONStruct(maxKey))).to(equal(wrappedMaxKey))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedMaxKey).x.value).to(bsonEqual(maxKey))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedMaxKey.canonicalExtendedJSON).x.value).to(bsonEqual(maxKey))

        // minkey
        let minKey = MinKey()

        expect(try decoder.decode(AnyBSONValue.self, from: "{ \"$minKey\" : 1 }").value).to(bsonEqual(minKey))

        let wrappedMinKey: Document = ["x": minKey]
        expect(try encoder.encode(AnyBSONStruct(minKey))).to(equal(wrappedMinKey))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedMinKey).x.value).to(bsonEqual(minKey))
        expect(try decoder.decode(AnyBSONStruct.self,
                                  from: wrappedMinKey.canonicalExtendedJSON).x.value).to(bsonEqual(minKey))

        // BSONNull
        expect(
            try decoder.decode(AnyBSONStruct.self, from: ["x": BSONNull()]).x
        ).to(equal(AnyBSONValue(BSONNull())))

        expect(try encoder.encode(AnyBSONStruct(BSONNull()))).to(equal(["x": BSONNull()]))
    }

    fileprivate struct IncorrectTopLevelEncode: Encodable {
        let x: AnyBSONValue

        // An empty encode here is incorrect.
        func encode(to encoder: Encoder) throws {}

        init(_ x: BSONValue) {
            self.x = AnyBSONValue(x)
        }
    }

    fileprivate struct CorrectTopLevelEncode: Encodable {
        let x: IncorrectTopLevelEncode

        enum CodingKeys: CodingKey {
            case x
        }

        // An empty encode here is incorrect.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(x, forKey: .x)
        }

        init(_ x: BSONValue) {
            self.x = IncorrectTopLevelEncode(x)
        }
    }

    func testIncorrectEncodeFunction() {
        let encoder = BSONEncoder()

        // A top-level `encode()` problem should throw an error, but any such issues deeper in the recursion should not.
        // These tests are to ensure that we handle incorrect encode() implementations in the same way as JSONEncoder.
        expect(try encoder.encode(IncorrectTopLevelEncode(BSONNull()))).to(throwError(CodecTests.invalidValueErr))
        expect(try encoder.encode(CorrectTopLevelEncode(BSONNull()))).to(equal(["x": Document()]))
    }

    // test encoding options structs that have non-standard CodingKeys
    func testOptionsEncoding() throws {
        let encoder = BSONEncoder()

        let rc = ReadConcern(.majority)
        let wc = try WriteConcern(wtimeoutMS: 123)
        let rp = ReadPreference(.primary)

        let agg = AggregateOptions(
                allowDiskUse: true,
                batchSize: 5,
                bypassDocumentValidation: false,
                collation: Document(),
                comment: "hello",
                hint: .indexName("hint"),
                maxTimeMS: 12,
                readConcern: rc,
                readPreference: rp,
                writeConcern: wc)

        expect(try encoder.encode(agg).keys.sorted()).to(equal([
            "allowDiskUse",
            "batchSize",
            "bypassDocumentValidation",
            "collation",
            "comment",
            "hint",
            "maxTimeMS",
            "readConcern",
            "writeConcern"
        ]))

        let count = CountOptions(
                collation: Document(),
                hint: .indexName("hint"),
                limit: 123,
                maxTimeMS: 12,
                readConcern: rc,
                readPreference: rp,
                skip: 123
        )
        expect(try encoder.encode(count).keys.sorted()).to(equal([
            "collation",
            "hint",
            "limit",
            "maxTimeMS",
            "readConcern",
            "skip"
        ]))

        let distinct = DistinctOptions(
                collation: Document(),
                maxTimeMS: 123,
                readConcern: rc,
                readPreference: rp
        )
        expect(try encoder.encode(distinct).keys.sorted()).to(equal([
            "collation",
            "maxTimeMS",
            "readConcern"
        ].sorted()))

        let find = FindOptions(
                allowPartialResults: false,
                batchSize: 123,
                collation: Document(),
                comment: "asdf",
                cursorType: .tailable,
                hint: .indexName("sdf"),
                limit: 123,
                max: Document(),
                maxAwaitTimeMS: 123,
                maxScan: 23,
                maxTimeMS: 123,
                min: Document(),
                noCursorTimeout: true,
                projection: Document(),
                readConcern: rc,
                readPreference: rp,
                returnKey: true,
                showRecordId: false,
                skip: 45,
                sort: Document())
        expect(try encoder.encode(find).keys.sorted()).to(equal([
            "allowPartialResults",
            "awaitData",
            "batchSize",
            "collation",
            "comment",
            "hint",
            "limit",
            "max",
            "maxAwaitTimeMS",
            "maxScan",
            "maxTimeMS",
            "min",
            "noCursorTimeout",
            "projection",
            "readConcern",
            "returnKey",
            "showRecordId",
            "skip",
            "sort",
            "tailable"
        ]))

        let index = IndexOptions(
                background: false,
                expireAfter: 123,
                name: "sadf",
                sparse: false,
                storageEngine: "sdaf",
                unique: true,
                version: 123,
                defaultLanguage: "english",
                languageOverride: "asdf",
                textVersion: 123,
                weights: Document(),
                sphereVersion: 959,
                bits: 32,
                max: 5.5,
                min: 4.4,
                bucketSize: 333,
                partialFilterExpression: Document(),
                collation: Document())
        expect(try encoder.encode(index).keys.sorted()).to(equal([
            "background",
            "expireAfter",
            "sparse",
            "storageEngine",
            "unique",
            "version",
            "defaultLanguage",
            "languageOverride",
            "textVersion",
            "weights",
            "sphereVersion",
            "bits",
            "max",
            "min",
            "bucketSize",
            "partialFilterExpression",
            "collation"
        ].sorted()))

        let runCommand = RunCommandOptions(
                readConcern: rc,
                readPreference: rp,
                session: ClientSession(),
                writeConcern: wc
        )

        expect(try encoder.encode(runCommand).keys.sorted()).to(equal([
            "readConcern",
            "writeConcern"
        ]))
    }
}
