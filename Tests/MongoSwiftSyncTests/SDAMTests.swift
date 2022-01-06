import Foundation
@testable import MongoSwift
import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

final class SDAMTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func checkEmptyLists(_ desc: ServerDescription) {
        expect(desc.arbiters).to(haveCount(0))
        expect(desc.hosts).to(haveCount(0))
        expect(desc.passives).to(haveCount(0))
    }

    func captureInitialSDAMEvents() throws -> [SDAMEvent] {
        let monitor = TestSDAMMonitor()
        let client = try MongoClient.makeTestClient()
        client.addSDAMEventHandler(monitor)

        try monitor.captureEvents {
            // do some basic operations
            let db = client.db(Self.testDatabase)
            _ = try db.createCollection(self.getCollectionName())
            try db.drop()
        }

        return monitor.events().filter { !$0.isHeartbeatEvent }
    }

    // Basic test based on the "standalone" spec test for SDAM monitoring:
    // swiftlint:disable line_length
    // https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/tests/monitoring/standalone.json
    // swiftlint:enable line_length
    func testMonitoringStandalone() throws {
        guard MongoSwiftTestCase.topologyType == .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let receivedEvents = try captureInitialSDAMEvents()

        let connString = MongoSwiftTestCase.getConnectionString()
        guard let hostAddress = connString.hosts?[0] else {
            XCTFail("Could not get hosts for uri: \(MongoSwiftTestCase.getConnectionString())")
            return
        }

        expect(receivedEvents.count).to(equal(5))
        expect(receivedEvents[0].topologyOpeningValue).toNot(beNil())
        expect(receivedEvents[1].topologyDescriptionChangedValue).toNot(beNil())
        expect(receivedEvents[2].serverOpeningValue).toNot(beNil())
        expect(receivedEvents[3].serverDescriptionChangedValue).toNot(beNil())
        expect(receivedEvents[4].topologyDescriptionChangedValue).toNot(beNil())

        let event0 = receivedEvents[0].topologyOpeningValue!

        let event1 = receivedEvents[1].topologyDescriptionChangedValue!
        expect(event1.topologyID).to(equal(event0.topologyID))

        let event2 = receivedEvents[2].serverOpeningValue!
        expect(event2.topologyID).to(equal(event1.topologyID))
        expect(event2.serverAddress).to(equal(hostAddress))

        let event3 = receivedEvents[3].serverDescriptionChangedValue!
        expect(event3.topologyID).to(equal(event2.topologyID))

        let prevServer = event3.previousDescription
        let newServer = event3.newDescription

        expect(prevServer.address).to(equal(hostAddress))
        expect(newServer.address).to(equal(hostAddress))

        self.checkEmptyLists(prevServer)
        self.checkEmptyLists(newServer)

        expect(prevServer.type).to(equal(.unknown))
        expect(newServer.type).to(equal(.standalone))

        let event4 = receivedEvents[4].topologyDescriptionChangedValue!
        expect(event4.topologyID).to(equal(event3.topologyID))

        let prevTopology = event4.previousDescription
        let newTopology = event4.newDescription

        expect(prevTopology.type).to(equal(.unknown))
        expect(newTopology.type).to(equal(.single))

        expect(prevTopology.servers).to(beEmpty())
        expect(newTopology.servers).to(haveCount(1))

        expect(newTopology.servers[0].address).to(equal(hostAddress))
        expect(newTopology.servers[0].type).to(equal(.standalone))

        self.checkEmptyLists(newTopology.servers[0])
    }

    // Prose test based on the load balncer spec test for SDAM monitoring:
    // swiftlint:disable line_length
    // https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/tests/monitoring/load_balancer.yml
    // swiftlint:enable line_length
    func testMonitoringLoadBalanced() throws {
        guard MongoSwiftTestCase.topologyType == .loadBalanced else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let receivedEvents = try captureInitialSDAMEvents()

        let connString = MongoSwiftTestCase.getConnectionString()
        guard let hostAddress = connString.hosts?[0] else {
            XCTFail("Could not get hosts for uri: \(MongoSwiftTestCase.getConnectionString())")
            return
        }

        guard receivedEvents.count == 5 else {
            XCTFail("Expected to receive 5 events, but instead received \(receivedEvents.count)")
            return
        }
        guard let topologyOpening = receivedEvents[0].topologyOpeningValue else {
            XCTFail("Expected event to be a topologyOpening event, but instead got \(receivedEvents[0])")
            return
        }
        guard let topologyChanged1 = receivedEvents[1].topologyDescriptionChangedValue else {
            XCTFail(
                "Expected event to be a topologyDescriptionChanged event, but instead got \(receivedEvents[1])"
            )
            return
        }
        guard let serverOpening = receivedEvents[2].serverOpeningValue else {
            XCTFail("Expected event to be a serverOpening event, but instead got \(receivedEvents[2])")
            return
        }
        guard let serverChanged = receivedEvents[3].serverDescriptionChangedValue else {
            XCTFail(
                "Expected event to be a serverDescriptionChanged event, but instead got \(receivedEvents[3])"
            )
            return
        }
        guard let topologyChanged2 = receivedEvents[4].topologyDescriptionChangedValue else {
            XCTFail(
                "Expected event to be a topologyDescriptionChanged event, but instead got \(receivedEvents[4])"
            )
            return
        }

        // all events should have the same topology ID.
        expect(topologyChanged1.topologyID).to(equal(topologyOpening.topologyID))
        expect(serverOpening.topologyID).to(equal(topologyOpening.topologyID))
        expect(serverChanged.topologyID).to(equal(topologyOpening.topologyID))
        expect(topologyChanged2.topologyID).to(equal(topologyOpening.topologyID))

        // initial change from unknown, no servers to loadBalanced, no servers. This is slightly different than what
        // the test linked above expects (that test expects the new server to show up here, too, with unknown type).
        // we don't see it here because `mongoc_topology_description_get_servers` excludes servers with type "unknown",
        // so until the server type changes to "loadBalancer" it won't show up in events.
        expect(topologyChanged1.previousDescription.type).to(equal(.unknown))
        expect(topologyChanged1.previousDescription.servers).to(beEmpty())
        expect(topologyChanged1.newDescription.type).to(equal(.loadBalanced))
        expect(topologyChanged1.newDescription.servers).to(beEmpty())

        // the server discovered should be the single one in the connection string.
        expect(serverOpening.serverAddress).to(equal(hostAddress))
        // the change should be to the same server.
        expect(serverChanged.serverAddress).to(equal(hostAddress))
        // the server should change from type unknown to loadBalancer.
        expect(serverChanged.previousDescription.address).to(equal(hostAddress))
        expect(serverChanged.previousDescription.arbiters).to(beEmpty())
        expect(serverChanged.previousDescription.hosts).to(beEmpty())
        expect(serverChanged.previousDescription.passives).to(beEmpty())
        expect(serverChanged.previousDescription.type).to(equal(.unknown))

        expect(serverChanged.newDescription.address).to(equal(hostAddress))
        expect(serverChanged.newDescription.arbiters).to(beEmpty())
        expect(serverChanged.newDescription.hosts).to(beEmpty())
        expect(serverChanged.newDescription.passives).to(beEmpty())
        expect(serverChanged.newDescription.type).to(equal(.loadBalancer))

        // finally, the topology should change to include the newly opened and discovered server.
        expect(topologyChanged2.previousDescription.type).to(equal(.loadBalanced))
        expect(topologyChanged2.previousDescription.servers).to(beEmpty())

        expect(topologyChanged2.newDescription.type).to(equal(.loadBalanced))
        guard topologyChanged2.newDescription.servers.count == 1 else {
            XCTFail(
                "Expected new topology description to contain 1 server, " +
                    "but found \(topologyChanged2.newDescription.servers)"
            )
            return
        }
        expect(topologyChanged2.newDescription.servers[0].address).to(equal(hostAddress))
        expect(topologyChanged2.newDescription.servers[0].arbiters).to(beEmpty())
        expect(topologyChanged2.newDescription.servers[0].hosts).to(beEmpty())
        expect(topologyChanged2.newDescription.servers[0].passives).to(beEmpty())
        expect(topologyChanged2.newDescription.servers[0].type).to(equal(.loadBalancer))
    }

    func testInitialReplicaSetDiscovery() throws {
        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let hostURIs = Self.getConnectionStringPerHost().map { $0.toString() }

        let optsFalse = MongoClientOptions(directConnection: false)
        let optsTrue = MongoClientOptions(directConnection: true)

        // We should succeed in discovering the primary in all of these cases:
        let testClientsShouldSucceed = try
            hostURIs.map { try MongoClient.makeTestClient($0) } + // option unspecified
            hostURIs.map { try MongoClient.makeTestClient("\($0)&directConnection=false") } + // false in URI
            hostURIs.map { try MongoClient.makeTestClient($0, options: optsFalse) } // false in options struct

        // separately connect to each host and verify we are able to perform a write, meaning
        // that the primary is successfully discovered no matter which host we start with
        for client in testClientsShouldSucceed {
            try withTestNamespace(client: client) { _, collection in
                expect(try collection.insertOne(["x": 1])).toNot(throwError())
            }
        }

        let testClientsShouldMostlyFail = try
            hostURIs.map { try MongoClient.makeTestClient("\($0)&directConnection=true") } + // true in URI
            hostURIs.map { try MongoClient.makeTestClient($0, options: optsTrue) } // true in options struct

        // 4 of 6 attempts to perform writes should fail assuming these are 3-node replica sets, since in 2 cases we
        // will directly connect to the primary, and in the other 4 we will directly connect to a secondary.

        var failures = 0
        for client in testClientsShouldMostlyFail {
            do {
                _ = try withTestNamespace(client: client) { _, collection in
                    try collection.insertOne(["x": 1])
                }
            } catch {
                expect(error).to(beAnInstanceOf(MongoError.CommandError.self))
                failures += 1
            }
        }

        expect(failures).to(
            equal(4),
            description: "Writes should fail when connecting to secondaries with directConnection=true"
        )
    }
}

