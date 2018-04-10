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
    }

    struct NestedStruct: Decodable, Equatable {
        let s1: BasicStruct
        let s2: BasicStruct
    }

    struct NestedArray: Decodable, Equatable {
        let array: [BasicStruct]
    }

    struct NestedNestedStruct: Decodable, Equatable {
        let s: NestedStruct
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
}
