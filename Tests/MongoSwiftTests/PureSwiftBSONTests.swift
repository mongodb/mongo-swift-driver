@testable import MongoSwift
import Nimble
import XCTest

final class PureSwiftBSONTests: MongoSwiftTestCase {
    func testDocument() throws {
        let doc: PureBSONDocument = [
                                        "double": 1.0,
                                        "string": "hi",
                                        "doc": ["a": 1],
                                        "array": [1, 2],
                                        "binary": .binary(try PureBSONBinary(data: Data([0, 0, 0, 0]), subtype: .generic)),
                                        "undefined": .undefined,
                                        "objectid": .objectId(PureBSONObjectId()),
                                        "false": false,
                                        "true": true,
                                        "date": .date(Date()),
                                        "null": .null,
                                        "regex": .regex(PureBSONRegularExpression(pattern: "abc", options: "ix")),
                                        "dbPointer": .dbPointer(PureBSONDBPointer(ref: "foo", id: PureBSONObjectId())),
                                        "symbol": .symbol("hi"),
                                        "code": .code(PureBSONCode(code: "xyz")),
                                        "codewscope": .codeWithScope(PureBSONCodeWithScope(code: "xyz", scope: ["a": 1])),
                                        "int32": .int32(32),
                                        "timestamp": .timestamp(PureBSONTimestamp(timestamp: UInt32(2), inc: UInt32(3))),
                                        "int64": 64,
                                        "minkey": .minKey,
                                        "maxkey": .maxKey,
                                    ]
        let values = Array(doc)
    }
}