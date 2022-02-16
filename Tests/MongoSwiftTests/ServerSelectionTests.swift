#if compiler(>=5.3)
import Foundation
@testable import MongoSwift
import Nimble
import NIO
import TestsCommon
import XCTest

private struct ServerSelectionTestFile: Decodable {
    let topologyDescription: TopologyDescription
    let operation: OperationType?
    let readPreference: ReadPreference
    let suitableServers: [ServerDescription]?
    let inLatencyWindow: [ServerDescription]?

    // additional fields for the max staleness tests
    let error: Bool?
    let heartbeatFrequencyMS: Int?

    enum CodingKeys: String, CodingKey {
        case topologyDescription = "topology_description", operation, readPreference = "read_preference",
             suitableServers = "suitable_servers", inLatencyWindow = "in_latency_window", error, heartbeatFrequencyMS
    }
}

private enum OperationType: String, Decodable {
    case read, write
}

private struct RTTCalculationTestFile: Decodable {
    let averageRoundTripTimeMS: Double?
    let newRoundTripTimeMS: Double
    let newAverageRoundTripTimeMS: Double

    enum CodingKeys: String, CodingKey {
        case averageRoundTripTimeMS = "avg_rtt_ms", newRoundTripTimeMS = "new_rtt_ms",
             newAverageRoundTripTimeMS = "new_avg_rtt"
    }

    internal init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // The tests specify a non-present initial average RTT as "NULL", so if decoding to a Double fails, ignore and
        // set to nil.
        self.averageRoundTripTimeMS = try? values.decode(Double.self, forKey: .averageRoundTripTimeMS)
        self.newRoundTripTimeMS = try values.decode(Double.self, forKey: .newRoundTripTimeMS)
        self.newAverageRoundTripTimeMS = try values.decode(Double.self, forKey: .newAverageRoundTripTimeMS)
    }
}

private struct SelectionWithinLatencyWindowTest: Decodable {
    let topologyDescription: TopologyDescription
    let mockedTopologyState: [TestServer]
    let iterations: Int
    let outcome: Outcome

    fileprivate struct TestServer: Decodable {
        let address: ServerAddress
        let operationCount: Int

        enum CodingKeys: String, CodingKey {
            case address, operationCount = "operation_count"
        }
    }

    fileprivate struct Outcome: Decodable {
        let tolerance: Double
        let expectedFrequencies: [ServerAddress: Double]

        enum CodingKeys: String, CodingKey {
            case tolerance, expectedFrequencies = "expected_frequencies"
        }

        internal init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            self.tolerance = try values.decode(Double.self, forKey: .tolerance)
            let expectedFrequenciesDocument = try values.decode(BSONDocument.self, forKey: .expectedFrequencies)
            self.expectedFrequencies = try expectedFrequenciesDocument.reduce(into: [ServerAddress: Double]()) {
                let (addressString, frequencyBSONValue) = $1
                let address = try ServerAddress(addressString)
                guard let frequency = frequencyBSONValue.toDouble() else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .expectedFrequencies,
                        in: values,
                        debugDescription: "a server's expected frequency must be specified as a number"
                    )
                }
                $0[address] = frequency
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case topologyDescription = "topology_description", mockedTopologyState = "mocked_topology_state", iterations,
             outcome
    }
}

final class ServerSelectionTests: MongoSwiftTestCase {
    private func runTests(_ tests: [(String, ServerSelectionTestFile)]) throws {
        for (filename, test) in tests {
            print("Running test from \(filename)...")

            // Server selection assumes that a primary read preference is passed for write operations.
            let readPreference = test.operation == .write ? ReadPreference.primary : test.readPreference
            let heartbeatFrequencyMS = test.heartbeatFrequencyMS ?? SDAMConstants.defaultHeartbeatFrequencyMS

            var selectedServers: [ServerDescription]
            do {
                selectedServers = try test.topologyDescription.findSuitableServers(
                    readPreference: readPreference,
                    heartbeatFrequencyMS: heartbeatFrequencyMS
                )
            } catch where test.error != true {
                throw error
            } catch {
                // The error field is used by the max staleness tests to assert that an error is thrown for an invalid
                // maxStalenessSeconds value.
                expect(error).to(beAnInstanceOf(MongoError.InvalidArgumentError.self))
                continue
            }

            if let suitableServers = test.suitableServers {
                expect(selectedServers.count).to(equal(suitableServers.count))
                expect(selectedServers).to(contain(suitableServers))
            }

            if let inLatencyWindow = test.inLatencyWindow {
                selectedServers.filterByLatency(localThresholdMS: nil)
                expect(selectedServers.count).to(equal(inLatencyWindow.count))
                expect(selectedServers).to(contain(inLatencyWindow))
            }
        }
    }

