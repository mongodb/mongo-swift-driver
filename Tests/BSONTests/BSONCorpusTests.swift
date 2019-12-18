import Foundation
import MongoSwift
import Nimble
import TestsCommon
import XCTest

final class BSONCorpusTests: MongoSwiftTestCase {
    /// Test case that includes 'canonical' forms of BSON and Extended JSON that are deemed equivalent and may provide
    /// additional cases or metadata for additional assertions.
    struct BSONCorpusValidityTest: Decodable {
        enum CodingKeys: String, CodingKey {
            case description, canonicalBSON = "canonical_bson", canonicalExtJSON = "canonical_extjson",
                relaxedExtJSON = "relaxed_extjson", degenerateBSON = "degenerate_bson",
                degenerateExtJSON = "degenerate_extjson", convertedBSON = "converted_bson",
                convertedExtJSON = "converted_extjson", lossy
        }

        /// Human-readable test case label.
        let description: String

        /// an (uppercase) big-endian hex representation of a BSON byte string.
        let canonicalBSON: String

        /// a string containing a Canonical Extended JSON document. Because this is itself embedded as a string inside a
        /// JSON document, characters like quote and backslash are escaped.
        let canonicalExtJSON: String

        /// A string containing a Relaxed Extended JSON document.
        /// Because this is itself embedded as a string inside a JSON document, characters like quote and backslash
        /// are escaped.
        let relaxedExtJSON: String?

        /// An (uppercase) big-endian hex representation of a BSON byte string that is technically parseable, but
        /// not in compliance with the BSON spec.
        let degenerateBSON: String?

        /// A string containing an invalid form of Canonical Extended JSON that is still parseable according to
        /// type-specific rules. (For example, "1e100" instead of "1E+100".)
        let degenerateExtJSON: String?

        /// An (uppercase) big-endian hex representation of a BSON byte string. It may be present for deprecated types.
        /// It represents a possible conversion of the deprecated type to a non-deprecated type, e.g. symbol to string.
        let convertedBSON: String?

        /// A string containing a Canonical Extended JSON document.
        /// Because this is itself embedded as a string inside a JSON document, characters like quote and backslash
        /// are escaped.
        /// It may be present for deprecated types and is the Canonical Extended JSON representation of `convertedBson`.
        let convertedExtJSON: String?

        /// A bool that is present (and true) iff `canonicalBson` can't be represented exactly with extended
        /// JSON (e.g. NaN with a payload).
        let lossy: Bool?
    }

    /// A test case that provides an invalid BSON document or field that should result in an error.
    struct BSONCorpusDecodeErrorTest: Decodable {
        /// Human-readable test case label.
        let description: String

        /// An (uppercase) big-endian hex representation of an invalid BSON string that should fail to decode correctly.
        let bson: String
    }

    /// Test case that is type-specific and represents some input that can not be encoded to the BSON type under test.
    struct BSONCorpusParseErrorTest: Decodable {
        /// Human-readable test case label.
        let description: String

        /// A textual or numeric representation of an input that can't be parsed to a valid value of the given type.
        let string: String
    }

    /// A BSON corpus test file for an individual BSON type.
    struct BSONCorpusTestFile: Decodable {
        enum CodingKeys: String, CodingKey {
            case description, bsonType = "bson_type", valid, parseErrors, decodeErrors, deprecated
        }

        /// Human-readable rdescription of the file.
        let description: String

        /// Hex string of the first byte of a BSON element (e.g. "0x01" for type "double").
        /// This will be the synthetic value "0x00" for "whole document" tests like top.json.
        let bsonType: String

        /// An array of validity test cases.
        let valid: [BSONCorpusValidityTest]?

        /// An array of decode error cases.
        let decodeErrors: [BSONCorpusDecodeErrorTest]?

        /// An array of type-specific parse error cases.
        let parseErrors: [BSONCorpusParseErrorTest]?

        /// This field will be present (and true) if the BSON type being tested has been deprecated (e.g. Symbol)
        let deprecated: Bool?
    }

