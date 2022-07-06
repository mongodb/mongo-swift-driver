import Foundation
@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

final class MongoCollection_IndexTests: MongoSwiftTestCase {
    func testCreateListDropIndexesComment() async throws {
        try await self.withTestClient { client in
            let comment = BSON("hello world")
            let monitor = client.addCommandMonitor()

            guard try await client.serverVersionIsInRange("4.4", nil) else {
                print("Skipping create/list/drop indexes comments test due to unsupported server version")
                return
            }

            let db = client.db(Self.testDatabase)
            let collection = db.collection("collection")
            try await collection.insertOne(["test": "blahblah"])

            try await monitor.captureEvents {
                let model = IndexModel(keys: ["dog": 1])
                let modelNoComm = IndexModel(keys: ["cat": 1])
                let createIndexOpts = CreateIndexOptions(comment: comment)
                let createIndexOptsNoComm = CreateIndexOptions()
                let createIndOperation = try await collection.createIndex(model, options: createIndexOpts)
                expect(createIndOperation).to(equal("dog_1"))
                let createIndOperationNoComm = try await collection.createIndex(modelNoComm, options:
                                                createIndexOptsNoComm)
                expect(createIndOperationNoComm).to(equal("cat_1"))

                let listIndexOpts = ListIndexOptions(comment: comment)
                let listNames = try await collection.listIndexNames(options: listIndexOpts)
                expect(Set(listNames)).to(equal(Set(["_id_", "cat_1", "dog_1"])))

                let dropIndexOpts = DropIndexOptions(comment: comment)
                let dropIndOperation: () = try await collection.dropIndex(model, options: dropIndexOpts)
                expect(dropIndOperation).toNot(throwError())

                // now there should only be _id_ and cat_1 left
                let indexes = try await collection.listIndexes()
                expect(indexes).toNot(beNil())
                let nextOptionsId = try await indexes.next().get()?.options?.name
                expect(nextOptionsId).to(equal("_id_"))
                let nextOptionsNil = try await indexes.next().get()?.options?.name
                expect(nextOptionsNil).to(equal("cat_1"))
            }

            // Check comment exists and is the correct value
            let receivedEvents = monitor.commandStartedEvents()
            expect(receivedEvents.count).to(equal(5))
            expect(receivedEvents[0].command["createIndexes"]).toNot(beNil())
            expect(receivedEvents[0].command["comment"]).toNot(beNil())
            expect(receivedEvents[0].command["comment"]).to(equal(comment))
            expect(receivedEvents[1].command["createIndexes"]).toNot(beNil())
            expect(receivedEvents[1].command["comment"]).to(beNil())
            expect(receivedEvents[2].command["listIndexes"]).toNot(beNil())
            expect(receivedEvents[2].command["comment"]).toNot(beNil())
            expect(receivedEvents[2].command["comment"]).to(equal(comment))
            expect(receivedEvents[3].command["dropIndexes"]).toNot(beNil())
            expect(receivedEvents[3].command["comment"]).toNot(beNil())
            expect(receivedEvents[3].command["comment"]).to(equal(comment))
        }
    }
}
