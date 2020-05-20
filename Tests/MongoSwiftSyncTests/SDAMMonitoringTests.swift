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

    func checkUnknownServerType(_ desc: ServerDescription) {
        expect(desc.type).to(equal(ServerDescription.ServerType.unknown))
    }

    // Basic test based on the "standalone" spec test for SDAM monitoring:
    // swiftlint:disable line_length
    // https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/tests/monitoring/standalone.json
    // swiftlint:enable line_length
    func testMonitoring() throws {
        guard MongoSwiftTestCase.topologyType == .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let monitor = TestSDAMMonitor()
        let client = try MongoClient.makeTestClient()
        client.addSDAMEventHandler(monitor)

        try monitor.captureEvents {
            // do some basic operations
            let db = client.db(Self.testDatabase)
            _ = try db.createCollection(self.getCollectionName())
            try db.drop()
        }

        let receivedEvents = monitor.events().filter { !$0.isHeartbeatEvent }

        let connString = try ConnectionString(MongoSwiftTestCase.getConnectionString())

        guard let host = connString.hosts?[0] else {
            XCTFail("Could not get hosts for uri: \(MongoSwiftTestCase.getConnectionString())")
            return
        }
        let hostAddress = try Address(host)

        // check event count and that events are of the expected types
        expect(receivedEvents.count).to(beGreaterThanOrEqualTo(5))
        expect(receivedEvents[0].topologyOpeningValue).toNot(beNil())
        expect(receivedEvents[1].topologyDescriptionChangedValue).toNot(beNil())
        expect(receivedEvents[2].serverOpeningValue).toNot(beNil())
        expect(receivedEvents[3].serverDescriptionChangedValue).toNot(beNil())
        expect(receivedEvents[4].topologyDescriptionChangedValue).toNot(beNil())

        // verify that data in ServerDescription and TopologyDescription looks reasonable
        let event0 = receivedEvents[0].topologyOpeningValue!
        expect(event0.topologyID).toNot(beNil())

        let event1 = receivedEvents[1].topologyDescriptionChangedValue!
        expect(event1.topologyID).to(equal(event0.topologyID))
        expect(event1.previousDescription.type).to(equal(TopologyDescription.TopologyType.unknown))
        expect(event1.newDescription.type).to(equal(TopologyDescription.TopologyType.single))
        // This is a bit of a deviation from the SDAM spec tests linked above. However, this is how mongoc responds so
        // there is no other way to get around this.
        expect(event1.newDescription.servers).to(beEmpty())

        let event2 = receivedEvents[2].serverOpeningValue!
        expect(event2.topologyID).to(equal(event1.topologyID))
        expect(event2.serverAddress).to(equal(hostAddress))

        let event3 = receivedEvents[3].serverDescriptionChangedValue!
        expect(event3.topologyID).to(equal(event2.topologyID))
        let prevServer = event3.previousDescription
        expect(prevServer.address).to(equal(hostAddress))
        self.checkEmptyLists(prevServer)
        self.checkUnknownServerType(prevServer)

        let newServer = event3.newDescription
        expect(newServer.address).to(equal(hostAddress))
        self.checkEmptyLists(newServer)
        expect(newServer.type).to(equal(ServerDescription.ServerType.standalone))

        let event4 = receivedEvents[4].topologyDescriptionChangedValue!
        expect(event4.topologyID).to(equal(event3.topologyID))
        let prevTopology = event4.previousDescription
        expect(prevTopology.type).to(equal(TopologyDescription.TopologyType.single))
        expect(prevTopology.servers).to(beEmpty())

        let newTopology = event4.newDescription
        expect(newTopology.type).to(equal(TopologyDescription.TopologyType.single))
        expect(newTopology.servers[0].address).to(equal(hostAddress))
        expect(newTopology.servers[0].type).to(equal(ServerDescription.ServerType.standalone))
        self.checkEmptyLists(newTopology.servers[0])
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

    fileprivate var topologyClosedValue: TopologyClosedEvent? {
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

    fileprivate var serverClosedValue: ServerClosedEvent? {
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
