import Foundation
@testable import MongoSwift
import Nimble
import NIO
import TestsCommon
import XCTest

final class ServerSelectionTests: MongoSwiftTestCase {
    func testServerSelection() throws {
        let standaloneServer = ServerDescription(type: .standalone)
        let rsPrimaryServer = ServerDescription(type: .rsPrimary)
        let rsSecondaryServer1 = ServerDescription(type: .rsSecondary)
        let rsSecondaryServer2 = ServerDescription(type: .rsSecondary)
        let mongosServer = ServerDescription(type: .mongos)

        // unknown
        let unkownTopology = TopologyDescription(type: .unknown, servers: [standaloneServer])
        expect(unkownTopology.findSuitableServers()).to(haveCount(0))

        // single
        let singleTopology = TopologyDescription(type: .single, servers: [standaloneServer])
        expect(singleTopology.findSuitableServers()[0].type).to(equal(.standalone))

        // replica set
        let replicaSetTopology = TopologyDescription(type: .replicaSetWithPrimary, servers: [
            rsPrimaryServer,
            rsSecondaryServer1,
            rsSecondaryServer2
        ])
        let primaryReadPreference = ReadPreference(.primary)
        let replicaSetSuitableServers = replicaSetTopology.findSuitableServers(readPreference: primaryReadPreference)
        expect(replicaSetSuitableServers[0].type)
            .to(equal(.rsPrimary))
        expect(replicaSetSuitableServers).to(haveCount(1))

        // sharded
        let shardedTopology = TopologyDescription(type: .sharded, servers: [
            mongosServer
        ])
        let shardedSuitableServers = shardedTopology.findSuitableServers()
        expect(shardedSuitableServers[0].type)
            .to(equal(.mongos))
        expect(shardedSuitableServers).to(haveCount(1))
    }
}
