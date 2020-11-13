import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

/// Represents a single test file.
struct DNSSeedlistTestCase: Decodable {
    /// A mongodb+srv connection string.
    let uri: String
    /// The expected set of initial seeds discovered from the SRV record.
    let seeds: [String]
    /// The discovered topology's list of hosts once SDAM completes a scan.
    let hosts: [ServerAddress]
    /// The parsed connection string options as discovered from URI and TXT records.
    let options: BSONDocument?
    /// Additional options present in the connection string URI such as Userinfo (as user and password), and Auth
    /// database (as auth_database).
    let parsedOptions: BSONDocument?
    /// Indicates that the parsing of the URI, or the resolving or contents of the SRV or TXT records included errors.
    let error: Bool?
    /// A comment to indicate why a test would fail.
    let comment: String?

    private enum CodingKeys: String, CodingKey {
        case uri, seeds, hosts, options, parsedOptions = "parsed_options", error, comment
    }
}

final class DNSSeedlistTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    fileprivate class TopologyDescriptionWatcher: SDAMEventHandler {
        fileprivate var lastTopologyDescription: TopologyDescription?

        // listen for TopologyDescriptionChanged events and continually record the latest description we've seen.
        func handleSDAMEvent(_ event: SDAMEvent) {
            guard case let .topologyDescriptionChanged(event) = event else {
                return
            }
            self.lastTopologyDescription = event.newDescription
        }
    }

    // Note: the file txt-record-with-overridden-uri-option.json causes a mongoc warning. This is expected.
    // swiftlint:disable:next cyclomatic_complexity
    func testInitialDNSSeedlistDiscovery() throws {
        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print("Skipping test because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let tests = try retrieveSpecTestFiles(
            specName: "initial-dns-seedlist-discovery",
            asType: DNSSeedlistTestCase.self
        )
        for (fileName, testCase) in tests {
            // TODO: SWIFT-910: unskip this test
            guard fileName != "txt-record-with-overridden-uri-option.json" else {
                print("Skipping test file \(fileName); see SWIFT-910")
                continue
            }

            // this particular test case requires SSL is disabled. see DRIVERS-1324.
            let requiresTLS = fileName != "txt-record-with-overridden-ssl-option.json"

            // TLS requirement for this test case is not met.
            guard (requiresTLS && MongoSwiftTestCase.ssl) || (!requiresTLS && !MongoSwiftTestCase.ssl) else {
                print("Skipping test file \(fileName); TLS requirement not met")
                continue
            }

            print("Running test file \(fileName)...")

            let topologyWatcher = TopologyDescriptionWatcher()

            let opts: MongoClientOptions?
            if requiresTLS {
                opts = MongoClientOptions(tlsAllowInvalidCertificates: true)
            } else {
                opts = nil
            }
            do {
                try self.withTestClient(testCase.uri, options: opts) { client in
                    client.addSDAMEventHandler(topologyWatcher)

                    // try selecting a server to trigger SDAM
                    _ = try client.connectionPool.selectServer(forWrites: false)

                    // get resolved connection string after SDAM has been started.
                    let connStr = try client.connectionPool.getConnectionString()

                    guard testCase.error != true else {
                        XCTFail("Expected error for test case \(testCase.comment ?? ""), got none")
                        return
                    }

                    // "You MUST verify that the set of ServerDescriptions in the client's TopologyDescription
                    // eventually matches the list of hosts."
                    // This needs to be done before the client leaves scope to ensure the SDAM machinery
                    // keeps running.
                    expect(topologyWatcher.lastTopologyDescription?.servers.map(\.address))
                        .toEventually(equal(testCase.hosts), timeout: 5)

                    // "You MUST verify that each of the values of the Connection String Options under options match the
                    // Client's parsed value for that option."
                    let connStrOptions = connStr.options ?? [:]
                    for (k, v) in Array(testCase.options ?? [:]) + Array(testCase.parsedOptions ?? [:]) {
                        switch k {
                        // the test files still use SSL, but libmongoc uses TLS
                        case "ssl":
                            expect(connStrOptions["tls"]).to(equal(v))
                        // these values are not returned as part of the options doc
                        case "authSource", "auth_database":
                            expect(connStr.authSource).to(equal(v.stringValue))
                        case "user":
                            expect(connStr.username).to(equal(v.stringValue))
                        case "password":
                            expect(connStr.password).to(equal(v.stringValue))
                        case "db":
                            expect(connStr.db).to(equal(v.stringValue))
                        default:
                            // there are some case inconsistencies between the tests and libmongoc
                            expect(connStrOptions[k.lowercased()]).to(equal(v))
                        }
                    }

                    // Note: we skip this assertion: "You SHOULD verify that the client's initial seed list matches the
                    // list of seeds." mongoc doesn't make this assertion in their test runner either.
                }
            } catch where testCase.error != true {
                XCTFail("Expected no error for test case \(testCase.comment ?? ""), got \(error)")
                continue
            } catch {
                continue
            }
        }
    }
}
