import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

/// Represents a single file containing connection string tests.
private struct ConnectionStringTestFile: Decodable {
    let tests: [ConnectionStringTestCase]
}

/// Represents a single test case within a file.
private struct ConnectionStringTestCase: Decodable {
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
private struct TestServerAddress: Decodable {
    /// The host.
    let host: String
    /// The port number.
    let port: UInt16?

    /// Compares the test expectation to an actual address. If a field is nil in the expectation we do not need to
    /// assert on it.
    func matches(_ address: MongoConnectionString.HostIdentifier) -> Bool {
        self.host == address.host && (self.port == nil || self.port == address.port)
    }
}

/// Represents credential data. We can't use MongoCredential directly as the coding keys don't match.
private struct TestCredential: Decodable {
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

// Tests we skip because we don't support the specified behavior.
let skipUnsupported: [String: [String]] = [
    "valid-auth.json": ["mongodb-cr"], // we don't support MONGODB-CR authentication
    "compression-options.json": ["multiple compressors are parsed correctly"], // requires Snappy, see SWIFT-894
    "connection-pool-options.json": [
        // we don't support maxIdleTimeMS
        "too low maxidletimems causes a warning",
        "non-numeric maxidletimems causes a warning",
        "valid connection pool options are parsed correctly",
        // we don't support minPoolSize
        "minpoolsize=0 does not error",
        // we don't allow maxPoolSize=0, see SWIFT-1339
        "maxpoolsize=0 does not error"
    ],
    "connection-options.json": [
        "valid connection and timeout options are parsed correctly" // we don't support maxIdleTimeMS
    ],
    "single-threaded-options.json": ["*"], // we don't support single threaded options
    "valid-options.json": ["option names are normalized to lowercase"] // we don't support MONGODB-CR authentication
]

func shouldSkip(file: String, test: String) -> Bool {
    if let skipList = skipUnsupported[file],
       skipList.contains(where: test.lowercased().contains) || skipList.contains("*")
    {
        return true
    }

    return false
}

extension MongoConnectionString {
    fileprivate func assertMatchesTestCase(_ testCase: ConnectionStringTestCase) {
        // Assert that hosts match, if present.
        if let expectedHosts = testCase.hosts {
            let actualHosts = self.hosts
            for expectedHost in expectedHosts {
                guard actualHosts.contains(where: { expectedHost.matches($0) }) else {
                    XCTFail("No host found matching \(expectedHost) in host list \(actualHosts)")
                    return
                }
            }
        }

        // Assert that authentication information matches, if present.
        if let expectedAuth = testCase.auth {
            let actual = self.credential ?? MongoCredential()
            guard expectedAuth.matches(actual) else {
                XCTFail("Expected credentials: \(expectedAuth) do not match parsed credentials: \(actual)")
                return
            }
        }

        // Assert that options match, if present.
        if let expectedOptions = testCase.options {
            let actualOptions = self.options
            for (key, value) in expectedOptions {
                expect(actualOptions[key.lowercased()]).to(sortedEqual(value))
            }
        }
    }
}

final class ConnectionStringTests: MongoSwiftTestCase {
    func runTests(_ specName: String) throws {
        let testFiles = try retrieveSpecTestFiles(specName: specName, asType: ConnectionStringTestFile.self)
        for (filename, file) in testFiles {
            for testCase in file.tests {
                guard !shouldSkip(file: filename, test: testCase.description) else {
                    continue
                }

                // If the URI is invalid or is expected to emit a warning, expect an error to occur. Note that because
                // the driver does not implement logging, we throw errors where the spec indicates to log a warning.
                // TODO: SWIFT-511: revisit when we implement logging spec.
                guard testCase.valid && testCase.warning != true else {
                    expect(try MongoConnectionString(string: testCase.uri)).to(
                        throwError(
                            errorType: MongoError.InvalidArgumentError.self
                        ),
                        description: testCase.description
                    )
                    continue
                }

                // Assert that the MongoConnectionString matches the expected output.
                let connString = try MongoConnectionString(string: testCase.uri)
                connString.assertMatchesTestCase(testCase)

                // Assert that the URI successfully round-trips through the MongoConnectionString's description
                // property. Note that we cannot compare the description to the original URI directly because the
                // ordering of the options is not preserved.
                let connStringFromDescription = try MongoConnectionString(string: connString.description)
                connStringFromDescription.assertMatchesTestCase(testCase)
            }
        }
    }

