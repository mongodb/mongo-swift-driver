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
        "Invalid directConnection value",

        // libmongoc actually does nothing when these values are too low. for consistency with the behavior when invalid
        // values are provided for other known options, we upconvert these to an error.
        "Too low serverSelectionTimeoutMS causes a warning",
        "Too low localThresholdMS causes a warning"
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

        let testConnStr = MongoSwiftTestCase.getConnectionString()
        let rsName = try ConnectionString(testConnStr).replicaSet!

        var connStrWithoutRS = testConnStr
        connStrWithoutRS.removeSubstring("replicaSet=\(rsName)")
        print("without rs: \(connStrWithoutRS)")

        // setting actual name via options struct only should succeed in connecting
        opts.replicaSet = rsName
        try self.withTestClient(connStrWithoutRS, options: opts) { client in
            expect(try client.listDatabases().wait()).toNot(throwError())
        }

        // setting actual name via both client options and URI should succeed in connecting
        opts.replicaSet = rsName
        try self.withTestClient(testConnStr, options: opts) { client in
            expect(try client.listDatabases().wait()).toNot(throwError())
        }

        // setting to an incorrect repl set name via client options should fail to connect
        // speed up server selection timeout to fail faster
        opts.replicaSet! += "xyz"
        try self.withTestClient(testConnStr + "&serverSelectionTimeoutMS=1000", options: opts) { client in
            expect(try client.listDatabases().wait()).to(throwError())
        }
    }

    func testHeartbeatFrequencyMSOption() throws {
        // option is set correctly from options struct
        let opts = MongoClientOptions(heartbeatFrequencyMS: 50000)
        let connStr1 = try ConnectionString("mongodb://localhost:27017", options: opts)
        expect(connStr1.options?["heartbeatfrequencyms"]?.int32Value).to(equal(50000))

        // option is parsed correctly from string
        let connStr2 = try ConnectionString("mongodb://localhost:27017/?heartbeatFrequencyMS=50000")
        expect(connStr2.options?["heartbeatfrequencyms"]?.int32Value).to(equal(50000))

        // options struct overrides string
        let connStr3 = try ConnectionString("mongodb://localhost:27017/?heartbeatFrequencyMS=20000", options: opts)
        expect(connStr3.options?["heartbeatfrequencyms"]?.int32Value).to(equal(50000))

        let tooSmall = 10
        expect(try ConnectionString("mongodb://localhost:27017/?heartbeatFrequencyMS=\(tooSmall)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        expect(try ConnectionString(
            "mongodb://localhost:27017",
            options: MongoClientOptions(heartbeatFrequencyMS: tooSmall)
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        guard !MongoSwiftTestCase.is32Bit else {
            print("Skipping remainder of test, only supported on 64-bit platforms")
            return
        }

        let tooLarge = Int(Int32.max) + 1
        expect(try ConnectionString(
            "mongodb://localhost:27017",
            options: MongoClientOptions(heartbeatFrequencyMS: tooLarge)
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        expect(try ConnectionString("mongodb://localhost:27017/?heartbeatFrequencyMS=\(tooLarge)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    fileprivate class HeartbeatWatcher: SDAMEventHandler {
        fileprivate var started: [Date] = []
        fileprivate var succeeded: [Date] = []

        // listen for TopologyDescriptionChanged events and continually record the latest description we've seen.
        fileprivate func handleSDAMEvent(_ event: SDAMEvent) {
            switch event {
            case .serverHeartbeatStarted:
                self.started.append(Date())
            case .serverHeartbeatSucceeded:
                self.succeeded.append(Date())
            default:
                return
            }
        }

        fileprivate init() {}
    }

    func testHeartbeatFrequencyMSWithMonitoring() throws {
        guard MongoSwiftTestCase.topologyType == .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let watcher = HeartbeatWatcher()

        // verify that we can speed up the heartbeat frequency
        try self.withTestClient(options: MongoClientOptions(heartbeatFrequencyMS: 2000)) { client in
            client.addSDAMEventHandler(watcher)
            _ = try client.listDatabases().wait()
            sleep(5) // sleep to allow heartbeats to occur
        }

        // in case there's an uneven number of events (i.e. client was closed mid-heartbeat) drop any
        // started events at the end with no corresponding succeeded event
        let succeeded = watcher.succeeded
        let started = watcher.started[0..<succeeded.endIndex]

        // the last started time should be 2s after the second-to-last succeeded time.
        let lastStart = started.last!
        let secondToLastSuccess = succeeded[succeeded.count - 2]

        let difference = lastStart.timeIntervalSince1970 - secondToLastSuccess.timeIntervalSince1970
        expect(difference).to(beCloseTo(2.0, within: 0.2))
    }

    func testServerSelectionTimeoutMS() throws {
        // option is set correctly from options struct
        let opts = MongoClientOptions(serverSelectionTimeoutMS: 10000)
        let connStr1 = try ConnectionString("mongodb://localhost:27017", options: opts)
        expect(connStr1.options?["serverselectiontimeoutms"]?.int32Value).to(equal(10000))

        // option is parsed correctly from string
        let connStr2 = try ConnectionString("mongodb://localhost:27017/?serverSelectionTimeoutMS=10000")
        expect(connStr2.options?["serverselectiontimeoutms"]?.int32Value).to(equal(10000))

        // options struct overrides string
        let connStr3 = try ConnectionString("mongodb://localhost:27017/?serverSelectionTimeoutMS=5000", options: opts)
        expect(connStr3.options?["serverselectiontimeoutms"]?.int32Value).to(equal(10000))

        let tooSmall = 0

        expect(try ConnectionString(
            "mongodb://localhost:27017",
            options: MongoClientOptions(serverSelectionTimeoutMS: tooSmall)
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))
        expect(try ConnectionString(
            "mongodb://localhost:27017/?serverSelectionTimeoutMS=\(tooSmall)"
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        guard !MongoSwiftTestCase.is32Bit else {
            print("Skipping remainder of test, only supported on 64-bit platforms")
            return
        }

        let tooLarge = Int(Int32.max) + 1
        expect(try ConnectionString("mongodb://localhost:27017/?serverSelectionTimeoutMS=\(tooLarge)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        expect(try ConnectionString(
            "mongodb://localhost:27017",
            options: MongoClientOptions(serverSelectionTimeoutMS: tooLarge)
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    func testServerSelectionTimeoutMSWithCommand() throws {
        let opts = MongoClientOptions(serverSelectionTimeoutMS: 1000)
        try self.withTestClient("mongodb://localhost:27099", options: opts) { client in
            let start = Date()
            expect(try client.listDatabases().wait()).to(throwError(errorType: MongoError.ServerSelectionError.self))
            let end = Date()

            let difference = end.timeIntervalSince1970 - start.timeIntervalSince1970
            expect(difference).to(beCloseTo(1.0, within: 0.2))
        }
    }

    func testLocalThresholdMSOption() throws {
        // option is set correctly from options struct
        let opts = MongoClientOptions(localThresholdMS: 100)
        let connStr1 = try ConnectionString("mongodb://localhost:27017", options: opts)
        expect(connStr1.options?["localthresholdms"]?.int32Value).to(equal(100))

        // option is parsed correctly from string
        let connStr2 = try ConnectionString("mongodb://localhost:27017/?localThresholdMS=100")
        expect(connStr2.options?["localthresholdms"]?.int32Value).to(equal(100))

        // options struct overrides string
        let connStr3 = try ConnectionString("mongodb://localhost:27017/?localThresholdMS=50", options: opts)
        expect(connStr3.options?["localthresholdms"]?.int32Value).to(equal(100))

        let tooSmall = -10
        expect(try ConnectionString(
            "mongodb://localhost:27017",
            options: MongoClientOptions(localThresholdMS: tooSmall)
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        expect(try ConnectionString(
            "mongodb://localhost:27017/?localThresholdMS=\(tooSmall)"
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        guard !MongoSwiftTestCase.is32Bit else {
            print("Skipping remainder of test, requires 64-bit platform")
            return
        }

        let tooLarge = Int(Int32.max) + 1
        expect(try ConnectionString("mongodb://localhost:27017/?localThresholdMS=\(tooLarge)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
        expect(try ConnectionString(
            "mongodb://localhost:27017",
            options: MongoClientOptions(localThresholdMS: tooLarge)
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }
}
