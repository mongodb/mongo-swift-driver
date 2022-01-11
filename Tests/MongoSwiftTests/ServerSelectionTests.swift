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

        // replica set with primary
        let replicaSetTopology = TopologyDescription(type: .replicaSetWithPrimary, servers: [
            rsPrimaryServer,
            rsSecondaryServer1,
            rsSecondaryServer2
        ])
        let primaryReadPreference = ReadPreference(.primary)
        let replicaSetSuitableServers = replicaSetTopology.findSuitableServers(readPreference: primaryReadPreference)
        expect(replicaSetSuitableServers[0].type).to(equal(.rsPrimary))
        expect(replicaSetSuitableServers).to(haveCount(1))

        let primaryPrefReadPreferemce = ReadPreference(.primaryPreferred)
        let replicaSetSuitableServers2 = replicaSetTopology
            .findSuitableServers(readPreference: primaryPrefReadPreferemce)
        expect(replicaSetSuitableServers2[0].type).to(equal(.rsPrimary))
        expect(replicaSetSuitableServers2).to(haveCount(1))

        // replica set without primary
        let replicaSetNoPrimaryTopology = TopologyDescription(type: .replicaSetNoPrimary, servers: [
            rsSecondaryServer1,
            rsSecondaryServer2
        ])
        let replicaSetNoPrimarySuitableServers = replicaSetNoPrimaryTopology
            .findSuitableServers(readPreference: primaryReadPreference)
        expect(replicaSetNoPrimarySuitableServers).to(haveCount(0))

        let replicaSetNoPrimarySuitableServer2 = replicaSetNoPrimaryTopology.findSuitableServers(readPreference: nil)
        expect(replicaSetNoPrimarySuitableServer2).to(haveCount(0))

        let replicaSetNoPrimarySuitableServer3 = replicaSetNoPrimaryTopology
            .findSuitableServers(readPreference: primaryPrefReadPreferemce)
        expect(replicaSetNoPrimarySuitableServer3[0].type).to(equal(.rsSecondary))
        expect(replicaSetNoPrimarySuitableServer3).to(haveCount(2))

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