    func testURIOptions() throws {
        try self.runTests("uri-options")
    }

    func testConnectionString() throws {
        try self.runTests("connection-string")
    }

    func testCodable() throws {
        let connStr = try MongoConnectionString(string: "mongodb://localhost:27017/")
        let encodedData = try JSONEncoder().encode(connStr)
        let decodedResult = try JSONDecoder().decode(MongoConnectionString.self, from: encodedData)
        expect(connStr.description).to(equal(decodedResult.description))
        expect(connStr.description).to(equal("mongodb://localhost:27017/"))
    }

    func testAppNameOption() throws {
        // option is set correctly from options struct
        let opts = MongoClientOptions(appName: "MyApp")
        var connStr1 = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr1.applyOptions(opts)
        expect(connStr1.appName).to(equal("MyApp"))

        // option is parsed correctly from string
        let connStr2 = try MongoConnectionString(string: "mongodb://localhost:27017/?appName=MyApp")
        expect(connStr2.appName).to(equal("MyApp"))

        // options struct overrides string
        var connStr3 = try MongoConnectionString(string: "mongodb://localhost:27017/?appName=MyApp2")
        try connStr3.applyOptions(opts)
        expect(connStr3.appName).to(equal("MyApp"))
    }

    func testReplSetOption() throws {
        // option is set correctly from options struct
        var opts = MongoClientOptions(replicaSet: "rs0")
        var connStr1 = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr1.applyOptions(opts)
        expect(connStr1.replicaSet).to(equal("rs0"))

        // option is parsed correctly from string
        let connStr2 = try MongoConnectionString(string: "mongodb://localhost:27017/?replicaSet=rs1")
        expect(connStr2.replicaSet).to(equal("rs1"))

        // options struct overrides string
        var connStr3 = try MongoConnectionString(string: "mongodb://localhost:27017/?replicaSet=rs1")
        try connStr3.applyOptions(opts)
        expect(connStr3.replicaSet).to(equal("rs0"))

        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print("Skipping rest of test because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let testConnStr = MongoSwiftTestCase.getConnectionString()
        let rsName = testConnStr.replicaSet!

        var connStrWithoutRS = testConnStr.description
        connStrWithoutRS.removeSubstring("replicaSet=\(rsName)")
        // need to delete the extra & in case replicaSet was first
        connStrWithoutRS = connStrWithoutRS.replacingOccurrences(of: "?&", with: "?")
        // need to delete the extra & in case replicaSet was between two options
        connStrWithoutRS = connStrWithoutRS.replacingOccurrences(of: "&&", with: "&")

        // setting actual name via options struct only should succeed in connecting
        opts.replicaSet = rsName
        try self.withTestClient(connStrWithoutRS, options: opts) { client in
            expect(try client.listDatabases().wait()).toNot(throwError())
        }

        // setting actual name via both client options and URI should succeed in connecting
        opts.replicaSet = rsName
        try self.withTestClient(testConnStr.description, options: opts) { client in
            expect(try client.listDatabases().wait()).toNot(throwError())
        }

        // setting to an incorrect repl set name via client options should fail to connect
        // speed up server selection timeout to fail faster
        opts.replicaSet! += "xyz"
        try self.withTestClient(testConnStr.description + "&serverSelectionTimeoutMS=1000", options: opts) { client in
            expect(try client.listDatabases().wait()).to(throwError())
        }
    }

    func testHeartbeatFrequencyMSOption() throws {
        // option is set correctly from options struct
        let opts1 = MongoClientOptions(heartbeatFrequencyMS: 50000)
        var connStr1 = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr1.applyOptions(opts1)
        expect(connStr1.options["heartbeatfrequencyms"]?.int32Value).to(equal(50000))

        // option is parsed correctly from string
        let connStr2 = try MongoConnectionString(string: "mongodb://localhost:27017/?heartbeatFrequencyMS=50000")
        expect(connStr2.options["heartbeatfrequencyms"]?.int32Value).to(equal(50000))

        // options struct overrides string
        var connStr3 = try MongoConnectionString(string: "mongodb://localhost:27017/?heartbeatFrequencyMS=20000")
        try connStr3.applyOptions(opts1)
        expect(connStr3.options["heartbeatfrequencyms"]?.int32Value).to(equal(50000))

        let tooSmall = 60

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?heartbeatFrequencyMS=\(tooSmall)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let opts2 = MongoClientOptions(heartbeatFrequencyMS: tooSmall)
        var connStr4 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr4.applyOptions(opts2)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        guard !MongoSwiftTestCase.is32Bit else {
            print("Skipping remainder of test, only supported on 64-bit platforms")
            return
        }

        let tooLarge = Int(Int32.max) + 1

        let opts3 = MongoClientOptions(heartbeatFrequencyMS: tooLarge)
        var connStr5 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr5.applyOptions(opts3)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?heartbeatFrequencyMS=\(tooLarge)"))
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

        let succeeded = watcher.succeeded

        // the last success time should be roughly 2s after the second-to-last succeeded time.
        // we can't use started events here because streamable monitor checks begin immediately after previous
        // ones succeed. They only fire success events every heartbeatFrequencyMS though.
        let lastSuccess = succeeded.last!
        let secondToLastSuccess = succeeded[succeeded.count - 2]

        let difference = lastSuccess.timeIntervalSince1970 - secondToLastSuccess.timeIntervalSince1970
        expect(difference).to(beCloseTo(2.0, within: 0.2))
    }

    func testServerSelectionTimeoutMS() throws {
        // option is set correctly from options struct
        let opts1 = MongoClientOptions(serverSelectionTimeoutMS: 10000)
        var connStr1 = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr1.applyOptions(opts1)
        expect(connStr1.options["serverselectiontimeoutms"]?.int32Value).to(equal(10000))

        // option is parsed correctly from string
        let connStr2 = try MongoConnectionString(string: "mongodb://localhost:27017/?serverSelectionTimeoutMS=10000")
        expect(connStr2.options["serverselectiontimeoutms"]?.int32Value).to(equal(10000))

        // options struct overrides string
        var connStr3 = try MongoConnectionString(string: "mongodb://localhost:27017/?serverSelectionTimeoutMS=5000")
        try connStr3.applyOptions(opts1)
        expect(connStr3.options["serverselectiontimeoutms"]?.int32Value).to(equal(10000))

        let tooSmall = 0

        let opts2 = MongoClientOptions(serverSelectionTimeoutMS: tooSmall)
        var connStr4 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr4.applyOptions(opts2)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        expect(try MongoConnectionString(
            string: "mongodb://localhost:27017/?serverSelectionTimeoutMS=\(tooSmall)"
        )).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        guard !MongoSwiftTestCase.is32Bit else {
            print("Skipping remainder of test, only supported on 64-bit platforms")
            return
        }

        let tooLarge = Int(Int32.max) + 1

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?serverSelectionTimeoutMS=\(tooLarge)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let opts3 = MongoClientOptions(serverSelectionTimeoutMS: tooLarge)
        var connStr5 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr5.applyOptions(opts3)).to(throwError(errorType: MongoError.InvalidArgumentError.self))
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
        let opts1 = MongoClientOptions(localThresholdMS: 100)
        var connStr1 = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr1.applyOptions(opts1)
        expect(connStr1.options["localthresholdms"]?.int32Value).to(equal(100))

        // option is parsed correctly from string
        let connStr2 = try MongoConnectionString(string: "mongodb://localhost:27017/?localThresholdMS=100")
        expect(connStr2.options["localthresholdms"]?.int32Value).to(equal(100))

        // options struct overrides string
        var connStr3 = try MongoConnectionString(string: "mongodb://localhost:27017/?localThresholdMS=50")
        try connStr3.applyOptions(opts1)
        expect(connStr3.options["localthresholdms"]?.int32Value).to(equal(100))

        let tooSmall = -10

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?localThresholdMS=\(tooSmall)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let opts2 = MongoClientOptions(localThresholdMS: tooSmall)
        var connStr4 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr4.applyOptions(opts2)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        guard !MongoSwiftTestCase.is32Bit else {
            print("Skipping remainder of test, requires 64-bit platform")
            return
        }

        let tooLarge = Int(Int32.max) + 1

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?localThresholdMS=\(tooLarge)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let opts3 = MongoClientOptions(localThresholdMS: tooLarge)
        var connStr5 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr5.applyOptions(opts3)).to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    func testConnectTimeoutMSOption() throws {
        // option is set correctly from options struct
        let opts1 = MongoClientOptions(connectTimeoutMS: 100)
        var connStr1 = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr1.applyOptions(opts1)
        expect(connStr1.options["connecttimeoutms"]?.int32Value).to(equal(100))

        // option is parsed correctly from string
        let connStr2 = try MongoConnectionString(string: "mongodb://localhost:27017/?connectTimeoutMS=100")
        expect(connStr2.options["connecttimeoutms"]?.int32Value).to(equal(100))

        // options struct overrides string
        var connStr3 = try MongoConnectionString(string: "mongodb://localhost:27017/?connectTimeoutMS=50")
        try connStr3.applyOptions(opts1)
        expect(connStr3.options["connecttimeoutms"]?.int32Value).to(equal(100))

        // test invalid options
        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?connectTimeoutMS=0"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let opts2 = MongoClientOptions(connectTimeoutMS: 0)
        var connStr4 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr4.applyOptions(opts2)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let tooSmall = -10

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?connectTimeoutMS=\(tooSmall)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let opts3 = MongoClientOptions(connectTimeoutMS: tooSmall)
        var connStr5 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr5.applyOptions(opts3)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        guard !MongoSwiftTestCase.is32Bit else {
            print("Skipping remainder of test, requires 64-bit platform")
            return
        }

        let tooLarge = Int(Int32.max) + 1

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?connectTimeoutMS=\(tooLarge)"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        let opts4 = MongoClientOptions(connectTimeoutMS: tooLarge)
        var connStr6 = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr6.applyOptions(opts4)).to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    func testUnsupportedOptions() throws {
        // options we know of but don't support yet should throw errors
        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?minPoolSize=10"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?maxIdleTimeMS=10"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?waitQueueMultiple=10"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?waitQueueTimeoutMS=10"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // options we don't know of should throw errors
        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?blah=10"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    func testCompressionOptions() throws {
        // zlib level validation
        expect(try Compressor.zlib(level: -2)).to(throwError(errorType: MongoError.InvalidArgumentError.self))
        expect(try Compressor.zlib(level: 10)).to(throwError(errorType: MongoError.InvalidArgumentError.self))
        expect(try Compressor.zlib(level: -1)).toNot(throwError())
        expect(try Compressor.zlib(level: 9)).toNot(throwError())

        // options are set correctly from options struct
        var opts = MongoClientOptions()
        opts.compressors = [.zlib]
        var connStr = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr.applyOptions(opts)
        expect(connStr.compressors).to(equal([.zlib]))

        opts.compressors = [try .zlib(level: 6)]
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connStr.applyOptions(opts)
        expect(connStr.compressors).to(equal([try .zlib(level: 6)]))

        // options parsed correctly from string
        connStr = try MongoConnectionString(
            string: "mongodb://localhost:27017/?compressors=zlib&zlibcompressionlevel=6"
        )
        expect(connStr.compressors).to(equal([try .zlib(level: 6)]))

        // options struct overrides string
        opts.compressors = []
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017/?compressors=zlib")
        try connStr.applyOptions(opts)
        expect(connStr.compressors).to(beEmpty())

        opts.compressors = [try .zlib(level: 6)]
        connStr = try MongoConnectionString(
            string: "mongodb://localhost:27017/?compressors=zlib&zlibcompressionlevel=4"
        )
        try connStr.applyOptions(opts)
        expect(connStr.compressors).to(equal([try .zlib(level: 6)]))

        // duplicate compressors should error
        opts.compressors = [.zlib, try .zlib(level: 1)]
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        expect(try MongoConnectionString(string: "mongodb://localhost:27017/?compressors=unsupported"))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    func testInvalidOptionsCombinations() throws {
        var opts: MongoClientOptions
        var connStr: MongoConnectionString

        // tlsInsecure and conflicting options
        opts = MongoClientOptions(tlsAllowInvalidCertificates: true, tlsInsecure: true)
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        opts = MongoClientOptions(tlsAllowInvalidHostnames: true, tlsInsecure: true)
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // one in URI, one in options struct
        opts = MongoClientOptions(tlsAllowInvalidCertificates: true)
        connStr = try MongoConnectionString(string: "mongodb://localhost:27107/?tlsInsecure=true")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        opts = MongoClientOptions(tlsAllowInvalidHostnames: true)
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        opts = MongoClientOptions(tlsInsecure: true)
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017/?tlsAllowInvalidHostnames=true")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        connStr = try MongoConnectionString(string: "mongodb://localhost:27017/?tlsAllowInvalidCertificates=true")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // directConnection cannot be used with SRV URIs
        opts = MongoClientOptions(directConnection: true)
        connStr = try MongoConnectionString(string: "mongodb+srv://test3.test.build.10gen.cc")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // directConnection=true cannot be used with multiple seeds
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017,localhost:27018")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // The cases where the conflicting options are all in the connection string are already covered by the URI
        // options tests, so here we only check behavior for cases where 1+ option is specified via the options struct.

        // loadBalanced=true cannot be used with multiple seeds
        opts = MongoClientOptions(loadBalanced: true)
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // loadBalanced=true cannot be used with replica set option
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017/?replicaSet=xyz")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        opts.replicaSet = "xyz"
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // loadBalanced=true cannot be used with directConnection=true
        opts = MongoClientOptions(directConnection: true, loadBalanced: true)
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        opts = MongoClientOptions(directConnection: true)
        connStr = try MongoConnectionString(string: "mongodb://localhost:27017/?loadBalanced=true")
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))

