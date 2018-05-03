@testable import MongoSwift
import Nimble
import XCTest

struct TestClass: BsonEncodable {
    let val1 = "a"
    let val2 = 0
    let val3 = [1, 2, [3, 4]] as [Any]
    let val4 = TestClass2()
    let val5 = [3, TestClass2()] as [Any]
}

struct TestClass2: BsonEncodable {
    let x = 1
    let y = 2
}

final class CodecTests: XCTestCase {
    static var allTests: [(String, (CodecTests) -> () throws -> Void)] {
        return [
            ("testEncodeStructs", testEncodeStructs),
            ("testEncodeListDatabasesOptions", testEncodeListDatabasesOptions),
            ("testNilEncodingStrategy", testNilEncodingStrategy)
        ]
    }

    func testEncodeStructs() throws {

        let expected: Document = [
            "val2": 0,
            "val3": [1, 2, [3, 4] as Document] as Document,
            "val5": [3, ["y": 2, "x": 1] as Document] as Document,
            "val4": ["y": 2, "x": 1] as Document,
            "val1": "a"
        ]

        expect(try BsonEncoder().encode(TestClass())).to(equal(expected))
    }

    func testEncodeListDatabasesOptions() throws {
        let options = ListDatabasesOptions(filter: Document(["a": 10]), nameOnly: true, session: ClientSession())
        let expected: Document = ["session": Document(), "filter": ["a": 10] as Document, "nameOnly": true]
        expect(try BsonEncoder().encode(options)).to(equal(expected))
    }

    func testNilEncodingStrategy() throws {
        let encoderNoNils = BsonEncoder()
        let encoderWithNils = BsonEncoder(nilStrategy: .include)
        let emptyOptions = ListDatabasesOptions(filter: nil, nameOnly: nil, session: nil)

        // Even if the object exists, don't bother encoding it if its properties are all nil
        expect(try encoderNoNils.encode(emptyOptions)).to(beNil())

        expect(try encoderWithNils.encode(emptyOptions))
        .to(equal(["session": nil, "filter": nil, "nameOnly": nil] as Document))

        let options = ListDatabasesOptions(filter: nil, nameOnly: true, session: nil)
        expect(try encoderNoNils.encode(options)).to(equal(["nameOnly": true]))
        expect(try encoderWithNils.encode(options))
        .to(equal(["session": nil, "filter": nil, "nameOnly": true]))
    }

    struct BasicStruct: Decodable, Equatable {
        let int: Int
        let string: String

        public static func == (lhs: BasicStruct, rhs: BasicStruct) -> Bool {
            return lhs.int == rhs.int && lhs.string == rhs.string
        }
    }

    struct NestedStruct: Decodable, Equatable {
        let s1: BasicStruct
        let s2: BasicStruct

        public static func == (lhs: NestedStruct, rhs: NestedStruct) -> Bool {
            return lhs.s1 == rhs.s1 && lhs.s2 == rhs.s2
        }
    }

    struct NestedArray: Decodable, Equatable {
        let array: [BasicStruct]

        public static func == (lhs: NestedArray, rhs: NestedArray) -> Bool {
            return lhs.array == rhs.array
        }
    }

    struct NestedNestedStruct: Decodable, Equatable {
        let s: NestedStruct

        public static func == (lhs: NestedNestedStruct, rhs: NestedNestedStruct) -> Bool {
            return lhs.s == rhs.s
        }
    }

