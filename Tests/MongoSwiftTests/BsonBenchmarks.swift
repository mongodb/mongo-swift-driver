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
    // Repeat serialization 10,000 times. Unclear how helpful a benchmark
    // this is as there is no C driver analog, so basically this is testing
    // JSON parsing speed. 
    func doEncodingTest(file: URL) throws {
        let jsonString = try String(contentsOf: file, encoding: .utf8)
        measure {
            for _ in 1...self.iterations {
                do { _ = try Document(fromJSON: jsonString)
                } catch {}
            }
        }
    }

    // Recursively visit values 
    func visit(_ value: BsonValue?) {
        switch value {
        // if a document or array, iterate to visit each value
        case let val as Document:
            for (_, v) in val {
                self.visit(v)
            }
        case let val as [BsonValue]:
            for v in val {
                self.visit(v)
            }
        // otherwise, we are done
        default:
            break
        }
    }

    // Read in the file, and then serialize its JSON by creating
    // a `Document`, which wraps the encoded data in a `bson_t`. 
    // "Deserialize" the data by recursively visiting each element.
    // Repeat deserialization 10,000 times.
    func doDecodingTest(file: URL) throws {
        let jsonString = try String(contentsOf: file, encoding: .utf8)
        let document = try Document(fromJSON: jsonString)
        measure {
            for _ in 1...self.iterations {
                self.visit(document)
            }
        }
    }

    func testFlatEncoding() throws {
        try doEncodingTest(file: flatBsonFile)
    }

    // ~1.551 vs. 0.231 for libbson (6.7x)
    func testFlatDecoding() throws {
        try doDecodingTest(file: flatBsonFile)
    }

    func testDeepEncoding() throws {
        try doEncodingTest(file: deepBsonFile)
    }

    //  ~1.96 vs .001 for libbson (1960x)
    func testDeepDecoding() throws {
        try doDecodingTest(file: deepBsonFile)
    }

    func testFullEncoding() throws {
        try doEncodingTest(file: fullBsonFile)
    }

    // ~3.296 vs for libbson (42x)
    func testFullDecoding() throws {
        try doDecodingTest(file: fullBsonFile)
    }

}