    func testServerSelectionLogic() throws {
        let tests = try retrieveSpecTestFiles(
            specName: "server-selection",
            subdirectory: "server_selection",
            asType: ServerSelectionTestFile.self
        )
        try runTests(tests)
    }

    func testMaxStaleness() throws {
        let tests = try retrieveSpecTestFiles(specName: "max-staleness", asType: ServerSelectionTestFile.self)
        try runTests(tests)
    }

    func testRoundTripTimeCalculation() throws {
        let tests = try retrieveSpecTestFiles(
            specName: "server-selection",
            subdirectory: "rtt",
            asType: RTTCalculationTestFile.self
        )
        for (filename, test) in tests {
            print("Running test from \(filename)...")
            var serverDescription = ServerDescription(averageRoundTripTimeMS: test.averageRoundTripTimeMS)
            serverDescription.updateAverageRoundTripTime(roundTripTime: test.newRoundTripTimeMS)
            expect(serverDescription.averageRoundTripTimeMS).to(equal(test.newAverageRoundTripTimeMS))
        }
    }

    func testSelectionWithinLatencyWindow() throws {
        let tests = try retrieveSpecTestFiles(
            specName: "server-selection",
            subdirectory: "in_window",
            asType: SelectionWithinLatencyWindowTest.self
        )
        for (filename, test) in tests {
            print("Running test from \(filename)...")
            try self.withTestClient { client in
                var selectedServerCounts: [ServerAddress: Int] = [:]
                let readPreference = ReadPreference.nearest
                for _ in 1...test.iterations {
                    // The servers need to be created during each round of iteration to avoid the incremented operation
                    // count of the server selected in the previous iteration carrying over to the next one.
                    let servers = test.mockedTopologyState.reduce(into: [ServerAddress: Server]()) {
                        $0[$1.address] = Server(address: $1.address, operationCount: $1.operationCount)
                    }
                    let selectedServer = try client.selectServer(
                        readPreference: readPreference,
                        topology: test.topologyDescription,
                        servers: servers
                    )
                    let count = selectedServerCounts[selectedServer.address] ?? 0
                    selectedServerCounts[selectedServer.address] = count + 1
                }

                let selectedServerFrequencies = selectedServerCounts.reduce(into: [ServerAddress: Double]()) {
                    let (address, frequency) = $1
                    $0[address] = Double(frequency) / Double(test.iterations)
                }
                for (address, expectedFrequency) in test.outcome.expectedFrequencies {
                    if expectedFrequency == 0 {
                        expect(selectedServerFrequencies[address]).to(beNil())
                    } else {
                        // From the test spec: "If the expected frequency for a given server is 1 or 0, then the
                        // observed frequency MUST be exactly equal to the expected one."
                        let tolerance = expectedFrequency == 1 ? 0 : test.outcome.tolerance
                        guard let actualFrequency = selectedServerFrequencies[address] else {
                            XCTFail("Server of address \(address) was never selected but was expected to be selected"
                                + " with a frequency of \(expectedFrequency)")
                            return
                        }
                        let deviation = (actualFrequency - expectedFrequency).magnitude
                        expect(deviation).to(beLessThanOrEqualTo(tolerance))
                    }
                }
            }
        }
    }

    func testReadPreferenceValidation() throws {
        var readPreference = ReadPreference.primary
        readPreference.tagSets = [["tag": "set"]]
        let topology = TopologyDescription(type: .single, servers: [])
        expect(try topology.findSuitableServers(readPreference: readPreference, heartbeatFrequencyMS: 0))
            .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        readPreference.tagSets = [[:]]
        expect(try topology.findSuitableServers(readPreference: readPreference, heartbeatFrequencyMS: 0))
            .toNot(throwError())

        readPreference.tagSets = nil
        expect(try topology.findSuitableServers(readPreference: readPreference, heartbeatFrequencyMS: 0))
            .toNot(throwError())
    }

    // TODO: SWIFT-1496: Implement the remaining server selection tests
}
#endif
