import Foundation
@testable import MongoSwift
import XCTest

final class CodecTests: XCTestCase {
    static var allTests: [(String, (CodecTests) -> () throws -> Void)] {
        return [
            ("testEncodeStructs", testEncodeStructs),
            ("testEncodeListDatabasesOptions", testEncodeListDatabasesOptions),
            ("testNilEncodingStrategy", testNilEncodingStrategy)
        ]
    }

    func testEncodeStructs() {

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

        struct ListDatabasesOptions: BsonEncodable {
        /// An optional filter for the returned databases
        let filter: Document?

        /// Optionally indicate whether only names should be returned
        let nameOnly: Bool?

        /// An optional session to use for this operation
        let session: ClientSession?

        // public func encode(to encoder: BsonEncoder) throws {
        //     try encoder.encode(filter, forKey: "filter")
        //     try encoder.encode(nameOnly, forKey: "nameOnly")
        //     try encoder.encode(session, forKey: "session")
        // }
        }

        let v = TestClass()
        let enc = BsonEncoder()
        do {
            guard let res = try enc.encode(v) else {
                XCTFail("Failed to encode value")
                return
            }

            let expected: Document = [
                "val2": 0,
                "val3": [1, 2, [3, 4] as Document] as Document,
                "val5": [3, ["y": 2, "x": 1] as Document] as Document,
                "val4": ["y": 2, "x": 1] as Document,
                "val1": "a"
            ]

            XCTAssertEqual(res, expected)

        } catch {
            XCTFail("failed to encode document")
        }
    }

    func testEncodeListDatabasesOptions() {
        let encoder = BsonEncoder()
        let options = ListDatabasesOptions(filter: Document(["a": 10]), nameOnly: true, session: ClientSession())
        do {
            guard let optionsDoc = try encoder.encode(options) else {
                XCTFail("Failed to encode options")
                return
            }

            XCTAssertEqual(optionsDoc, ["session": Document(), "filter": ["a": 10] as Document, "nameOnly": true] as Document)

        } catch {
            XCTFail("Failed to encode options")
        }
    }

    func testNilEncodingStrategy() {
        let encoderNoNils = BsonEncoder()
        let encoderWithNils = BsonEncoder(nilStrategy: .include)

        // Even if the object exists, don't bother encoding it if its properties are all nil
        let emptyOptions = ListDatabasesOptions(filter: nil, nameOnly: nil, session: nil)
        XCTAssertNil(try encoderNoNils.encode(emptyOptions))

        XCTAssertEqual(try encoderWithNils.encode(emptyOptions) as? Document,
            ["session": nil, "filter": nil, "nameOnly": nil] as Document)

        let options = ListDatabasesOptions(filter: nil, nameOnly: true, session: nil)
        XCTAssertEqual(try encoderNoNils.encode(options), ["nameOnly": true] as Document)
        XCTAssertEqual(try encoderWithNils.encode(options), ["session": nil, "filter": nil, "nameOnly": true])
    }
}
