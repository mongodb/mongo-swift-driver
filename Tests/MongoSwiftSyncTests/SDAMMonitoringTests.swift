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
        let hostAddress = try ServerAddress(host)

        expect(receivedEvents.count).to(equal(4))
        expect(receivedEvents[0].topologyOpeningValue).toNot(beNil())
        expect(receivedEvents[1].serverOpeningValue).toNot(beNil())
        expect(receivedEvents[2].serverDescriptionChangedValue).toNot(beNil())
        expect(receivedEvents[3].topologyDescriptionChangedValue).toNot(beNil())

        let event0 = receivedEvents[0].topologyOpeningValue!

        let event1 = receivedEvents[1].serverOpeningValue!
        expect(event1.topologyID).to(equal(event0.topologyID))
        expect(event1.serverAddress).to(equal(hostAddress))

        let event2 = receivedEvents[2].serverDescriptionChangedValue!
        expect(event2.topologyID).to(equal(event1.topologyID))

        let prevServer = event2.previousDescription
        let newServer = event2.newDescription

        expect(prevServer.address).to(equal(hostAddress))
        expect(newServer.address).to(equal(hostAddress))

        self.checkEmptyLists(prevServer)
        self.checkEmptyLists(newServer)

        expect(prevServer.type).to(equal(.unknown))
        expect(newServer.type).to(equal(.standalone))

        let event3 = receivedEvents[3].topologyDescriptionChangedValue!
        expect(event3.topologyID).to(equal(event2.topologyID))

        let prevTopology = event3.previousDescription
        let newTopology = event3.newDescription

        expect(prevTopology.type).to(equal(.unknown))
        expect(newTopology.type).to(equal(.single))

        expect(prevTopology.servers).to(beEmpty())
        expect(newTopology.servers).to(haveCount(1))

        expect(newTopology.servers[0].address).to(equal(hostAddress))
        expect(newTopology.servers[0].type).to(equal(.standalone))

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
