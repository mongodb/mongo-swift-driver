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

final class ServerSelectionTests: MongoSwiftTestCase {
    fileprivate func runTests(_ tests: [(String, ServerSelectionTestFile)]) throws {
        for (filename, test) in tests {
            print("Running test from \(filename)...")

            // Server selection assumes that no read preference is passed for write operations.
            let readPreference = test.operation == .write ? nil : test.readPreference
            let heartbeatFrequencyMS = test.heartbeatFrequencyMS ?? SDAMConstants.defaultHeartbeatFrequencyMS

            let selectedServers: [ServerDescription]
            do {
                selectedServers = try test.topologyDescription.findSuitableServers(
                    readPreference: readPreference,
                    heartbeatFrequencyMS: heartbeatFrequencyMS
                )
            } catch where test.error != true {
                throw error
            } catch {
                continue
            }

            if let suitableServers = test.suitableServers {
                expect(selectedServers.count).to(equal(suitableServers.count))
                expect(selectedServers).to(contain(suitableServers))
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
}
