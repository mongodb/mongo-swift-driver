import Foundation
@testable import MongoSwift
import XCTest

final class DocumentTests: XCTestCase {
    static var allTests: [(String, (DocumentTests) -> () throws -> Void)] {
        return [
            ("testDocument", testDocument)
        ]
    }

    func testDocument() {
        let doc = Document()
        doc["string"] = "test string"
        doc["true"] = true
        doc["false"] = false
        doc["int32"] = Int32(5)
        doc["int64"] = Int64(10)
        doc["double"] = Double(15)
        doc["array1"] = [Int32(1), Int32(2)]
        doc["array2"] = ["string1", "string2"]
        doc["decimal128"] = Decimal128("2.0")
        doc["nestedarray"] = [[Int32(1), Int32(2)], [Int32(3), Int32(4)]]

        XCTAssertEqual(doc["string"] as? String, "test string")
        XCTAssertEqual(doc["true"] as? Bool, true)
        XCTAssertEqual(doc["false"] as? Bool, false)
        XCTAssertEqual(doc["int32"] as? Int32, 5)
        XCTAssertEqual(doc["int64"] as? Int64, 10)
        XCTAssertEqual(doc["double"] as? Double, 15)
        XCTAssertEqual(doc["array1"] as! [Int32], [1, 2])
        XCTAssertEqual(doc["array2"] as! [String], ["string1", "string2"])
        XCTAssertEqual(doc["decimal128"] as? Decimal128, Decimal128("2.0"))

        guard let nestedArray = doc["nestedarray"] else { return }
        let intArrays = nestedArray as! [[Int32]]
        XCTAssertEqual(intArrays.count, 2)
        XCTAssertEqual(intArrays[0], [Int32(1), Int32(2)])
        XCTAssertEqual(intArrays[1], [Int32(3), Int32(4)])

        let doc2: Document = ["hi": true, "hello": "hi", "cat": Int32(2)]
        XCTAssertEqual(doc2["hi"] as? Bool, true)
        XCTAssertEqual(doc2["hello"] as? String, "hi")
        XCTAssertEqual(doc2["cat"] as? Int32, 2)

        let doc3 = Document(["hi": true, "hello": "hi", "cat": Int32(2)])
        XCTAssertEqual(doc3["hi"] as? Bool, true)
        XCTAssertEqual(doc3["hello"] as? String, "hi")
        XCTAssertEqual(doc3["cat"] as? Int32, 2)
    }
}
