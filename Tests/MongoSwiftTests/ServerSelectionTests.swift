import Foundation
@testable import MongoSwift
import Nimble
import NIO
import TestsCommon
import XCTest

private struct ServerSelectionLogicTestFile: Decodable {
    let topologyDescription: TopologyDescription
    let operation: String
    let readPreference: ReadPreference
    let suitableServers: [ServerDescription]
    let inLatencyWindow: [ServerDescription]

    enum CodingKeys: String, CodingKey {
        case topologyDescription = "topology_description", operation, readPreference = "read_preference",
             suitableServers = "suitable_servers", inLatencyWindow = "in_latency_window"
    }
}

final class ServerSelectionTests: MongoSwiftTestCase {
    func testServerSelectionLogic() throws {
        let tests = try retrieveSpecTestFiles(
            specName: "server-selection",
            subdirectory: "server_selection",
            asType: ServerSelectionLogicTestFile.self
        )
        for (filename, test) in tests {
            print("Running test from \(filename)...")
            // Server selection assumes that no read preference is passed for write operations.
            let readPreference = test.operation == "read" ? test.readPreference : nil
            let selectedServers = test.topologyDescription.findSuitableServers(readPreference: readPreference)
            expect(selectedServers.count).to(equal(test.suitableServers.count))
            expect(selectedServers).to(contain(test.suitableServers))
        }
    }
}
