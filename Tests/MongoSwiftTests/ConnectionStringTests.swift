import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

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
    let warning: Bool?
    /// An object containing key/value pairs for each parsed query string option.
    let options: BSONDocument?
    /// Hosts contained in the connection string.
    let hosts: [TestServerAddress]?
    /// Auth information.
    let auth: TestCredential?
}

/// Represents a host in a connection string. We can't just use ServerAddress because the port
/// may not be present.
struct TestServerAddress: Decodable {
    /// The host.
    let host: String
    /// The port number.
    let port: UInt16?

    /// Compares the test expectation to an actual address. If a field is nil in the expectation we do not need to
    /// assert on it.
    func matches(_ address: ServerAddress) -> Bool {
        self.host == address.host && (self.port == nil || self.port == address.port)
    }
}

/// Represents credential data. We can't use MongoCredential directly as the coding keys don't match.
struct TestCredential: Decodable {
    /// Username.
    let username: String?
    /// Password.
    let password: String?
    /// A string containing the authentication database.
    let db: String?

    /// Compares the test expectation to an actual credential. If a field is nil in the expectation we do not need to
    /// assert on it.
    func matches(_ credential: MongoCredential) -> Bool {
        (self.username == nil || self.username == credential.username) &&
            (self.password == nil || self.password == credential.password) &&
            (self.db == nil || self.db == credential.source)
    }
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
    ],
    "valid-warnings.json": [
        "Empty integer option values are ignored",
        "Empty boolean option value are ignored"
    ]
]
// libmongoc does not validate negative timeout values and will leave these values in the URI. Also see CDRIVER-3167.
let shouldWarnButLibmongocAllows: [String: [String]] = [
    "connection-pool-options.json": ["Too low maxIdleTimeMS causes a warning"],
    "read-preference-options.json": ["Too low maxStalenessSeconds causes a warning"]
]

// tests we skip because we don't support the specified behavior.
let skipUnsupported: [String: [String]] = [
    "compression-options.json": ["Multiple compressors are parsed correctly"], // requires Snappy, see SWIFT-894
    "valid-db-with-dotted-name.json": ["*"] // libmongoc doesn't allow db names in dotted form in the URI
]

func shouldSkip(file: String, test: String) -> Bool {
    if let skipList = shouldWarnButLibmongocAllows[file], skipList.contains(test) {
        return true
    }

    if let skipList = skipUnsupported[file], skipList.contains(test) || skipList.contains("*") {
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
    // swiftlint:disable:next cyclomatic_complexity
    func runTests(_ specName: String) throws {
        let testFiles = try retrieveSpecTestFiles(specName: specName, asType: ConnectionStringTestFile.self)
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

                if testCase.warning == true {
                    // TODO: SWIFT-511: revisit when we implement logging spec.
                }

                let connString = try ConnectionString(testCase.uri)
                var parsedOptions = connString.options ?? BSONDocument()

                // normalize wtimeoutMS type
                if let wTimeout = parsedOptions.wtimeoutms?.int64Value {
                    parsedOptions.wtimeoutms = .int32(Int32(wTimeout))
                }

                // Assert that options match, if present
                for (key, value) in testCase.options ?? BSONDocument() {
                    expect(parsedOptions[key.lowercased()])
                        .to(equal(value), description: "Value for key \(key) doesn't match")
                }

                // Assert that hosts match, if present
                if let expectedHosts = testCase.hosts {
                    // always present since these are not srv URIs.
                    let actualHosts = connString.hosts!
                    for expectedHost in expectedHosts {
                        guard actualHosts.contains(where: { expectedHost.matches($0) }) else {
                            XCTFail("No host found matching \(expectedHost) in host list \(actualHosts)")
                            continue
                        }
                    }
                }

                // Assert that auth matches, if present
                if let expectedAuth = testCase.auth {
                    let actual = connString.credential
                    guard expectedAuth.matches(actual) else {
                        XCTFail("Expected credentials: \(expectedAuth) do not match parsed credentials: \(actual)")
                        continue
                    }
                }
            }
        }
    }

    func testURIOptions() throws {
        try self.runTests("uri-options")
    }

    func testConnectionString() throws {
        try self.runTests("connection-string")
    }

    func testAppNameOption() throws {
        // option is set correctly from options struct
        let opts1 = MongoClientOptions(appName: "MyApp")
        let connStr1 = try ConnectionString("mongodb://localhost:27017", options: opts1)
        expect(connStr1.appName).to(equal("MyApp"))

        // option is parsed correctly from string
        let connStr2 = try ConnectionString("mongodb://localhost:27017/?appName=MyApp")
        expect(connStr2.appName).to(equal("MyApp"))

        // options struct overrides string
        let connStr3 = try ConnectionString("mongodb://localhost:27017/?appName=MyApp2", options: opts1)
        expect(connStr3.appName).to(equal("MyApp"))
    }

    func testReplSetOption() throws {
        // option is set correctly from options struct
        var opts = MongoClientOptions(replicaSet: "rs0")
        let connStr1 = try ConnectionString("mongodb://localhost:27017", options: opts)
        expect(connStr1.replicaSet).to(equal("rs0"))

        // option is parsed correctly from string
        let connStr2 = try ConnectionString("mongodb://localhost:27017/?replicaSet=rs1")
        expect(connStr2.replicaSet).to(equal("rs1"))

        // options struct overrides string
        let connStr3 = try ConnectionString("mongodb://localhost:27017/?replicaSet=rs1", options: opts)
        expect(connStr3.replicaSet).to(equal("rs0"))

        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print("Skipping rest of test because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        // lower server selection timeout to speed up expected failure
        let testConnStr = MongoSwiftTestCase.getConnectionString() + "&serverSelectionTimeoutMS=1000"

        // setting actual name via client options should succeed in connecting
        opts.replicaSet = try ConnectionString(testConnStr).replicaSet
        try self.withTestClient(testConnStr, options: opts) { client in
            expect(try client.listDatabases().wait()).toNot(throwError())
        }

        // setting to an incorrect repl set name via client options should fail to connect
        opts.replicaSet! += "xyz"
        try self.withTestClient(testConnStr, options: opts) { client in
            expect(try client.listDatabases().wait()).to(throwError())
        }
    }
}
