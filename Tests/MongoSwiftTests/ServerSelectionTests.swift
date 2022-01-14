import Foundation
@testable import MongoSwift
import Nimble
import NIO
import TestsCommon
import XCTest

final class ServerSelectionTests: MongoSwiftTestCase {
    // Servers
    let standaloneServer = ServerDescription(type: .standalone)
    let rsPrimaryServer = ServerDescription(type: .rsPrimary)
    let rsSecondaryServer1 = ServerDescription(type: .rsSecondary, tags: ["dc": "ny", "rack": "2", "size": "large"])
    let rsSecondaryServer2 = ServerDescription(type: .rsSecondary)
    let rsSecondaryServer3 = ServerDescription(type: .rsSecondary, tags: ["dc": "ny", "rack": "3", "size": "small"])
    let mongosServer = ServerDescription(type: .mongos)

    // Read Preferences
    let primaryReadPreference = ReadPreference(.primary)
    let primaryPrefReadPreferemce = ReadPreference(.primaryPreferred)

    // Tag Sets
    let tagSet: BSONDocument = ["dc": "ny", "rack": "2"]
    let tagSet2: BSONDocument = ["dc": "ny"]
    let tagSet3: BSONDocument = ["size": "small"]

    func testUnknownTopology() throws {
        let unkownTopology = TopologyDescription(type: .unknown, servers: [standaloneServer])
        expect(try unkownTopology.findSuitableServers()).to(haveCount(0))
    }

    func testSingleTopology() throws {
        let singleTopology = TopologyDescription(type: .single, servers: [standaloneServer])
        expect(try singleTopology.findSuitableServers()[0].type).to(equal(.standalone))
    }

    func testReplicaSetWithPrimaryTopology() throws {
        let replicaSetTopology = TopologyDescription(type: .replicaSetWithPrimary, servers: [
            rsPrimaryServer,
            rsSecondaryServer1,
            rsSecondaryServer2
        ])
        let replicaSetSuitableServers = try replicaSetTopology
            .findSuitableServers(readPreference: self.primaryReadPreference)
        expect(replicaSetSuitableServers[0].type).to(equal(.rsPrimary))
        expect(replicaSetSuitableServers).to(haveCount(1))

        let replicaSetSuitableServers2 = try replicaSetTopology
            .findSuitableServers(readPreference: self.primaryPrefReadPreferemce)
        expect(replicaSetSuitableServers2[0].type).to(equal(.rsPrimary))
        expect(replicaSetSuitableServers2).to(haveCount(1))
    }

    func testReplicaSetNoPrimaryTopology() throws {
        let replicaSetNoPrimaryTopology = TopologyDescription(type: .replicaSetNoPrimary, servers: [
            rsSecondaryServer1,
            rsSecondaryServer2
        ])
        let suitable1 = try replicaSetNoPrimaryTopology
            .findSuitableServers(readPreference: self.primaryReadPreference)
        expect(suitable1).to(haveCount(0))

        let suitable2 = try replicaSetNoPrimaryTopology
            .findSuitableServers(readPreference: nil)
        expect(suitable2).to(haveCount(0))

        let suitable3 = try replicaSetNoPrimaryTopology
            .findSuitableServers(readPreference: self.primaryPrefReadPreferemce)
        expect(suitable3[0].type).to(equal(.rsSecondary))
        expect(suitable3).to(haveCount(2))
    }

    func testShardedTopology() throws {
        let shardedTopology = TopologyDescription(type: .sharded, servers: [
            mongosServer
        ])
        let shardedSuitableServers = try shardedTopology.findSuitableServers()
        expect(shardedSuitableServers[0].type)
            .to(equal(.mongos))
        expect(shardedSuitableServers).to(haveCount(1))
    }

    func testTagSets() throws {
        // tag set 1
        let topology = TopologyDescription(type: .replicaSetNoPrimary, servers: [
            rsSecondaryServer1,
            rsSecondaryServer2,
            rsSecondaryServer3
        ])
        let secondaryReadPreferenceWithTagSet = try ReadPreference(
            .secondaryPreferred,
            tagSets: [tagSet, tagSet3], // tagSet3 should be ignored, because tagSet matches some servers
            maxStalenessSeconds: nil
        )

        let suitable = try topology
            .findSuitableServers(readPreference: secondaryReadPreferenceWithTagSet)
        expect(suitable[0].type).to(equal(.rsSecondary))
        expect(suitable).to(haveCount(1))

        // tag set 2
        let secondaryReadPreferenceWithTagSet2 = try ReadPreference(
            .secondaryPreferred,
            tagSets: [tagSet2],
            maxStalenessSeconds: nil
        )

        let suitable2 = try topology
            .findSuitableServers(readPreference: secondaryReadPreferenceWithTagSet2)
        expect(suitable2[0].type).to(equal(.rsSecondary))
        expect(suitable2).to(haveCount(2))

        // invalid tag set passing
        expect(try ReadPreference(
            .primary,
            tagSets: [self.tagSet],
            maxStalenessSeconds: nil
        ))
        .to(throwError(errorType: MongoError.InvalidArgumentError.self))

        // valid tag set passing
        let replicaSetTopology = TopologyDescription(type: .replicaSetWithPrimary, servers: [
            rsPrimaryServer,
            rsSecondaryServer1,
            rsSecondaryServer2
        ])

        let emptyTagSet: BSONDocument = [:]

        let primaryReadPreferenceWithEmptyTagSet = try ReadPreference(
            .primary,
            tagSets: [emptyTagSet],
            maxStalenessSeconds: nil
        )
        let replicaSetSuitableServers = try replicaSetTopology
            .findSuitableServers(readPreference: primaryReadPreferenceWithEmptyTagSet)
        expect(replicaSetSuitableServers[0].type).to(equal(.rsPrimary))
        expect(replicaSetSuitableServers).to(haveCount(1))
    }
}