/// SDAM monitoring event handler that behaves similarly to the `TestCommandMonitor`
private class TestSDAMMonitor: SDAMEventHandler {
    private var topEvents: [SDAMEvent]
    private var monitoring: Bool

    fileprivate init() {
        self.topEvents = []
        self.monitoring = false
    }

    fileprivate func captureEvents<T>(_ f: () throws -> T) rethrows -> T {
        self.monitoring = true
        defer { self.monitoring = false }
        return try f()
    }

    fileprivate func events() -> [SDAMEvent] {
        defer { self.topEvents.removeAll() }
        return self.topEvents
    }

    fileprivate func handleSDAMEvent(_ event: SDAMEvent) {
        guard self.monitoring else {
            return
        }
        self.topEvents.append(event)
    }
}

/// Failable accessors for the different types of topology events.
extension SDAMEvent {
    fileprivate var topologyOpeningValue: TopologyOpeningEvent? {
        guard case let .topologyOpening(event) = self else {
            return nil
        }
        return event
    }

    private var topologyClosedValue: TopologyClosedEvent? {
        guard case let .topologyClosed(event) = self else {
            return nil
        }
        return event
    }

    fileprivate var topologyDescriptionChangedValue: TopologyDescriptionChangedEvent? {
        guard case let .topologyDescriptionChanged(event) = self else {
            return nil
        }
        return event
    }

    fileprivate var serverOpeningValue: ServerOpeningEvent? {
        guard case let .serverOpening(event) = self else {
            return nil
        }
        return event
    }

    private var serverClosedValue: ServerClosedEvent? {
        guard case let .serverClosed(event) = self else {
            return nil
        }
        return event
    }

    fileprivate var serverDescriptionChangedValue: ServerDescriptionChangedEvent? {
        guard case let .serverDescriptionChanged(event) = self else {
            return nil
        }
        return event
    }

    fileprivate var isHeartbeatEvent: Bool {
        switch self {
        case .serverHeartbeatFailed, .serverHeartbeatStarted, .serverHeartbeatSucceeded:
            return true
        default:
            return false
        }
    }
}
