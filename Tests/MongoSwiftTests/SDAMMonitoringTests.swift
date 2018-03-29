@testable import MongoSwift
import Foundation
import Nimble
import XCTest

final class SDAMMonitoringTests: XCTestCase {

	func testMonitoring() throws {
		let client = try MongoClient()
		client.enableMonitoring(forEvents: [.serverDescriptionChanged, .serverOpening, .serverClosed, .topologyDescriptionChanged,
										.topologyOpening, .topologyClosed, .serverHeartbeatStarted, .serverHeartbeatSucceeded, .serverHeartbeatFailed])

		let center = NotificationCenter.default

		let observer = center.addObserver(forName: nil, object: nil, queue: nil) { (notif) in
			print("NOTIF: \(notif)")
        }

        let db = try client.db("testing")
        let coll = try db.createCollection("testColl")
        _ = try coll.insertOne(["x": 1])

        try db.drop()
	}
}
