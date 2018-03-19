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
}
