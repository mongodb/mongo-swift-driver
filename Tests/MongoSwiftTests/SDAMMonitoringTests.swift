@testable import MongoSwift
import Foundation
import Nimble
import XCTest

final class SDAMMonitoringTests: XCTestCase {

    override func setUp() {
        self.continueAfterFailure = false
    }

    // Basic test based on the "standalone" spec test for SDAM monitoring
    func testMonitoring() throws {
        let client = try MongoClient()
        try client.initializeMonitoring(forEvents: .serverMonitoring)

        let center = NotificationCenter.default
        var receivedEvents = [Event]()

        let observer = center.addObserver(forName: nil, object: nil, queue: nil) { (notif) in
            guard let event = notif.userInfo?["event"] as? Event else {
                XCTFail("Notification \(notif) did not contain an event")
                return
            }
            // heartbeat events are not deterministic for every run since they're time dependent, so ignore them
            if event as? ServerHeartbeatStartedEvent == nil,
                event as? ServerHeartbeatSucceededEvent == nil,
                event as? ServerHeartbeatFailedEvent == nil {
                receivedEvents.append(event)
            }
        }

        // do some basic operations
        let db = try client.db("testing")
        _ = try db.createCollection("testColl")
        try db.drop()

        center.removeObserver(observer)

        expect(receivedEvents.count).to(equal(5))
        expect(receivedEvents[0]).to(beAnInstanceOf(TopologyOpeningEvent.self))
        expect(receivedEvents[1]).to(beAnInstanceOf(TopologyDescriptionChangedEvent.self))
        expect(receivedEvents[2]).to(beAnInstanceOf(ServerOpeningEvent.self))
        expect(receivedEvents[3]).to(beAnInstanceOf(ServerDescriptionChangedEvent.self))
        expect(receivedEvents[4]).to(beAnInstanceOf(TopologyDescriptionChangedEvent.self))
    }
}