    /// Test decoding a variety of structs containing simple types that have 
    /// built in Codable support (strings, arrays, ints, and structs composed of them.)
    func testDecodingStructs() throws {
        let decoder = BsonDecoder()

        // decode a document to a basic struct
        let basic1 = BasicStruct(int: 1, string: "hello")
        let basic1Doc: Document = ["int": 1, "string": "hello"]
        let res1 = try decoder.decode(BasicStruct.self, from: basic1Doc)
        expect(res1).to(equal(basic1))

        // decode a document to a struct storing two nested structs as properties
        let basic2 = BasicStruct(int: 2, string: "hi")
        let basic2Doc: Document = ["int": 2, "string": "hi"]

        let nestedStruct = NestedStruct(s1: basic1, s2: basic2)
        let nestedStructDoc: Document = ["s1": basic1Doc, "s2": basic2Doc]
        let res2 = try decoder.decode(NestedStruct.self, from: nestedStructDoc)
        expect(res2).to(equal(nestedStruct))

        // decode a document to a struct storing two nested structs in an array
        let nestedArray = NestedArray(array: [basic1, basic2])
        let nestedArrayDoc: Document = ["array": [basic1Doc, basic2Doc]]
        let res3 = try decoder.decode(NestedArray.self, from: nestedArrayDoc)
        expect(res3).to(equal(nestedArray))

        let nestedNested = NestedNestedStruct(s: nestedStruct)
        let nestedNestedDoc: Document = ["s": nestedStructDoc]
        let res4 = try decoder.decode(NestedNestedStruct.self, from: nestedNestedDoc)
        expect(res4).to(equal(nestedNested))
    }

    struct OptionalsStruct: Decodable, Equatable {
        let int: Int?
        let bool: Bool?
        let string: String

        public static func == (lhs: OptionalsStruct, rhs: OptionalsStruct) -> Bool {
            return lhs.int == rhs.int && lhs.bool == rhs.bool && lhs.string == rhs.string
        }
    }

    /// Test decoding a struct containing optional values. 
    func testDecodingOptionals() throws {
        let decoder = BsonDecoder()

        let s1 = OptionalsStruct(int: 1, bool: true, string: "hi")
        let s1Doc: Document = ["int": 1, "bool": true, "string": "hi"]
        let res1 = try decoder.decode(OptionalsStruct.self, from: s1Doc)
        expect(res1).to(equal(s1))

        let s2 = OptionalsStruct(int: nil, bool: true, string: "hi")
        let s2Doc1: Document = ["bool": true, "string": "hi"]
        let res2 = try decoder.decode(OptionalsStruct.self, from: s2Doc1)
        expect(res2).to(equal(s2))

        let s2Doc2: Document = ["int": nil, "bool": true, "string": "hi"]
        let res3 = try decoder.decode(OptionalsStruct.self, from: s2Doc2)
        expect(res3).to(equal(s2))
    }

    struct Numbers: Decodable, Equatable {
        let int8: Int8?
        let int16: Int16?
        let uint8: UInt8?
        let uint16: UInt16?
        let uint32: UInt32?
        let uint64: UInt64?
        let uint: UInt?
        let float: Float?

        public static func == (lhs: Numbers, rhs: Numbers) -> Bool {
            return lhs.int8 == rhs.int8 && lhs.int16 == rhs.int16 &&
                    lhs.uint8 == rhs.uint8 && lhs.uint16 == rhs.uint16 &&
                    lhs.uint32 == rhs.uint32 && lhs.uint64 == rhs.uint64 &&
                    lhs.uint == rhs.uint && lhs.float == rhs.float
        }