        opts = MongoClientOptions(loadBalanced: true)
        expect(try connStr.applyOptions(opts)).to(throwError(errorType: MongoError.InvalidArgumentError.self))
    }

    func testIPv4AddressParsing() throws {
        // valid IPv4
        let connString1 = try MongoConnectionString(string: "mongodb://1.2.3.4")
        guard let host = connString1.hosts.first else {
            XCTFail("connection string should contain one host")
            return
        }
        expect(host.host).to(equal("1.2.3.4"))
        expect(host.type).to(equal(.ipv4))
        // invalid IPv4 should fall back to hostname (only three numbers)
        let connString2 = try MongoConnectionString(string: "mongodb://1.2.3")
        guard let host = connString2.hosts.first else {
            XCTFail("connection string should contain one host")
            return
        }
        expect(host.host).to(equal("1.2.3"))
        expect(host.type).to(equal(.hostname))
        // invalid IPv4 should fall back to hostname (numbers out of bounds)
        let connString3 = try MongoConnectionString(string: "mongodb://256.1.2.3")
        guard let host = connString3.hosts.first else {
            XCTFail("connection string should contain one host")
            return
        }
        expect(host.host).to(equal("256.1.2.3"))
        expect(host.type).to(equal(.hostname))
    }

    func testAuthSourceInDescription() throws {
        // defaultAuthDB
        let connString1 = try MongoConnectionString(string: "mongodb://localhost:27017/test")
        expect(connString1.description).toNot(contain("authsource"))

        // authSource
        let connString2 = try MongoConnectionString(string: "mongodb://localhost:27017/?authSource=test")
        expect(connString2.description).to(contain("authsource=test"))

        // defaultAuthDB and authSource
        let connString3 = try MongoConnectionString(string: "mongodb://localhost:27017/admin?authSource=test")
        expect(connString3.description).to(contain("authsource=test"))

        // set from options
        let options = MongoClientOptions(credential: MongoCredential(source: "test"))
        var connString4 = try MongoConnectionString(string: "mongodb://localhost:27017")
        try connString4.applyOptions(options)
        expect(connString4.description).to(contain("authsource=test"))

        // set manually
        let credential1 = MongoCredential(username: "user", source: "test")
        var connString5 = try MongoConnectionString(string: "mongodb://localhost:27107")
        connString5.credential = credential1
        expect(connString5.description).to(contain("authsource=test"))

        // field changed to value
        let credential2 = MongoCredential(username: "user")
        var connString6 = try MongoConnectionString(string: "mongodb://localhost:27017")
        connString6.credential = credential2
        connString6.credential?.source = "test"
        expect(connString6.description).to(contain("authsource=test"))

        // field changed to nil
        let credential3 = MongoCredential(username: "user", source: "test")
        var connString7 = try MongoConnectionString(string: "mongodb://localhost:27107")
        connString7.credential = credential3
        connString7.credential?.source = nil
        expect(connString7.description).toNot(contain("authsource"))
    }
}
