@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

final class CodecTests: MongoSwiftTestCase {
    // generic decoding/encoding errors for error matching. Only the case is considered.
    static let typeMismatchErr = DecodingError._typeMismatch(at: [], expectation: Int.self, reality: 0)
    static let invalidValueErr =
        EncodingError.invalidValue(0, EncodingError.Context(codingPath: [], debugDescription: "dummy error"))
    static let dataCorruptedErr = DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: [], debugDescription: "dummy error"))

    struct TestStruct: Encodable {
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
    }

    struct NestedStruct: Codable, Equatable {
        let s1: BasicStruct
        let s2: BasicStruct
    }

    struct NestedArray: Codable, Equatable {
        let array: [BasicStruct]
    }

    struct NestedNestedStruct: Codable, Equatable {
        let s: NestedStruct
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
            "val4": ["x": 1, "y": 2],
            "val5": [["x": 1, "y": 2]]
        ]

        expect(try encoder.encode(TestStruct())).to(equal(expected))

        // a basic struct
        let basic1 = BasicStruct(int: 1, string: "hello")
        let basic1Doc: Document = ["int": 1, "string": "hello"]
        expect(try encoder.encode(basic1)).to(equal(basic1Doc))
        expect(try decoder.decode(BasicStruct.self, from: basic1Doc)).to(equal(basic1))

        // a struct storing two nested structs as properties
        let basic2 = BasicStruct(int: 2, string: "hi")
        let basic2Doc: Document = ["int": 2, "string": "hi"]

        let nestedStruct = NestedStruct(s1: basic1, s2: basic2)
        let nestedStructDoc: Document = ["s1": .document(basic1Doc), "s2": .document(basic2Doc)]
        expect(try encoder.encode(nestedStruct)).to(equal(nestedStructDoc))
        expect(try decoder.decode(NestedStruct.self, from: nestedStructDoc)).to(equal(nestedStruct))

        // a struct storing two nested structs in an array
        let nestedArray = NestedArray(array: [basic1, basic2])
        let nestedArrayDoc: Document = ["array": [.document(basic1Doc), .document(basic2Doc)]]
        expect(try encoder.encode(nestedArray)).to(equal(nestedArrayDoc))
        expect(try decoder.decode(NestedArray.self, from: nestedArrayDoc)).to(equal(nestedArray))

        // one more level of nesting
        let nestedNested = NestedNestedStruct(s: nestedStruct)
        let nestedNestedDoc: Document = ["s": .document(nestedStructDoc)]
        expect(try encoder.encode(nestedNested)).to(equal(nestedNestedDoc))
        expect(try decoder.decode(NestedNestedStruct.self, from: nestedNestedDoc)).to(equal(nestedNested))
    }

    struct OptionalsStruct: Codable, Equatable {
        let int: Int?
        let bool: Bool?
        let string: String
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
        let s2Doc2: Document = ["int": .null, "bool": true, "string": "hi"]
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

        init(
            int8: Int8? = nil,
            int16: Int16? = nil,
            uint8: UInt8? = nil,
            uint16: UInt16? = nil,
            uint32: UInt32? = nil,
            uint64: UInt64? = nil,
            uint: UInt? = nil,
            float: Float? = nil
        ) {
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

        let int32 = Int32(42)
        // all should be stored as Int32s, except the float should be stored as a double
        let doc1: Document = [
            "int8": .int32(int32), "int16": .int32(int32), "uint8": .int32(int32), "uint16": .int32(int32),
            "uint32": .int32(int32), "uint64": .int32(int32), "uint": .int32(int32), "float": 42.0
        ]

        expect(try encoder.encode(s1)).to(equal(doc1))

        // check that a UInt32 too large for an Int32 gets converted to Int64
        expect(try encoder.encode(Numbers(uint32: 4_294_967_295))).to(equal(["uint32": .int64(4_294_967_295)]))

        // check that UInt, UInt64 too large for an Int32 gets converted to Int64
        expect(try encoder.encode(Numbers(uint64: 4_294_967_295))).to(equal(["uint64": .int64(4_294_967_295)]))
        expect(try encoder.encode(Numbers(uint: 4_294_967_295))).to(equal(["uint": .int64(4_294_967_295)]))

        // check that UInt, UInt64 too large for an Int64 gets converted to Double
        expect(try encoder.encode(Numbers(uint64: UInt64(Int64.max) + 1)))
            .to(equal(["uint64": 9_223_372_036_854_775_808.0]))
        // on a 32-bit platform, Int64.max + 1 will not fit in a UInt.
        if !MongoSwiftTestCase.is32Bit {
            expect(try encoder.encode(Numbers(uint: UInt(Int64.max) + 1)))
                .to(equal(["uint": 9_223_372_036_854_775_808.0]))
        }
        // check that we fail gracefully with a UInt, UInt64 that can't fit in any type.
        expect(try encoder.encode(Numbers(uint64: UInt64.max))).to(throwError(CodecTests.invalidValueErr))
        // on a 32-bit platform, UInt.max = UInt32.max, which fits in an Int64.
        if MongoSwiftTestCase.is32Bit {
            expect(try encoder.encode(Numbers(uint: UInt.max))).to(equal(["uint": 4_294_967_295]))
        } else {
            expect(try encoder.encode(Numbers(uint: UInt.max))).to(throwError(CodecTests.invalidValueErr))
        }
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
            doc2[k] = .int64(42)
        }

        let res2 = try decoder.decode(Numbers.self, from: doc2)
        expect(res2).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        var doc3 = Document()
        for k in Numbers.keys {
            doc3[k] = .double(42)
        }

        let res3 = try decoder.decode(Numbers.self, from: doc3)
        expect(res3).to(equal(s))

        // test for each type that we fail gracefully when values cannot be represented because they are out of bounds
        expect(try decoder.decode(Numbers.self, from: ["int8": .int64(Int64(Int8.max) + 1)]))
            .to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["int16": .int64(Int64(Int16.max) + 1)]))
            .to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint8": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint16": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint32": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint64": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["uint": -1])).to(throwError(CodecTests.typeMismatchErr))
        expect(try decoder.decode(Numbers.self, from: ["float": .double(Double.greatestFiniteMagnitude)]))
            .to(throwError(CodecTests.typeMismatchErr))
    }

    struct BSONNumbers: Codable, Equatable {
        let int: Int
        let int32: Int32
        let int64: Int64
        let double: Double
    }

    /// Test that BSON number types are encoded properly, and can be decoded from any type they are stored as
    func testBSONNumbers() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()
        // the struct we expect to get back
        let s = BSONNumbers(int: 42, int32: 42, int64: 42, double: 42)
        expect(try encoder.encode(s)).to(equal([
            "int": 42,
            "int32": .int32(42),
            "int64": .int64(42),
            "double": .double(42)
        ]))

        // store all values as Int32s and decode them to their requested types
        let doc1: Document = ["int": .int32(42), "int32": .int32(42), "int64": .int32(42), "double": .int32(42)]
        expect(try decoder.decode(BSONNumbers.self, from: doc1)).to(equal(s))

        // store all values as Int64s and decode them to their requested types
        let doc2: Document = ["int": .int64(42), "int32": .int64(42), "int64": .int64(42), "double": .int64(42)]
        expect(try decoder.decode(BSONNumbers.self, from: doc2)).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        let doc3: Document = ["int": 42.0, "int32": 42.0, "int64": 42.0, "double": 42.0]
        expect(try decoder.decode(BSONNumbers.self, from: doc3)).to(equal(s))
    }

    struct AllBSONTypes: Codable, Equatable {
        let double: Double
        let string: String
        let doc: Document
        let arr: [BSON]
        let binary: Binary
        let oid: ObjectId
        let bool: Bool
        let date: Date
        let code: Code
        let codeWithScope: CodeWithScope
        let ts: Timestamp
        let int32: Int32
        let int64: Int64
        let dec: Decimal128
        let minkey: MinKey
        let maxkey: MaxKey
        let regex: RegularExpression
        let symbol: Symbol
        let undefined: BSONUndefined
        let dbpointer: DBPointer
        let null: BSONNull

        public static func factory() throws -> AllBSONTypes {
            AllBSONTypes(
                double: Double(2),
                string: "hi",
                doc: ["x": 1],
                arr: [.int32(1), .int32(2)],
                binary: try Binary(base64: "//8=", subtype: .generic),
                oid: ObjectId("507f1f77bcf86cd799439011")!,
                bool: true,
                date: Date(timeIntervalSinceReferenceDate: 5000),
                code: Code(code: "hi"),
                codeWithScope: CodeWithScope(code: "hi", scope: ["x": .int64(1)]),
                ts: Timestamp(timestamp: 1, inc: 2),
                int32: 5,
                int64: 6,
                dec: Decimal128("1.2E+10")!,
                minkey: MinKey(),
                maxkey: MaxKey(),
                regex: RegularExpression(pattern: "^abc", options: "imx"),
                symbol: Symbol("i am a symbol"),
                undefined: BSONUndefined(),
                dbpointer: DBPointer(ref: "some.namespace", id: ObjectId("507f1f77bcf86cd799439011")!),
                null: BSONNull()
            )
        }

        // Manually construct a document from this instance for comparision with encoder output.
        public func toDocument() -> Document {
            [
                "double": .double(self.double),
                "string": .string(self.string),
                "doc": .document(self.doc),
                "arr": .array(self.arr),
                "binary": .binary(self.binary),
                "oid": .objectId(self.oid),
                "bool": .bool(self.bool),
                "date": .datetime(self.date),
                "code": .code(self.code),
                "codeWithScope": .codeWithScope(self.codeWithScope),
                "ts": .timestamp(self.ts),
                "int32": .int32(self.int32),
                "int64": .int64(self.int64),
                "dec": .decimal128(self.dec),
                "minkey": .minKey,
                "maxkey": .maxKey,
                "regex": .regex(self.regex),
                "symbol": .symbol(self.symbol),
                "undefined": .undefined,
                "dbpointer": .dbPointer(self.dbpointer),
                "null": .null
            ]
        }
    }

    /// Test decoding/encoding to all possible BSON types
    func testBSONValues() throws {
        let expected = try AllBSONTypes.factory()

        let decoder = BSONDecoder()

        let doc = expected.toDocument()

        let res = try decoder.decode(AllBSONTypes.self, from: doc)
        expect(res).to(equal(expected))

        expect(try BSONEncoder().encode(expected)).to(equal(doc))

        // swiftlint:disable line_length
        let base64 = "//8="
        let extjson = """
        {
            "double" : 2.0,
            "string" : "hi",
            "doc" : { "x" : { "$numberLong": "1" } },
            "arr" : [ 1, 2 ],
            "binary" : { "$binary" : { "base64": "\(base64)", "subType" : "00" } },
            "oid" : { "$oid" : "507f1f77bcf86cd799439011" },
            "bool" : true,
            "date" : { "$date" : "2001-01-01T01:23:20Z" },
            "code" : { "$code" : "hi" },
            "codeWithScope" : { "$code" : "hi", "$scope" : { "x" : { "$numberLong": "1" } } },
            "int" : 1,
            "ts" : { "$timestamp" : { "t" : 1, "i" : 2 } },
            "int32" : 5,
            "int64" : 6,
            "dec" : { "$numberDecimal" : "1.2E+10" },
            "minkey" : { "$minKey" : 1 },
            "maxkey" : { "$maxKey" : 1 },
            "regex" : { "$regularExpression" : { "pattern" : "^abc", "options" : "imx" } },
            "symbol" : { "$symbol" : "i am a symbol" },
            "undefined": { "$undefined" : true },
            "dbpointer": { "$dbPointer" : { "$ref" : "some.namespace", "$id" : { "$oid" : "507f1f77bcf86cd799439011" } } },
            "null": null
        }
        """
        // swiftlint:enable line_length

        let res2 = try decoder.decode(AllBSONTypes.self, from: extjson)
        expect(res2).to(equal(expected))
    }

    /// Test decoding extJSON and JSON for standalone values
    func testDecodeScalars() throws {
        let decoder = BSONDecoder()

        expect(try decoder.decode(Int32.self, from: "42")).to(equal(Int32(42)))
        expect(try decoder.decode(Int32.self, from: "{\"$numberInt\": \"42\"}")).to(equal(Int32(42)))

        let oid = ObjectId("507f1f77bcf86cd799439011")!
        expect(try decoder.decode(ObjectId.self, from: "{\"$oid\": \"507f1f77bcf86cd799439011\"}")).to(equal(oid))

        expect(try decoder.decode(String.self, from: "\"somestring\"")).to(equal("somestring"))

        expect(try decoder.decode(Int64.self, from: "42")).to(equal(Int64(42)))
        expect(try decoder.decode(Int64.self, from: "{\"$numberLong\": \"42\"}")).to(equal(Int64(42)))

        expect(try decoder.decode(Double.self, from: "42.42")).to(equal(42.42))
        expect(try decoder.decode(Double.self, from: "{\"$numberDouble\": \"42.42\"}")).to(equal(42.42))

        expect(try decoder.decode(
            Decimal128.self,
            from: "{\"$numberDecimal\": \"1.2E+10\"}"
        )).to(equal(Decimal128("1.2E+10")!))

        let binary = try Binary(base64: "//8=", subtype: .generic)
        expect(
            try decoder.decode(
                Binary.self,
                from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}"
            )
        ).to(equal(binary))

        expect(try decoder.decode(
            Code.self,
            from: "{\"$code\": \"hi\" }"
        )).to(equal(Code(code: "hi")))
        let code = Code(code: "hi")
        expect(try decoder.decode(
            Code.self,
            from: "{\"$code\": \"hi\", \"$scope\": {\"x\" : { \"$numberLong\": \"1\" }} }"
        )
        ).to(throwError())
        expect(try decoder.decode(Code.self, from: "{\"$code\": \"hi\" }")).to(equal(code))

        expect(try decoder.decode(
            CodeWithScope.self,
            from: "{\"$code\": \"hi\" }"
        )).to(throwError())
        let cws = CodeWithScope(code: "hi", scope: ["x": 1])
        expect(try decoder.decode(
            CodeWithScope.self,
            from: "{\"$code\": \"hi\", \"$scope\": {\"x\" : { \"$numberLong\": \"1\" }} }"
        )
        ).to(equal(cws))
        expect(try decoder.decode(Document.self, from: "{\"x\": 1}")).to(equal(["x": .int32(1)]))

        let ts = Timestamp(timestamp: 1, inc: 2)
        expect(try decoder.decode(Timestamp.self, from: "{ \"$timestamp\" : { \"t\" : 1, \"i\" : 2 } }")).to(equal(ts))

        let regex = RegularExpression(pattern: "^abc", options: "imx")
        expect(
            try decoder.decode(
                RegularExpression.self,
                from: "{ \"$regularExpression\" : { \"pattern\" :\"^abc\", \"options\" : \"imx\" } }"
            )
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
        // We presently have no way to control the order of emitted JSON in `cleanEqual`, so this
        // test will no longer run deterministically on both OSX and Linux in Swift 5.0+. Instead
        // of doing this, one can (and should) just initialize a Document with the `init(fromJSON:)`
        // constructor, and convert to JSON using the .extendedJSON property. This test is just
        // to demonstrate that a Document can theoretically work with any encoder/decoder.
        // let encoder = JSONEncoder()
        // let decoder = JSONDecoder()

        // let json = """
        // {
        //     "name": "Durian",
        //     "points": 600,
        //     "pointsDouble": 600.5,
        //     "description": "A fruit with a distinctive scent.",
        //     "array": ["a", "b", "c"],
        //     "doc": { "x" : 2.0 }
        // }
        // """

        // let expected: Document = [
        //     "name": "Durian",
        //     "points": 600,
        //     "pointsDouble": 600.5,
        //     "description": "A fruit with a distinctive scent.",
        //     "array": ["a", "b", "c"],
        //     "doc": ["x": 2] as Document
        // ]

        // let decoded = try decoder.decode(Document.self, from: json.data(using: .utf8)!)
        // expect(decoded).to(sortedEqual(expected))

        // let encoded = try String(data: encoder.encode(expected), encoding: .utf8)
        // expect(encoded).to(cleanEqual(json))
    }

    func testEncodeArray() throws {
        let encoder = BSONEncoder()

        let values1 = [BasicStruct(int: 1, string: "hello"), BasicStruct(int: 2, string: "hi")]
        expect(try encoder.encode(values1)).to(equal([["int": 1, "string": "hello"], ["int": 2, "string": "hi"]]))

        let values2 = [BasicStruct(int: 1, string: "hello"), nil]
        expect(try encoder.encode(values2)).to(equal([["int": 1, "string": "hello"], nil]))
    }

    struct AnyBSONStruct: Codable, Equatable {
        let x: BSON

        init(_ x: BSON) {
            self.x = x
        }
    }

    // test encoding/decoding BSONs with BSONEncoder and Decoder
    func testBSONIsBSONCodable() throws {
        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        // standalone document
        let doc: Document = ["y": 1]
        let bsonDoc = BSON.document(doc)
        expect(try encoder.encode(bsonDoc)).to(equal(doc))
        expect(try decoder.decode(BSON.self, from: doc)).to(equal(bsonDoc))
        expect(try decoder.decode(BSON.self, from: doc.canonicalExtendedJSON)).to(equal(bsonDoc))
        // doc wrapped in a struct

        let wrappedDoc: Document = ["x": bsonDoc]
        expect(try encoder.encode(AnyBSONStruct(bsonDoc))).to(equal(wrappedDoc))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDoc).x).to(equal(bsonDoc))
        expect(try decoder.decode(
            AnyBSONStruct.self,
            from: wrappedDoc.canonicalExtendedJSON
        ).x).to(equal(bsonDoc))

        // values wrapped in an `AnyBSONStruct`
        let double: BSON = 42.0
        expect(try decoder.decode(BSON.self, from: "{\"$numberDouble\": \"42\"}")).to(equal(double))

        let wrappedDouble: Document = ["x": double]
        expect(try encoder.encode(AnyBSONStruct(double))).to(equal(wrappedDouble))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDouble).x).to(equal(double))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDouble.canonicalExtendedJSON).x).to(equal(double))

        // string
        let string: BSON = "hi"
        expect(try decoder.decode(BSON.self, from: "\"hi\"")).to(equal(string))

        let wrappedString: Document = ["x": string]
        expect(try encoder.encode(AnyBSONStruct(string))).to(equal(wrappedString))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedString).x).to(equal(string))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedString.canonicalExtendedJSON).x).to(equal(string))

        // array
        let array: BSON = [1, 2, "hello"]

        let decodedArray = try decoder.decode(
            BSON.self,
            from: "[{\"$numberLong\": \"1\"}, {\"$numberLong\": \"2\"}, \"hello\"]"
        ).arrayValue
        expect(decodedArray).toNot(beNil())
        expect(decodedArray?[0]).to(equal(1))
        expect(decodedArray?[1]).to(equal(2))
        expect(decodedArray?[2]).to(equal("hello"))

        let wrappedArray: Document = ["x": array]
        expect(try encoder.encode(AnyBSONStruct(array))).to(equal(wrappedArray))
        let decodedWrapped = try decoder.decode(AnyBSONStruct.self, from: wrappedArray).x.arrayValue
        expect(decodedWrapped?[0]).to(equal(1))
        expect(decodedWrapped?[1]).to(equal(2))
        expect(decodedWrapped?[2]).to(equal("hello"))

        // binary
        let binary = BSON.binary(try Binary(base64: "//8=", subtype: .generic))

        expect(
            try decoder.decode(
                BSON.self,
                from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}"
            )
        ).to(equal(binary))

        let wrappedBinary: Document = ["x": binary]
        expect(try encoder.encode(AnyBSONStruct(binary))).to(equal(wrappedBinary))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedBinary).x).to(equal(binary))
        expect(try decoder.decode(
            AnyBSONStruct.self,
            from: wrappedBinary.canonicalExtendedJSON
        ).x).to(equal(binary))

        // objectid
        let oid = ObjectId()
        let bsonOid = BSON.objectId(oid)

        expect(try decoder.decode(BSON.self, from: "{\"$oid\": \"\(oid.hex)\"}")).to(equal(bsonOid))

        let wrappedOid: Document = ["x": bsonOid]
        expect(try encoder.encode(AnyBSONStruct(bsonOid))).to(equal(wrappedOid))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedOid).x).to(equal(bsonOid))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedOid.canonicalExtendedJSON).x).to(equal(bsonOid))

        // bool
        let bool: BSON = true

        expect(try decoder.decode(BSON.self, from: "true")).to(equal(bool))

        let wrappedBool: Document = ["x": bool]
        expect(try encoder.encode(AnyBSONStruct(bool))).to(equal(wrappedBool))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedBool).x).to(equal(bool))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedBool.canonicalExtendedJSON).x).to(equal(bool))

        // date
        let date = BSON.datetime(Date(timeIntervalSince1970: 5000))

        expect(try decoder.decode(BSON.self, from: "{ \"$date\" : { \"$numberLong\" : \"5000000\" } }")).to(equal(date))

        let wrappedDate: Document = ["x": date]
        expect(try encoder.encode(AnyBSONStruct(date))).to(equal(wrappedDate))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDate).x).to(equal(date))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDate.canonicalExtendedJSON).x).to(equal(date))

        let dateEncoder = BSONEncoder()
        dateEncoder.dateEncodingStrategy = .millisecondsSince1970
        expect(try dateEncoder.encode(AnyBSONStruct(date))).to(equal(["x": 5_000_000]))

        let dateDecoder = BSONDecoder()
        dateDecoder.dateDecodingStrategy = .millisecondsSince1970
        expect(try dateDecoder.decode(AnyBSONStruct.self, from: wrappedDate)).to(throwError(CodecTests.typeMismatchErr))

        // regex
        let regex = BSON.regex(RegularExpression(pattern: "abc", options: "imx"))

        expect(try decoder.decode(
            BSON.self,
            from: "{ \"$regularExpression\" : { \"pattern\" : \"abc\", \"options\" : \"imx\" } }"
        )
        ).to(equal(regex))

        let wrappedRegex: Document = ["x": regex]
        expect(try encoder.encode(AnyBSONStruct(regex))).to(equal(wrappedRegex))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedRegex).x).to(equal(regex))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedRegex.canonicalExtendedJSON).x).to(equal(regex))

        // codewithscope
        let code = BSON.codeWithScope(CodeWithScope(code: "console.log(x);", scope: ["x": 1]))

        expect(
            try decoder.decode(
                BSON.self,
                from: "{ \"$code\" : \"console.log(x);\", "
                    + "\"$scope\" : { \"x\" : { \"$numberLong\" : \"1\" } } }"
            )
        ).to(equal(code))

        let wrappedCode: Document = ["x": code]
        expect(try encoder.encode(AnyBSONStruct(code))).to(equal(wrappedCode))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedCode).x).to(equal(code))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedCode.canonicalExtendedJSON).x).to(equal(code))

        // int32
        let int32 = BSON.int32(5)

        expect(try decoder.decode(BSON.self, from: "{ \"$numberInt\" : \"5\" }")).to(equal(int32))

        let wrappedInt32: Document = ["x": int32]
        expect(try encoder.encode(AnyBSONStruct(int32))).to(equal(wrappedInt32))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt32).x).to(equal(int32))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt32.canonicalExtendedJSON).x).to(equal(int32)
        )

        // int
        let int: BSON = 5

        expect(try decoder.decode(BSON.self, from: "{ \"$numberLong\" : \"5\" }")).to(equal(int))

        let wrappedInt: Document = ["x": int]
        expect(try encoder.encode(AnyBSONStruct(int))).to(equal(wrappedInt))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt).x).to(equal(int))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt.canonicalExtendedJSON).x).to(equal(int))

        // int64
        let int64 = BSON.int64(5)

        expect(try decoder.decode(BSON.self, from: "{\"$numberLong\":\"5\"}")).to(equal(int64))

        let wrappedInt64: Document = ["x": int64]
        expect(try encoder.encode(AnyBSONStruct(int64))).to(equal(wrappedInt64))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt64).x).to(equal(int64))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedInt64.canonicalExtendedJSON).x).to(equal(int64))

        // decimal128
        let decimal = BSON.decimal128(Decimal128("1.2E+10")!)

        expect(try decoder.decode(BSON.self, from: "{ \"$numberDecimal\" : \"1.2E+10\" }")).to(equal(decimal))

        let wrappedDecimal: Document = ["x": decimal]
        expect(try encoder.encode(AnyBSONStruct(decimal))).to(equal(wrappedDecimal))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDecimal).x).to(equal(decimal))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedDecimal.canonicalExtendedJSON).x).to(equal(decimal))

        // maxkey
        let maxKey = BSON.maxKey

        expect(try decoder.decode(BSON.self, from: "{ \"$maxKey\" : 1 }")).to(equal(maxKey))

        let wrappedMaxKey: Document = ["x": maxKey]
        expect(try encoder.encode(AnyBSONStruct(maxKey))).to(equal(wrappedMaxKey))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedMaxKey).x).to(equal(maxKey))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedMaxKey.canonicalExtendedJSON).x).to(equal(maxKey))

        // minkey
        let minKey = BSON.minKey

        expect(try decoder.decode(BSON.self, from: "{ \"$minKey\" : 1 }")).to(equal(minKey))

        let wrappedMinKey: Document = ["x": minKey]
        expect(try encoder.encode(AnyBSONStruct(minKey))).to(equal(wrappedMinKey))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedMinKey).x).to(equal(minKey))
        expect(try decoder.decode(AnyBSONStruct.self, from: wrappedMinKey.canonicalExtendedJSON).x).to(equal(minKey))

        // BSONNull
        expect(try decoder.decode(AnyBSONStruct.self, from: ["x": .null]).x).to(equal(BSON.null))
        expect(try encoder.encode(AnyBSONStruct(.null))).to(equal(["x": .null]))
    }

    fileprivate struct IncorrectTopLevelEncode: Encodable {
        let x: BSON

        // An empty encode here is incorrect.
        func encode(to _: Encoder) throws {}

        init(_ x: BSON) {
            self.x = x
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
            try container.encode(self.x, forKey: .x)
        }

        init(_ x: BSON) {
            self.x = IncorrectTopLevelEncode(x)
        }
    }

    func testIncorrectEncodeFunction() {
        let encoder = BSONEncoder()

        // A top-level `encode()` problem should throw an error, but any such issues deeper in the recursion should not.
        // These tests are to ensure that we handle incorrect encode() implementations in the same way as JSONEncoder.
        expect(try encoder.encode(IncorrectTopLevelEncode(.null))).to(throwError(CodecTests.invalidValueErr))
        expect(try encoder.encode(CorrectTopLevelEncode(.null))).to(equal(["x": [:]]))
    }

    // test encoding options structs that have non-standard CodingKeys
    func testOptionsEncoding() throws {
        let encoder = BSONEncoder()

        let rc = ReadConcern(.majority)
        let wc = try WriteConcern(wtimeoutMS: 123)
        let rp = ReadPreference.primary

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
            writeConcern: wc
        )

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

        let count = CountDocumentsOptions(
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
            maxTimeMS: 123,
            min: Document(),
            noCursorTimeout: true,
            projection: Document(),
            readConcern: rc,
            readPreference: rp,
            returnKey: true,
            showRecordId: false,
            skip: 45,
            sort: Document()
        )
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
            bits: 32,
            bucketSize: 333,
            collation: Document(),
            defaultLanguage: "english",
            expireAfterSeconds: 123,
            languageOverride: "asdf",
            max: 5.5,
            min: 4.4,
            name: "sadf",
            partialFilterExpression: Document(),
            sparse: false,
            sphereIndexVersion: 959,
            storageEngine: ["a": 1],
            textIndexVersion: 123,
            unique: true,
            version: 123,
            weights: Document()
        )
        expect(try encoder.encode(index).keys.sorted()).to(equal([
            "background",
            "bits",
            "bucketSize",
            "collation",
            "default_language",
            "expireAfterSeconds",
            "language_override",
            "max",
            "min",
            "name",
            "partialFilterExpression",
            "sparse",
            "2dsphereIndexVersion",
            "storageEngine",
            "textIndexVersion",
            "unique",
            "v",
            "weights"
        ].sorted()))

        let runCommand = RunCommandOptions(
            readConcern: rc,
            readPreference: rp,
            writeConcern: wc
        )

        expect(try encoder.encode(runCommand).keys.sorted()).to(equal([
            "readConcern",
            "writeConcern"
        ]))
    }
}