        init(int8: Int8? = nil, int16: Int16? = nil, uint8: UInt8? = nil, uint16: UInt16? = nil,
             uint32: UInt32? = nil, uint64: UInt64? = nil, uint: UInt? = nil, float: Float? = nil) {
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

    /// Test decoding where the requested numeric types are non-BSON
    /// and require conversions.
    func testDecodingNonBsonNumbers() throws {
        let decoder = BsonDecoder()

        // the struct we expect to get back
        let s = Numbers(int8: 42, int16: 42, uint8: 42, uint16: 42, uint32: 42, uint64: 42, uint: 42, float: 42)

        // store all values as Int32s and decode them to their requested types
        let doc1: Document = ["int8": 42, "int16": 42, "uint8": 42, "uint16": 42,
                            "uint32": 42, "uint64": 42, "uint": 42, "float": 42]
        let res1 = try decoder.decode(Numbers.self, from: doc1)
        expect(res1).to(equal(s))

        // store all values as Int64s and decode them to their requested types
        let doc2: Document = ["int8": Int64(42), "int16": Int64(42), "uint8": Int64(42), "uint16": Int64(42),
                            "uint32": Int64(42), "uint64": Int64(42), "uint": Int64(42), "float": Int64(42)]
        let res2 = try decoder.decode(Numbers.self, from: doc2)
        expect(res2).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        let doc3: Document = ["int8": Double(42), "int16": Double(42), "uint8": Double(42), "uint16": Double(42),
                            "uint32": Double(42), "uint64": Double(42), "uint": Double(42), "float": Double(42)]
        let res3 = try decoder.decode(Numbers.self, from: doc3)
        expect(res3).to(equal(s))

        // test for each type that we fail gracefully when values cannot be represented because they are out of bounds
        expect(try decoder.decode(Numbers.self, from: ["int8": Int(Int8.max) + 1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["int16": Int(Int16.max) + 1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint8": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: [ "uint16": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint32": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint64": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["float": Double.greatestFiniteMagnitude])).to(throwError())
    }

     struct BsonNumbers: Decodable, Equatable {
        let int: Int
        let int32: Int32
        let int64: Int64
        let double: Double

        public static func == (lhs: BsonNumbers, rhs: BsonNumbers) -> Bool {
            return lhs.int == rhs.int && lhs.int32 == rhs.int32 &&
                    lhs.int64 == rhs.int64 && lhs.double == rhs.double
        }
    }

    /// Test that BSON number types can be decoded from any type they are stored as
    func testDecodingBsonNumbers() throws {
        let decoder = BsonDecoder()
        // the struct we expect to get back
        let s = BsonNumbers(int: 42, int32: 42, int64: 42, double: 42)

        // store all values as Int32s and decode them to their requested types
        let doc1: Document = ["int": Int32(42), "int32": Int32(42), "int64": Int32(42), "double": Int32(42)]
        let res1 = try decoder.decode(BsonNumbers.self, from: doc1)
        expect(res1).to(equal(s))

        // store all values as Int64s and decode them to their requested types
        let doc2: Document = ["int": Int64(42), "int32": Int64(42), "int64": Int64(42), "double": Int64(42)]
        let res2 = try decoder.decode(BsonNumbers.self, from: doc2)
        expect(res2).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        let doc3: Document = ["int": Double(42), "int32": Double(42), "int64": Double(42), "double": Double(42)]
        let res3 = try decoder.decode(BsonNumbers.self, from: doc3)
        expect(res3).to(equal(s))
    }

    struct AllBsonTypes: Decodable, Equatable {
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

        public static func == (lhs: AllBsonTypes, rhs: AllBsonTypes) -> Bool {
            return lhs.double == rhs.double && lhs.string == rhs.string &&
                    lhs.doc == rhs.doc && lhs.arr == rhs.arr && lhs.binary == rhs.binary &&
                    lhs.oid == rhs.oid && lhs.bool == rhs.bool && lhs.code == rhs.code &&
                    lhs.int == rhs.int && lhs.ts == rhs.ts && lhs.int32 == rhs.int32 &&
                    lhs.int64 == rhs.int64 && lhs.dec == rhs.dec && lhs.minkey == rhs.minkey &&
                    lhs.maxkey == rhs.maxkey && lhs.regex == rhs.regex && lhs.date == rhs.date
        }
    }

    /// Test decoding to all possible BSON types
    func testDecodeBsonValues() throws {

        // decode from fully de-structured 
        let doc1: Document = [
            "double": Double(2),
            "string": "hi",
            "doc": ["x": 1] as Document,
            "arr": [1, 2],
            "binary": ["subtype": 0, "data": [255, 255]] as Document,
            "oid": ["oid": "507f1f77bcf86cd799439011"] as Document,
            "bool": true,
            "date": 5000,
            "code": ["code": "hi", "scope": ["x": 1] as Document] as Document,
            "int": 1,
            "ts": ["timestamp": 1, "increment": 2] as Document,
            "int32": 5,
            "int64": 6,
            "dec": ["data": "1.2E+10"] as Document,
            "minkey": [] as Document,
            "maxkey": [] as Document,
            "regex": ["pattern": "^abc", "options": "imx"] as Document
        ]

        let expected = AllBsonTypes(
                            double: Double(2),
                            string: "hi",
                            doc: ["x": 1],
                            arr: [1, 2],
                            binary: Binary(base64: "//8=", subtype: .binary),
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

        let decoder = BsonDecoder()
        let res1 = try decoder.decode(AllBsonTypes.self, from: doc1)
        expect(res1).to(equal(expected))

        let doc2: Document = [
            "double": Double(2),
            "string": "hi",
            "doc": ["x": 1] as Document,
            "arr": [1, 2],
            "binary": Binary(base64: "//8=", subtype: .binary),
            "oid": ObjectId(fromString: "507f1f77bcf86cd799439011"),
            "bool": true,
            "date": Date(timeIntervalSinceReferenceDate: 5000),
            "code": CodeWithScope(code: "hi", scope: ["x": 1]),
            "int": 1,
            "ts": Timestamp(timestamp: 1, inc: 2),
            "int32": 5,
            "int64": 6,
            "dec": Decimal128("1.2E+10"),
            "minkey": MinKey(),
            "maxkey": MaxKey(),
            "regex": RegularExpression(pattern: "^abc", options: "imx")
        ]

        let res2 = try decoder.decode(AllBsonTypes.self, from: doc2)
        expect(res2).to(equal(expected))

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

        let res3 = try decoder.decode(AllBsonTypes.self, from: extjson)
        expect(res3).to(equal(expected))
    }

    /// Test decoding extJSON and JSON for standalone values
    func testDecodeScalars() throws {
        let decoder = BsonDecoder()

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

        let binary = Binary(base64: "//8=", subtype: .binary)
        expect(try decoder.decode(Binary.self,
            from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}")).to(equal(binary))

        expect(try decoder.decode(CodeWithScope.self, from: "{\"code\": \"hi\" }")).to(equal(CodeWithScope(code: "hi")))
        let cws = CodeWithScope(code: "hi", scope: ["x": 1])
        expect(try decoder.decode(CodeWithScope.self,
            from: "{\"code\": \"hi\", \"scope\": {\"x\" : 1} }")).to(equal(cws))

        expect(try decoder.decode(Document.self, from: "{\"x\": 1}")).to(equal(["x": 1]))

        let ts = Timestamp(timestamp: 1, inc: 2)
        expect(try decoder.decode(Timestamp.self, from: "{ \"$timestamp\" : { \"t\" : 1, \"i\" : 2 } }")).to(equal(ts))

        let regex = RegularExpression(pattern: "^abc", options: "imx")
        expect(try decoder.decode(RegularExpression.self,
            from: "{ \"$regularExpression\" : { \"pattern\" :\"^abc\", \"options\" : \"imx\" } }")).to(equal(regex))

        expect(try decoder.decode(MinKey.self, from: "{\"$minKey\": 1}")).to(equal(MinKey()))
        expect(try decoder.decode(MaxKey.self, from: "{\"$maxKey\": 1}")).to(equal(MaxKey()))

        expect(try decoder.decode(Bool.self, from: "false")).to(beFalse())
        expect(try decoder.decode(Bool.self, from: "true")).to(beTrue())

        expect(try decoder.decode([Int].self, from: "[1, 2, 3]")).to(equal([1, 2, 3]))
    }

    // test that Document.init(from decoder: Decoder) works with a non BSON decoder.
    func testDocumentIsDecodable() throws {
        // note: instead of doing this, one can and should just initialize a Document with the `init(fromJSON:)`
        // constructor. this test is to demonstrate that a Document can theoretically be created from any decoder.
        let decoder = JSONDecoder()

        let json = """
        {
            "name": "Durian",
            "points": 600,
            "description": "A fruit with a distinctive scent.",
            "array": ["a", "b", "c"],
            "doc": { "x" : 2.0 }
        }
        """.data(using: .utf8)!

        let expected: Document = [
            "description": "A fruit with a distinctive scent.",
            "doc": ["x": 2.0] as Document,
            "name": "Durian",
            "array": ["a", "b", "c"],
            "points": 600.0
        ]

        let res = try decoder.decode(Document.self, from: json)
        expect(res).to(equal(expected))
    }
}
