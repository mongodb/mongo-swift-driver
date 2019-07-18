@testable import MongoSwift
import Nimble
import XCTest

final class PureSwiftBSONTests: MongoSwiftTestCase {
    func testDocument() throws {
        let doc: PureBSONDocument = [
                                        "double": 1.0,
                                        "string": "hi",
                                        "doc": ["a": 1],
                                        //"binary": .binary(try PureBSONBinary(data: Data([0, 0, 0, 0]), subtype: .generic))
                                    ]
        print(doc.data.hex)
        print(doc.byteCount)
        // print(doc["a"])
        // print(doc["b"])

        for (k, v) in doc {
            print("key: \(k), value: \(v)")
        }
    }
}
//     length     subtype    key        length      value  subtype    key      length        value  null
//  [17 00 00 00]   [02]    [61 00] [02 00 00 00]  [61 00]   [02]   [62 00]  [02 00 00 00] [62 00] 00
//   0  1   2  3      4      5   6    7  8  9 10    11 12     13     14 15    16 17 18 19   20 21  22