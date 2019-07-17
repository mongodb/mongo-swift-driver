@testable import MongoSwift
import Nimble
import XCTest

final class PureSwiftBSONTests: MongoSwiftTestCase {
    func testDocument() throws {
        let doc: PureBSONDocument = ["a": "hi", "b": 1]
        print(doc["a"])
        print(doc["b"])
    }
}