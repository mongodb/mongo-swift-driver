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
        let opts = NSRegularExpression.optionsFromString("imx")
        doc["string"] = "test string"
        doc["true"] = true
        doc["false"] = false
        doc["int"] = 25
        doc["int32"] = Int32(5)
        doc["int64"] = Int64(10)
        doc["double"] = Double(15)
        doc["minkey"] = MinKey()
        doc["maxkey"] = MaxKey()
        doc["date"] = Date(timeIntervalSince1970: 5000)

        do { doc["regex"] = try NSRegularExpression(pattern: "^abc", options: opts)
        } catch { }

        doc["array1"] = [1, 2]
        doc["array2"] = ["string1", "string2"]
        doc["nestedarray"] = [[1, 2], [Int32(3), Int32(4)]]

        XCTAssertEqual(doc["string"] as? String, "test string")
        XCTAssertEqual(doc["true"] as? Bool, true)
        XCTAssertEqual(doc["false"] as? Bool, false)
        XCTAssertEqual(doc["int"] as? Int, 25)
        XCTAssertEqual(doc["int32"] as? Int, 5)
        XCTAssertEqual(doc["int64"] as? Int64, 10)
        XCTAssertEqual(doc["double"] as? Double, 15)
        XCTAssertEqual(doc["minkey"] as? MinKey, MinKey())
        XCTAssertEqual(doc["maxkey"] as? MaxKey, MaxKey())
        XCTAssertEqual(doc["date"] as? Date, Date(timeIntervalSince1970: 5000))

        let regex = doc["regex"] as! NSRegularExpression
        XCTAssertEqual(regex.pattern as? String, "^abc")
        XCTAssertEqual(regex.stringOptions as? String, "imx")

        XCTAssertEqual(doc["array1"] as! [Int], [1, 2])
        XCTAssertEqual(doc["array2"] as! [String], ["string1", "string2"])

        guard let nestedArray = doc["nestedarray"] else { return }
        let intArrays = nestedArray as! [[Int]]
        XCTAssertEqual(intArrays.count, 2)
        XCTAssertEqual(intArrays[0], [1, 2])
        XCTAssertEqual(intArrays[1], [3, 4])

        let doc2: Document = ["hi": true, "hello": "hi", "cat": 2]
        XCTAssertEqual(doc2["hi"] as? Bool, true)
        XCTAssertEqual(doc2["hello"] as? String, "hi")
        XCTAssertEqual(doc2["cat"] as? Int, 2)

        let doc3 = Document(["hi": true, "hello": "hi", "cat": 2])
        XCTAssertEqual(doc3["hi"] as? Bool, true)
        XCTAssertEqual(doc3["hello"] as? String, "hi")
        XCTAssertEqual(doc3["cat"] as? Int, 2)
    }
}
