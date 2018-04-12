import Foundation
@testable import MongoSwift
import XCTest

let basePath = (Bundle(for: BsonBenchmarkTests.self).resourcePath ?? "") + "/data/"
let flatBsonFile = URL(fileURLWithPath: basePath + "flat_bson.json")
let flatSize = 75.31
let deepBsonFile = URL(fileURLWithPath: basePath + "deep_bson.json")
let deepSize = 19.64
let fullBsonFile = URL(fileURLWithPath: basePath + "full_bson.json")
let fullSize = 57.34

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

    let taskIterations = 10000

    // Read in the file, and then serialize its JSON by creating 
    // a `Document`, which wraps the encoded data in a `bson_t`. 
    // Repeat serialization 10,000 times. Unclear how helpful a benchmark
    // this is as there is no C driver analog, so basically this is testing
    // JSON parsing speed. 
    func doEncodingTest(file: URL, size: Double, measureOpIterations: Int = 100) throws {
        let jsonString = try String(contentsOf: file, encoding: .utf8)
        let result = try measureOp({
            for _ in 1...self.taskIterations {
                _ = try Document(fromJSON: jsonString)
            }
        }, iterations: measureOpIterations)

        printResults(time: result, size: size)
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
    func doDecodingTest(file: URL, size: Double, measureOpIterations: Int = 100) throws {
        let jsonString = try String(contentsOf: file, encoding: .utf8)
        let document = try Document(fromJSON: jsonString)
        let result = try measureOp({
            for _ in 1...self.taskIterations {
                self.visit(document)
            }
        }, iterations: measureOpIterations)

        printResults(time: result, size: size)
    }

    func testFlatEncoding() throws {
        try doEncodingTest(file: flatBsonFile, size: flatSize)
    }

    // ~1.551 vs. 0.231 for libbson (6.7x)
    func testFlatDecoding() throws {
        try doDecodingTest(file: flatBsonFile, size: flatSize)
    }

    func testDeepEncoding() throws {
        try doEncodingTest(file: deepBsonFile, size: deepSize, measureOpIterations: 150)
    }

    //  ~1.96 vs .001 for libbson (1960x)
    func testDeepDecoding() throws {
        try doDecodingTest(file: deepBsonFile, size: deepSize)
    }

    func testFullEncoding() throws {
        try doEncodingTest(file: fullBsonFile, size: fullSize)
    }

    // ~3.296 vs for libbson (42x)
    func testFullDecoding() throws {
        try doDecodingTest(file: fullBsonFile, size: fullSize, measureOpIterations: 80)
    }

}
