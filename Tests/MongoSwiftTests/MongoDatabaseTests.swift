import Foundation
@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class MongoDatabaseTests: MongoSwiftTestCase {
    func testListCollectionsComment() async throws {
        try await self.withTestClient { client in
            let monitor = client.addCommandMonitor()
            let db = client.db(Self.testDatabase)

            // comment only supported here for 4.4+
            guard try await client.serverVersionIsInRange("4.4", nil) else {
                print("Skipping list collections comment test due to unsupported server version")
                return
            }

            // clear out collections
            try await db.drop()
            let comment = BSON("commenter")

            _ = try await db.createCollection("foo")
            _ = try await db.createCollection("bar")
            _ = try await db.createCollection("baz")

            try await monitor.captureEvents {
                let options = ListCollectionsOptions(comment: comment)
                _ = try await db.listCollections(options: options)
                _ = try await db.listCollectionNames()
            }

            let events = monitor.commandStartedEvents(withNames: ["listCollections"])
            expect(events).to(haveCount(2))
            expect(events[0].commandName).to(equal("listCollections"))
            expect(events[0].command["comment"]).toNot(beNil())
            expect(events[0].command["comment"]).to(equal(comment))
            expect(events[1].commandName).to(equal("listCollections"))
            expect(events[1].command["comment"]).to(beNil())
        }
    }
}
