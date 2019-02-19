import Foundation
import mongoc
@testable import MongoSwift
import Nimble
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

        let observer = center.addObserver(forName: nil, object: nil, queue: nil) { notif in
            guard [
                    "serverDescriptionChanged", "serverOpening", "serverClosed", "topologyDescriptionChanged",
                    "topologyOpening", "topologyClosed"
                  ].contains(notif.name.rawValue) else { return }

            guard let event = notif.userInfo?["event"] as? MongoEvent else {
                XCTFail("Notification \(notif) did not contain an event")
                return
            }

            receivedEvents.append(event)
        }
        // do some basic operations
        let db = client.db(type(of: self).testDatabase)
        _ = try db.createCollection(self.getCollectionName())
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
        expect(event1.previousDescription.type).to(equal(TopologyDescription.TopologyType.unknown))
        expect(event1.newDescription.type).to(equal(TopologyDescription.TopologyType.single))
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
        expect(newServer.type).to(equal(ServerDescription.ServerType.standalone))

        let event4 = receivedEvents[4] as! TopologyDescriptionChangedEvent
        expect(event4.topologyId).to(equal(event3.topologyId))
        let prevTopology = event4.previousDescription
        expect(prevTopology.type).to(equal(TopologyDescription.TopologyType.single))
        expect(prevTopology.servers).to(beEmpty())

        let newTopology = event4.newDescription
        expect(newTopology.type).to(equal(TopologyDescription.TopologyType.single))
        checkDefaultHostPort(newTopology.servers[0], hostlist)
        expect(newTopology.servers[0].type).to(equal(ServerDescription.ServerType.standalone))
        checkEmptyLists(newTopology.servers[0])
    }
}
