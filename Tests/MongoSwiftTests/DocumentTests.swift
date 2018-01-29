import Foundation
import XCTest
@testable import MongoSwift

final class DocumentTests: XCTestCase {
    static var allTests: [(String, (DocumentTests) -> () throws -> Void)] {
        return [
            ("testDocument", testDocument)
        ]
    }

    func testDocument() {
        var doc = Document()
        doc["string"] = "test string"
        doc["true"] = true
        doc["false"] = false

        XCTAssertEqual(doc["string"] as? String, "test string")
        XCTAssertEqual(doc["true"] as? Bool, true)
        XCTAssertEqual(doc["false"] as? Bool, false)
    }
}
