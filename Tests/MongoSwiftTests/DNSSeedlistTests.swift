import Foundation
@testable import MongoSwift
import Nimble
import XCTest

/// Represents a single test file.
struct DNSSeedlistTestCase: Decodable {
    /// A mongodb+srv connection string.
    let uri: String
    /// The expected set of initial seeds discovered from the SRV record.
    let seeds: [String]
    /// The discovered topology's list of hosts once SDAM completes a scan.
    let hosts: [ConnectionId]
    /// The parsed connection string options as discovered from URI and TXT records.
    let options: Document?
    /// Additional options present in the connection string URI such as Userinfo (as user and password), and Auth
    /// database (as auth_database).
    let parsedOptions: Document?
    /// Indicates that the parsing of the URI, or the resolving or contents of the SRV or TXT records included errors.
    let error: Bool?
    /// A comment to indicate why a test would fail.
    let comment: String?
}

/// Makes `ConnectionId` `Decodable` for the sake of constructing it from the test files.
extension ConnectionId: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hostPortPair = try container.decode(String.self)
        self.init(hostPortPair)
    }
}

final class DNSSeedlistTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    // Note: the file txt-record-with-overridden-uri-option.json causes a mongoc warning. This is expected.
    func testInitialDNSSeedlistDiscovery() throws {
        guard MongoSwiftTestCase.ssl else {
            print("Skipping test, requires SSL")
            return
        }
        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let specsPath = MongoSwiftTestCase.specsPath + "/initial-dns-seedlist-discovery/tests"
        let testFiles = try FileManager.default.contentsOfDirectory(atPath: specsPath).filter { $0.hasSuffix(".json") }
        for filename in testFiles {
            // TODO SWIFT-593: run these tests
            guard !["encoded-userinfo-and-db.json", "uri-with-auth.json"].contains(filename) else {
                continue
            }

            let testFilePath = URL(fileURLWithPath: "\(specsPath)/\(filename)")
            let testDocument = try Document(fromJSONFile: testFilePath)
            let testCase = try BSONDecoder().decode(DNSSeedlistTestCase.self, from: testDocument)

            // listen for TopologyDescriptionChanged events and continually record the latest description we've seen.
            let center = NotificationCenter.default
            var lastTopologyDescription: TopologyDescription?
            let observer = center.addObserver(forName: .topologyDescriptionChanged, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? TopologyDescriptionChangedEvent else {
                    XCTFail("unexpected event \(notif.userInfo?["event"] ?? "nil")")
                    return
                }
                lastTopologyDescription = event.newDescription
            }
            defer { center.removeObserver(observer) }

            // Enclose all of the potentially throwing code in `doTest`. Sometimes the expected errors come when
            // parsing the URI, and other times they are not until we try to send a command.
            func doTest() throws {
                let opts = TLSOptions(pemFile: URL(string: MongoSwiftTestCase.sslPEMKeyFilePath ?? ""),
                                      caFile: URL(string: MongoSwiftTestCase.sslCAFilePath ?? ""),
                                      allowInvalidHostnames: true)
                let client = try MongoClient(testCase.uri,
                                             options: ClientOptions(serverMonitoring: true, tlsOptions: opts))

                // mongoc connects lazily so we need to send a command.
                let db = client.db("test")
                _ = try db.runCommand(["isMaster": 1])
            }

            // "You MUST verify that an error has been thrown if error is present."
            if testCase.error == true {
                expect(try doTest()).to(throwError(), description: testCase.comment ?? "")
                continue
            }

            expect(try doTest()).toNot(throwError(), description: testCase.comment ?? "")

            // "You MUST verify that the set of ServerDescriptions in the client's TopologyDescription eventually
            // matches the list of hosts."
            expect(lastTopologyDescription?.servers.map { $0.connectionId }).toEventually(equal(testCase.hosts))

            // "You MUST verify that each of the values of the Connection String Options under options match the
            // Client's parsed value for that option."
            // TODO SWIFT-597: Implement these assertions. Not possible now.

            // Note: we also skip this assertion: "You SHOULD verify that the client's initial seed list matches the
            // list of seeds." mongoc doesn't make this assertion in their test runner either.
        }
    }
}