    // swiftlint:disable:next cyclomatic_complexity
    func testBSONCorpus() throws {
        let SKIPPED_CORPUS_TESTS = [
            /* CDRIVER-1879, can't make Code with embedded NIL */
            "Javascript Code": ["Embedded nulls"],
            "Javascript Code with Scope": ["Unicode and embedded null in code string, empty scope"],
            "Top-level document validity": [
                // CDRIVER-2223, legacy extended JSON $date syntax uses numbers
                "Bad $date (number, not string or hash)",
                // TODO: SWIFT-330: unskip these
                "Invalid BSON type low range",
                "Invalid BSON type high range"
            ]
        ]

        let shouldSkip = { testFileDesc, testDesc in
            SKIPPED_CORPUS_TESTS[testFileDesc]?.contains { $0 == testDesc } == true
        }

        for (_, testFile) in try retrieveSpecTestFiles(specName: "bson-corpus", asType: BSONCorpusTestFile.self) {
            if let validityTests = testFile.valid {
                for test in validityTests {
                    guard !shouldSkip(testFile.description, test.description) else {
                        continue
                    }

                    guard let cBData = Data(hexString: test.canonicalBSON) else {
                        XCTFail("Unable to interpret canonical_bson as Data")
                        return
                    }

                    guard let cEJData = test.canonicalExtJSON.data(using: .utf8) else {
                        XCTFail("Unable to interpret canonical_extjson as Data")
                        return
                    }

                    let lossy = test.lossy ?? false

                    // for cB input:
                    // native_to_bson( bson_to_native(cB) ) = cB
                    let docFromCB = try Document(fromBSON: cBData)
                    expect(docFromCB.rawBSON).to(equal(cBData))

                    // test round tripping through documents
                    // We create an array by reading every element out of the document (and therefore out of the
                    // bson_t). We then create a new document and append each element of the array to it. Once that
                    // is done, every element in the original document will have gone from bson_t -> Swift data type
                    // -> bson_t. At the end, the new bson_t should be identical to the original one. If not, our bson_t
                    // translation layer is lossy and/or buggy.
                    let nativeFromDoc = docFromCB.toArray()
                    let docFromNative = Document(fromArray: nativeFromDoc)
                    expect(docFromNative.rawBSON).to(equal(cBData))

                    // native_to_canonical_extended_json( bson_to_native(cB) ) = cEJ
                    expect(docFromCB.canonicalExtendedJSON).to(cleanEqual(test.canonicalExtJSON))

                    // native_to_relaxed_extended_json( bson_to_native(cB) ) = rEJ (if rEJ exists)
                    if let rEJ = test.relaxedExtJSON {
                        expect(try Document(fromBSON: cBData).extendedJSON).to(cleanEqual(rEJ))
                    }

                    // for cEJ input:
                    // native_to_canonical_extended_json( json_to_native(cEJ) ) = cEJ
                    expect(try Document(fromJSON: cEJData).canonicalExtendedJSON).to(cleanEqual(test.canonicalExtJSON))

                    // native_to_bson( json_to_native(cEJ) ) = cB (unless lossy)
                    if !lossy {
                        expect(try Document(fromJSON: cEJData).rawBSON).to(equal(cBData))
                    }

                    // for dB input (if it exists):
                    if let dB = test.degenerateBSON {
                        guard let dBData = Data(hexString: dB) else {
                            XCTFail("Unable to interpret degenerate_bson as Data")
                            return
                        }

                        // bson_to_canonical_extended_json(dB) = cEJ
                        expect(try Document(fromBSON: dBData).canonicalExtendedJSON)
                            .to(cleanEqual(test.canonicalExtJSON))

                        // bson_to_relaxed_extended_json(dB) = rEJ (if rEJ exists)
                        if let rEJ = test.relaxedExtJSON {
                            expect(try Document(fromBSON: dBData).extendedJSON).to(cleanEqual(rEJ))
                        }
                    }

                    // for dEJ input (if it exists):
                    if let dEJ = test.degenerateExtJSON {
                        // native_to_canonical_extended_json( json_to_native(dEJ) ) = cEJ
                        expect(try Document(fromJSON: dEJ).canonicalExtendedJSON).to(cleanEqual(test.canonicalExtJSON))

                        // native_to_bson( json_to_native(dEJ) ) = cB (unless lossy)
                        if !lossy {
                            expect(try Document(fromJSON: dEJ).rawBSON).to(equal(cBData))
                        }
                    }

                    // for rEJ input (if it exists):
                    if let rEJ = test.relaxedExtJSON {
                        // native_to_relaxed_extended_json( json_to_native(rEJ) ) = rEJ
                        expect(try Document(fromJSON: rEJ).extendedJSON).to(cleanEqual(rEJ))
                    }
                }
            }

            if let parseErrorTests = testFile.parseErrors {
                for test in parseErrorTests {
                    guard !shouldSkip(testFile.description, test.description) else {
                        continue
                    }
                    let description = "\(testFile.description)-\(test.description)"

                    switch BSONType(rawValue: UInt32(testFile.bsonType.dropFirst(2), radix: 16)!)! {
                    case .invalid: // "top level document" uses 0x00 for the bson type
                        expect(try Document(fromJSON: test.string))
                            .to(throwError(), description: description)
                    case .decimal128:
                        expect(Decimal128(test.string))
                            .to(beNil(), description: description)
                    default:
                        throw TestError(
                            message: "\(description): parse error tests not implemented"
                                + "for bson type \(testFile.bsonType)"
                        )
                    }
                }
            }

            if let decodeErrors = testFile.decodeErrors {
                // TODO: SWIFT-330: unskip the other tests.
                guard testFile.description == "Top-level document validity" else {
                    continue
                }

                for test in decodeErrors {
                    guard !shouldSkip(testFile.description, test.description) else {
                        continue
                    }
                    let description = "\(testFile.description)-\(test.description)"

                    guard let data = Data(hexString: test.bson) else {
                        XCTFail("\(description): Unable to interpret bson as Data")
                        return
                    }
                    expect(try Document(fromBSON: data)).to(throwError(), description: description)
                }
            }
        }
    }
}
