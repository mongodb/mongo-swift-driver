import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class SDAMTests: MongoSwiftTestCase {
    static var allTests: [(String, (SDAMTests) -> () throws -> Void)] {
        return [
            ("testMonitoring", testMonitoring),
            ("testHasReadableServers", testHasReadableServers)
        ]
    }

    override func setUp() {
        self.continueAfterFailure = false
    }

    func checkEmptyLists(_ desc: ServerDescription) {
        expect(desc.arbiters).to(haveCount(0))
        expect(desc.hosts).to(haveCount(0))
        expect(desc.passives).to(haveCount(0))
    }

    func checkUnknownServerType(_ desc: ServerDescription) {
        expect(desc.type).to(equal(ServerType.unknown))
    }

    func checkDefaultHostPort(_ desc: ServerDescription, _ hostlist: UnsafePointer<mongoc_host_list_t>) {
        expect(desc.connectionId).to(equal(ConnectionId(hostlist)))
    }

    // Basic test based on the "standalone" spec test for SDAM monitoring:
    // swiftlint:disable line_length
    // https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/tests/monitoring/standalone.json
    // swiftlint:enable line_length
    func testMonitoring() throws {
        let client = try MongoClient(options: ClientOptions(eventMonitoring: true))
        client.enableMonitoring(forEvents: .serverMonitoring)

        let center = NotificationCenter.default
        var receivedEvents = [MongoEvent]()

        let observer = center.addObserver(forName: nil, object: nil, queue: nil) { (notif) in

            guard ["serverDescriptionChanged", "serverOpening", "serverClosed", "topologyDescriptionChanged",
                "topologyOpening", "topologyClosed"].contains(notif.name.rawValue) else { return }

            guard let event = notif.userInfo?["event"] as? MongoEvent else {
                XCTFail("Notification \(notif) did not contain an event")
                return
            }

            receivedEvents.append(event)
        }
        // do some basic operations
        let db = try client.db("testing")
        _ = try db.createCollection("testColl")
        try db.drop()

        center.removeObserver(observer)

        var error = bson_error_t()
        guard let uri = mongoc_uri_new_with_error(MongoSwiftTestCase.connStr, &error) else {
            XCTFail(toErrorString(error))
            return
        }

        guard let hostlist = mongoc_uri_get_hosts(uri) else {
            XCTFail("Could not get hostlists for uri: \(uri)")
            return
        }

        // check event count and that events are of the expected types
        expect(receivedEvents.count).to(equal(5))
        expect(receivedEvents[0]).to(beAnInstanceOf(TopologyOpeningEvent.self))
        expect(receivedEvents[1]).to(beAnInstanceOf(TopologyDescriptionChangedEvent.self))
        expect(receivedEvents[2]).to(beAnInstanceOf(ServerOpeningEvent.self))
        expect(receivedEvents[3]).to(beAnInstanceOf(ServerDescriptionChangedEvent.self))
        expect(receivedEvents[4]).to(beAnInstanceOf(TopologyDescriptionChangedEvent.self))

        // verify that data in ServerDescription and TopologyDescription looks reasonable
        let event0 = receivedEvents[0] as! TopologyOpeningEvent
        expect(event0.topologyId).toNot(beNil())

        let event1 = receivedEvents[1] as! TopologyDescriptionChangedEvent
        expect(event1.topologyId).to(equal(event0.topologyId))
        expect(event1.previousDescription.type).to(equal(TopologyType.unknown))
        expect(event1.newDescription.type).to(equal(TopologyType.single))
        // This is a bit of a deviation from the SDAM spec tests linked above. However, this is how mongoc responds so
        // there is no other way to get around this.
        expect(event1.newDescription.servers).to(beEmpty())

        let event2 = receivedEvents[2] as! ServerOpeningEvent
        expect(event2.topologyId).to(equal(event1.topologyId))
        expect(event2.connectionId).to(equal(ConnectionId(hostlist)))

        let event3 = receivedEvents[3] as! ServerDescriptionChangedEvent
        expect(event3.topologyId).to(equal(event2.topologyId))
        let prevServer = event3.previousDescription
        checkDefaultHostPort(prevServer, hostlist)
        checkEmptyLists(prevServer)
        checkUnknownServerType(prevServer)

        let newServer = event3.newDescription
        checkDefaultHostPort(newServer, hostlist)
        checkEmptyLists(newServer)
        expect(newServer.type).to(equal(ServerType.standalone))

        let event4 = receivedEvents[4] as! TopologyDescriptionChangedEvent
        expect(event4.topologyId).to(equal(event3.topologyId))
        let prevTopology = event4.previousDescription
        expect(prevTopology.type).to(equal(TopologyType.single))
        expect(prevTopology.servers).to(beEmpty())

        let newTopology = event4.newDescription
        expect(newTopology.type).to(equal(TopologyType.single))
        checkDefaultHostPort(newTopology.servers[0], hostlist)
        expect(newTopology.servers[0].type).to(equal(ServerType.standalone))
        checkEmptyLists(newTopology.servers[0])
    }

    // Test based on some of the max staleness spec tests.
    // See: https://github.com/mongodb/specifications/tree/master/source/max-staleness/tests
    func testMaxStaleness() throws {
        let makeServerDescription = { (id: String,
                                       type: ServerType,
                                       lastUpdateTime: TimeInterval,
                                       lastWrite: TimeInterval) -> ServerDescription in

            let lastWriteDate = Date(timeIntervalSinceReferenceDate: lastWrite)
            let ismaster: Document = ["lastWrite": ["lastWriteDate": lastWriteDate] as Document]

            return ServerDescription(
                    connectionId: ConnectionId(id),
                    type: type,
                    isMaster: ismaster,
                    updateTime: Date(timeIntervalSinceReferenceDate: lastUpdateTime))
        }

        var topology: TopologyDescription
        var servers: [ServerDescription] = []
        var maxStalenessSeconds = 150.0

        // ReplicaSetWithPrimary

        // "lastUpdateTime" test
        TopologyDescription.heartbeatFrequencyMS = 25000
        maxStalenessSeconds = 150.0
        servers = [
            makeServerDescription("a:1", .rsPrimary, 0.001, 0.002),
            makeServerDescription("b:1", .rsSecondary, 125.001, 0.002),
            makeServerDescription("c:1", .rsSecondary, 125.001, 0.001)
        ]
        topology = TopologyDescription(type: .replicaSetWithPrimary, servers: servers)

        expect(topology.staleness(for: servers[0])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[1])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[2])) > maxStalenessSeconds

        // "LongHeartbeat" test
        TopologyDescription.heartbeatFrequencyMS = 120000 // 120 seconds
        maxStalenessSeconds = 130.0
        servers = [
            makeServerDescription("a:1", .rsPrimary, 0.0, 0.001),
            makeServerDescription("b:1", .rsSecondary, 0.0, 0.001)
        ]
        topology = TopologyDescription(type: .replicaSetWithPrimary, servers: servers)

        expect(topology.staleness(for: servers[0])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[1])) <= maxStalenessSeconds

        // "Nearest" test
        TopologyDescription.heartbeatFrequencyMS = 25000 // 25 seconds
        maxStalenessSeconds = 150.0
        servers = [
            makeServerDescription("a:1", .rsPrimary, 0.0, 125.002),
            makeServerDescription("b:1", .rsSecondary, 0.0, 0.002),
            makeServerDescription("c:1", .rsSecondary, 0.0, 0.001)
        ]
        topology = TopologyDescription(type: .replicaSetWithPrimary, servers: servers)

        expect(topology.staleness(for: servers[0])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[1])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[2])) > maxStalenessSeconds

        // ReplicaSetNoPrimary

        // "LastUpdateTime" test
        TopologyDescription.heartbeatFrequencyMS = 25000 // 25 seconds
        maxStalenessSeconds = 150.0
        servers = [
            makeServerDescription("a:1", .rsSecondary, 0.001, 125.002),
            makeServerDescription("b:1", .rsSecondary, 25.002, 0.002),
            makeServerDescription("c:1", .rsSecondary, 25.001, 0.001)
        ]
        topology = TopologyDescription(type: .replicaSetNoPrimary, servers: servers)

        expect(topology.staleness(for: servers[0])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[1])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[2])) > maxStalenessSeconds

        // "Nearest" test
        TopologyDescription.heartbeatFrequencyMS = 25000 // 25 seconds
        maxStalenessSeconds = 150.0
        servers = [
            makeServerDescription("a:1", .rsSecondary, 0.0, 125.002),
            makeServerDescription("b:1", .rsSecondary, 0.0, 0.002),
            makeServerDescription("c:1", .rsSecondary, 0.0, 0.001)
        ]
        topology = TopologyDescription(type: .replicaSetNoPrimary, servers: servers)

        expect(topology.staleness(for: servers[0])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[1])) <= maxStalenessSeconds
        expect(topology.staleness(for: servers[2])) > maxStalenessSeconds
    }

    func runHasReadableAsserts(_ topology: TopologyDescription, _ testCase: [(ReadPreference, Bool)]) {
        var primaryCase = false

        testCase.forEach { (readPref, avail) in
            expect(topology.hasReadableServer(readPref)).to(equal(avail), description: "With topology \(topology) " +
                    "and Read Preference { mode: \(readPref.mode), tags: \(readPref.tagSets)}, expected " +
                    "hasReadableServer to return \(avail)")

            if readPref.mode == .primary {
                primaryCase = avail
            }
        }
        expect(topology.hasReadableServer()).to(equal(primaryCase))
    }

    func testHasReadableServers() throws {
        let hosts = [
            "a:1",
            "b:2",
            "c:3"
        ]

        let tags: Document = ["dog": 1, "cat": "two"]
        let tags1: Document = ["sdaf": "sadfsf", "f": 2]
        let wrongTags: Document = ["a": "b"]

        let primaryLastWrite = Date() - 600
        let lastUpdate = primaryLastWrite + 600

        let isMasterPrimary: Document = [
            "hosts": hosts,
            "primary": hosts[0],
            "lastWrite": ["lastWriteDate": primaryLastWrite] as Document
        ]

        // Has replicated most recent write
        let isMasterSecondary: Document = [
            "hosts": hosts,
            "primary": hosts[0],
            "tags": tags,
            "lastWrite": ["lastWriteDate": primaryLastWrite + 50] as Document
        ]

        // Stale
        let isMasterSecondary1: Document = [
            "hosts": hosts,
            "primary": hosts[0],
            "tags": tags1,
            "lastWrite": ["lastWriteDate": primaryLastWrite - 100] as Document
        ]

        let servers = [
            ServerDescription(
                    connectionId: ConnectionId(hosts[0]),
                    type: .rsPrimary,
                    isMaster: isMasterPrimary,
                    updateTime: lastUpdate),
            ServerDescription(
                    connectionId: ConnectionId(hosts[1]),
                    type: .rsSecondary,
                    isMaster: isMasterSecondary,
                    updateTime: lastUpdate),
            ServerDescription(
                    connectionId: ConnectionId(hosts[1]),
                    type: .rsSecondary,
                    isMaster: isMasterSecondary1,
                    updateTime: lastUpdate)
        ]

        let serversNoPrimary = Array(servers[1...])

        let topology1 = TopologyDescription(type: .replicaSetWithPrimary, servers: servers)
        let case1 = [
            (ReadPreference(.primary), true),
            (ReadPreference(.secondary), true),
            (ReadPreference(.primaryPreferred), true),
            (ReadPreference(.secondaryPreferred), true),
            (ReadPreference(.nearest), true),
            (try ReadPreference(.secondary, maxStalenessSeconds: 90), true),
            (try ReadPreference(.secondary, tagSets: [tags], maxStalenessSeconds: 90), true),
            (try ReadPreference(.secondary, tagSets: [tags1], maxStalenessSeconds: 90), false)
        ]
        runHasReadableAsserts(topology1, case1)

        let topology2 = TopologyDescription(type: .replicaSetNoPrimary, servers: serversNoPrimary)
        let case2 = [
            (ReadPreference(.primary), false),
            (ReadPreference(.secondary), true),
            (ReadPreference(.primaryPreferred), true),
            (ReadPreference(.secondaryPreferred), true),
            (ReadPreference(.nearest), true),
            (try ReadPreference(.secondary, maxStalenessSeconds: 90), true),
            (try ReadPreference(.secondary, tagSets: [tags], maxStalenessSeconds: 90), true),
            (try ReadPreference(.secondary, tagSets: [tags1], maxStalenessSeconds: 90), false)
        ]
        runHasReadableAsserts(topology2, case2)

        let topology3 = TopologyDescription(type: .replicaSetWithPrimary, servers: servers)
        let case3 = [
            (ReadPreference(.primary), true),
            (ReadPreference(.secondary), true),
            (try ReadPreference(.secondary, tagSets: [wrongTags, tags]), true),
            (try ReadPreference(.secondary, tagSets: [wrongTags]), false),
            (try ReadPreference(.secondaryPreferred, tagSets: [wrongTags]), true)
        ]
        runHasReadableAsserts(topology3, case3)

        let topology4 = TopologyDescription(type: .replicaSetNoPrimary, servers: serversNoPrimary)
        let case4 = [
            (ReadPreference(.primary), false),
            (try ReadPreference(.primaryPreferred, tagSets: [tags]), true),
            (try ReadPreference(.primaryPreferred, tagSets: [wrongTags]), false)
        ]
        runHasReadableAsserts(topology4, case4)
    }
}
