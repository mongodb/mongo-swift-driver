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
        let doc: Document = [
            "string": "test string",
            "true": true,
            "false": false,
            "int": 25,
            "int32": Int32(5),
            "int64": Int64(10),
            "double": Double(15),
            "minkey": MinKey(),
            "maxkey": MaxKey(),
            "date": Date(timeIntervalSince1970: 5000),
            "timestamp": Timestamp(timestamp: 5, inc: 10),
            "nestedarray": [[1, 2] as [Int], [Int32(3), Int32(4)] as [Int32]] as [BsonValue],
            "nesteddoc": ["a": 1, "b": 2, "c": false, "d": [3, 4] as [Int]] as Document,
            "oid": ObjectId(from: "507f1f77bcf86cd799439011"),
            "array1": [1, 2] as [Int],
            "array2": ["string1", "string2"] as [String],
            "null": nil,
            "code": JavascriptCode(code: "console.log('hi');"),
            "codewscope": JavascriptCode(code: "console.log(x);", scope: ["x": 2] as Document)
        ]

        let regex: NSRegularExpression?
        let opts = NSRegularExpression.optionsFromString("imx")

        do {
            regex = try NSRegularExpression(pattern: "^abc", options: opts)
        } catch {
            XCTAssert(false, "Failed to create test NSRegularExpression")
            return
        }

        doc["regex"] = regex

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
        XCTAssertEqual(doc["timestamp"] as? Timestamp, Timestamp(timestamp: 5, inc: 10))
        XCTAssertEqual(doc["oid"] as? ObjectId, ObjectId(from: "507f1f77bcf86cd799439011"))
        XCTAssertEqual(doc["array1"] as! [Int], [1, 2])
        XCTAssertEqual(doc["array2"] as! [String], ["string1", "string2"])
        XCTAssertNil(doc["null"])

        let code = doc["code"] as! JavascriptCode
        XCTAssertEqual(code.code, "console.log('hi');")
        XCTAssertNil(code.scope)

        let codewscope = doc["codewscope"] as! JavascriptCode
        XCTAssertEqual(codewscope.code, "console.log(x);")
        let scope = codewscope.scope as! Document
        XCTAssertEqual(scope["x"] as! Int, 2)

        guard let nestedArray = doc["nestedarray"] else { return }
        let intArrays = nestedArray as! [[Int]]
        XCTAssertEqual(intArrays.count, 2)
        XCTAssertEqual(intArrays[0], [1, 2])
        XCTAssertEqual(intArrays[1], [3, 4])

        let regexReturned = doc["regex"] as! NSRegularExpression
        XCTAssertEqual(regexReturned.pattern as String, "^abc")
        XCTAssertEqual(regexReturned.stringOptions as String, "imx")

        let nestedDoc = doc["nesteddoc"] as! Document
        XCTAssertEqual(nestedDoc["a"] as? Int, 1)
        XCTAssertEqual(nestedDoc["b"] as? Int, 2)
        XCTAssertEqual(nestedDoc["c"] as? Bool, false)
        XCTAssertEqual(nestedDoc["d"] as! [Int], [3, 4])

        let doc2 = Document(["hi": true, "hello": "hi", "cat": 2])
        XCTAssertEqual(doc2["hi"] as? Bool, true)
        XCTAssertEqual(doc2["hello"] as? String, "hi")
        XCTAssertEqual(doc2["cat"] as? Int, 2)

    }
}
