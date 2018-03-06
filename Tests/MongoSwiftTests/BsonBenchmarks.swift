import Foundation
@testable import MongoSwift
import XCTest

let basePath = "Tests/Specs/benchmarking/data/"
let flatBsonFile = URL(fileURLWithPath: basePath + "flat_bson.json")
let deepBsonFile = URL(fileURLWithPath: basePath + "deep_bson.json")
let fullBsonFile = URL(fileURLWithPath: basePath + "full_bson.json")

final class BsonBenchmarkTests: XCTestCase {
    static var allTests: [(String, (BsonBenchmarkTests) -> () throws -> Void)] {
        return [
            ("testFlatEncoding", testFlatEncoding),
            ("testFlatDecoding", testFlatDecoding),
            ("testDeepEncoding", testDeepEncoding),
            ("testDeepDecoding", testDeepDecoding),
            ("testFullEncoding", testFullEncoding),
            ("testFullDecoding", testFullDecoding)
        ]
    }

    let iterations = 10000

    // Read in the file, and then serialize its JSON by creating 
    // a `Document`, which wraps the encoded data in a `bson_t`. 
    // Repeat serialization 10,000 times. 
    func doEncodingTest(file: URL) throws {
        let jsonString = try String(contentsOf: file, encoding: .utf8)
        measure {
            for _ in 1...self.iterations {
                do { _ = try Document(fromJSON: jsonString)
                } catch {}
            }
        }
    }

    // Read in the file, and then serialize its JSON by creating
    // a `Document`, which wraps the encoded data in a `bson_t`. 
    // Deserialize the data by converting it to extended JSON. 
    // Repeat deserialization 10,000 times.
    func doDecodingTest(file: URL) throws {
        let jsonString = try String(contentsOf: file, encoding: .utf8)
        let document = try Document(fromJSON: jsonString)
        measure {
            for _ in 1...self.iterations {
                _ = document.canonicalExtendedJSON
            }
        }
    }
    func testFlatEncoding() throws {
        try doEncodingTest(file: flatBsonFile)
    }

    func testFlatDecoding() throws {
        try doDecodingTest(file: flatBsonFile)
    }

    func testDeepEncoding() throws {
        try doEncodingTest(file: deepBsonFile)
    }

    func testDeepDecoding() throws {
        try doDecodingTest(file: deepBsonFile)
    }

    func testFullEncoding() throws {
        try doEncodingTest(file: fullBsonFile)
    }

    func testFullDecoding() throws {
        try doDecodingTest(file: fullBsonFile)
    }

}
