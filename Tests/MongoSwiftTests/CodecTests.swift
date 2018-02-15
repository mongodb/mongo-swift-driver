import Foundation
@testable import MongoSwift
import XCTest

final class CodecTests: XCTestCase {
    static var allTests: [(String, (CodecTests) -> () throws -> Void)] {
        return [
            ("encodeTestStructs", encodeTestStructs),
            ("encodeListDatabasesOptions", encodeListDatabasesOptions)
        ]
    }

    func encodeTestStructs() {

        struct TestClass: BsonEncodable {
            let val1 = "a"
            let val2 = 0
            let val3 = [1, 2, [3, 4]] as [Any]
            let val4 = TestClass2()
            let val5 = [3, TestClass2()] as [Any]

            public func encode(to encoder: BsonEncoder) throws {
                try encoder.encode(val1, forKey: "val1")
                try encoder.encode(val2, forKey: "val2")
                try encoder.encode(val3, forKey: "val3")
                try encoder.encode(val4, forKey: "val4")
                try encoder.encode(val5, forKey: "val5")
            }
        }

        struct TestClass2: BsonEncodable {
            let x = 1
            let y = 2

            public func encode(to encoder: BsonEncoder) throws {
                try encoder.encode(x, forKey: "x")
                try encoder.encode(y, forKey: "y")
            }
        }

        let v = TestClass()
        let enc = BsonEncoder()
        do {
            let res: Document = try enc.encode(v)

            XCTAssertEqual(res["val1"] as? String, "a")
            XCTAssertEqual(res["val2"] as? Int, 0)

            guard let val3 = res["val3"] as? Document else {
                XCTAssert(false, "Failed to get val3 from document")
                return
            }
            XCTAssertEqual(val3["0"] as? Int, 1)
            XCTAssertEqual(val3["1"] as? Int, 2)
            guard let val32 = val3["2"] as? Document else {
                XCTAssert(false, "Failed to get val3[2] from document")
                return
            }
            XCTAssertEqual(val32["0"] as? Int, 3)
            XCTAssertEqual(val32["1"] as? Int, 4)

            guard let val4 = res["val4"] as? Document else {
                XCTAssert(false, "Failed to get val4 from document")
                return
            }
            XCTAssertEqual(val4["x"] as? Int, 1)
            XCTAssertEqual(val4["y"] as? Int, 2)

            guard let val5 = res["val5"] as? Document else {
                XCTAssert(false, "Failed to get val5 from document")
                return
            }
            XCTAssertEqual(val5["0"] as? Int, 3)
            guard let val51 = val5["1"] as? Document else {
                XCTAssert(false, "Failed to get val5[1] from document")
                return
            }
            XCTAssertEqual(val51["x"] as? Int, 1)
            XCTAssertEqual(val51["y"] as? Int, 2)

        } catch {
            XCTAssert(false, "failed to encode document")
        }
    }

    func encodeListDatabasesOptions() {
        let encoder = BsonEncoder()
        let options = ListDatabasesOptions(filter: Document(["a": 10]), nameOnly: true, session: ClientSession())
        do {
            let optionsDoc = try encoder.encode(options)
            XCTAssertEqual(optionsDoc["nameOnly"] as? Bool, true)
            guard let filterDoc = optionsDoc["filter"] as? Document else {
                XCTAssert(false, "Failed to get filter document")
                return
            }
            XCTAssertEqual(filterDoc["a"] as? Int, 10)
            guard let sessionDoc = optionsDoc["session"] as? Document else {
                XCTAssert(false, "Failed to get session document")
                return
            }
            XCTAssertEqual(sessionDoc["clusterTime"] as? Int64, 0)
            XCTAssertEqual(sessionDoc["operationTime"] as? Int64, 0)

        } catch {
            XCTAssert(false, "Failed to encode options")
        }
    }
}
