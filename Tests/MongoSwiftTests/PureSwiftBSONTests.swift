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
        // test we can convert to an array successfully
        _ = Array(doc)
    }

    func testBSONCorpus() throws {
        let testFilesPath = MongoSwiftTestCase.specsPath + "/bson-corpus/tests"
        var testFiles = try FileManager.default.contentsOfDirectory(atPath: testFilesPath)
        testFiles = testFiles.filter { $0.hasSuffix(".json") }

        for fileName in testFiles {
            // unsupported type
            if fileName.contains("decimal128") { continue }

            let testFilePath = URL(fileURLWithPath: "\(testFilesPath)/\(fileName)")
            let testFileData = try Data(contentsOf: testFilePath)
            let testCase = try JSONDecoder().decode(BSONCorpusTestFile.self, from: testFileData)

            if let valid = testCase.valid {
                for v in valid {
                    let canonicalData = Data(hex: v.canonicalBSON)!

                    // native_to_bson( bson_to_native(cB) ) = cB
                    let canonicalDoc = try PureBSONDocument(fromBSON: canonicalData)
                    let canonicalDocAsArray = try canonicalDoc.toArray()
                    let roundTrippedCanonicalDoc = PureBSONDocument(fromArray: canonicalDocAsArray)
                    expect(roundTrippedCanonicalDoc).to(equal(canonicalDoc))

                    // native_to_bson( bson_to_native(dB) ) = cB
                    if let db = v.degenerateBSON {
                        let degenerateData = Data(hex: db)!
                        let degenerateDoc = try PureBSONDocument(fromBSON: degenerateData)
                        let degenerateDocAsArray = try degenerateDoc.toArray()
                        let roundTrippedDegenerateDoc = PureBSONDocument(fromArray: degenerateDocAsArray)
                        expect(roundTrippedDegenerateDoc).to(equal(canonicalDoc))
                    }
                }
            }

            if let decodeErrors = testCase.decodeErrors {
                for error in decodeErrors {
                    let badData = Data(hex: error.bson)!
                    do {
                        let badDoc = try PureBSONDocument(fromBSON: badData)
                        _ = try badDoc.toArray()
                    } catch {
                        expect(error).toNot(beNil())
                    }
                }
            }

            // todo: test parse errors once decimal128 is supported

            // todo: test parse errors from top.json once extJSON is supported
        }
    }
}

extension PureBSONDocument {
    func toArray() throws -> [(String, BSON)] {
        var out = [(String, BSON)]()
        var iter = self.makeIterator()
        while let next = try iter.nextOrError() {
            out.append(next)
        }
        return out
    }

    init(fromArray array: [(String, BSON)]) {
        var out = PureBSONDocument()
        for (key, value) in array {
            out[key] = value
        }
        self = out
    }
}

struct BSONCorpusTestFile: Codable {
    let description: String
    let bsonType: String
    let testKey: String?
    let valid: [BSONCorpusTestCase]?
    let decodeErrors: [BSONCorpusDecodeError]?
    let parseErrors: [BSONCorpusParseError]?

    private enum CodingKeys: String, CodingKey {
        case description,
            bsonType = "bson_type",
            testKey = "test_key",
            valid,
            decodeErrors,
            parseErrors
    }
}

struct BSONCorpusTestCase: Codable {
    let description: String
    let canonicalBSON: String
    let degenerateBSON: String?
    let relaxedExtJSON: String?
    let canonicalExtJSON: String
    let convertedExtJSON: String?

    private enum CodingKeys: String, CodingKey {
        case description,
            canonicalBSON = "canonical_bson",
            degenerateBSON = "degenerate_bson",
            relaxedExtJSON = "relaxed_extjson",
            canonicalExtJSON = "canonical_extjson",
            convertedExtJSON = "converted_extjson"
    }
}

struct BSONCorpusDecodeError: Codable {
    let description: String
    let bson: String
}

struct BSONCorpusParseError: Codable {
    let description: String
    let string: String
}