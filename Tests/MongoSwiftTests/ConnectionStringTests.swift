import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon

/// Represents a single file containing connection string tests.
struct ConnectionStringTestFile: Decodable {
    let tests: [ConnectionStringTestCase]
}

/// Represents a single test case within a file.
struct ConnectionStringTestCase: Decodable {
    /// A string describing the test.
    let description: String
    /// A string containing the URI to be parsed.
    let uri: String
    /// A boolean indicating if the URI should be considered valid.
    let valid: Bool
    /// A boolean indicating whether URI parsing should emit a warning
    let warning: Bool
    /// An object containing key/value pairs for each parsed query string option.
    let options: BSONDocument
}

// The spec's expected behavior when an invalid option is encountered is to log a warning and ignore the option.
// however, when encountering an invalid option, mongoc_uri_new_with_error logs a warning but also returns null
// and fills out an error which we throw. so all of these warning cases are upconverted to errors. See CDRIVER-3167.
let shouldWarnButLibmongocErrors: [String: [String]] = [
    "connection-pool-options.json": ["Non-numeric maxIdleTimeMS causes a warning"],
    "single-threaded-options.json": ["Invalid serverSelectionTryOnce causes a warning"],
    "read-preference-options.json": [
        "Invalid readPreferenceTags causes a warning",
        "Non-numeric maxStalenessSeconds causes a warning"
    ],
    "tls-options.json": [
        "Invalid tlsAllowInvalidCertificates causes a warning",
        "Invalid tlsAllowInvalidHostnames causes a warning",
        "Invalid tlsInsecure causes a warning"
    ],
    "compression-options.json": [
        "Non-numeric zlibCompressionLevel causes a warning",
        "Too low zlibCompressionLevel causes a warning",
        "Too high zlibCompressionLevel causes a warning"
    ],
    "connection-options.json": [
        "Non-numeric connectTimeoutMS causes a warning",
        "Non-numeric heartbeatFrequencyMS causes a warning",
        "Too low heartbeatFrequencyMS causes a warning",
        "Non-numeric localThresholdMS causes a warning",
        "Invalid retryWrites causes a warning",
        "Non-numeric serverSelectionTimeoutMS causes a warning",
        "Non-numeric socketTimeoutMS causes a warning",
        "Invalid directConnection value"
    ],
    "concern-options.json": [
        "Non-numeric wTimeoutMS causes a warning",
        "Too low wTimeoutMS causes a warning",
        "Invalid journal causes a warning"
    ]
]
// libmongoc does not validate negative timeout values and will leave these values in the URI. Also see CDRIVER-3167.
let shouldWarnButLibmongocAllows: [String: [String]] = [
    "connection-pool-options.json": ["Too low maxIdleTimeMS causes a warning"],
    "read-preference-options.json": ["Too low maxStalenessSeconds causes a warning"]
]

let skipUnsupported: [String: [String]] = [
    "compression-options.json": ["Multiple compressors are parsed correctly"] // requires Snappy, see SWIFT-894
]

func shouldSkip(file: String, test: String) -> Bool {
    if let skipList = shouldWarnButLibmongocAllows[file], skipList.contains(test) {
        return true
    }

    if let skipList = skipUnsupported[file], skipList.contains(test) {
        return true
    }

    // check for these separately rather than putting them in the skip list since there are a lot of them.
    // TODO: SWIFT-787: unskip
    if test.contains("tlsDisableCertificateRevocationCheck") || test.contains("tlsDisableOCSPEndpointCheck") {
        return true
    }

    return false
}

final class ConnectionStringTests: MongoSwiftTestCase {
    func testURIOptions() throws {
        let testFiles = try retrieveSpecTestFiles(specName: "uri-options", asType: ConnectionStringTestFile.self)
        for (filename, file) in testFiles {
            for testCase in file.tests {
                guard !shouldSkip(file: filename, test: testCase.description) else {
                    continue
                }

                // if it's invalid, or a case where libmongoc errors instead of warning, expect an error.
                guard testCase.valid &&
                    !(shouldWarnButLibmongocErrors[filename]?.contains(testCase.description) ?? false) else {
                    expect(try ConnectionString(testCase.uri)).to(
                        throwError(
                            errorType: MongoError.InvalidArgumentError.self
                        ),
                        description: testCase.description
                    )
                    continue
                }

                if testCase.warning {
                    // TODO: SWIFT-511: revisit when we implement logging spec.
                }

                let connString = try ConnectionString(testCase.uri)
                var parsedOptions = connString.options ?? BSONDocument()

                // normalize wtimeoutMS type
                if let wTimeout = parsedOptions.wtimeoutms?.int64Value {
                    parsedOptions.wtimeoutms = .int32(Int32(wTimeout))
                }

                for (key, value) in testCase.options {
                    expect(parsedOptions[key.lowercased()])
                        .to(equal(value), description: "Value for key \(key) doesn't match")
                }
            }
        }
    }
}
