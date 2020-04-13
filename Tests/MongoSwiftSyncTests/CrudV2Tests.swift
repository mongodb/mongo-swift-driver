import Foundation
import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

private var _client: MongoSwiftSync.MongoClient?

/// A place for CrudV2 Tests until the swift crud v2 runner is shipped
final class MongoCrudV2Tests: MongoSwiftTestCase {
    func testFindOptionsAllowDiskUseNotSpecified() throws {
        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()

        let db = client.db(Self.testDatabase)

        let collection = db.collection("collection")
        try collection.insertOne(["test": "blahblah"])

        try monitor.captureEvents {
            let options = FindOptions()
            expect(try collection.find(["test": "blahblah"], options: options)).toNot(throwError())
        }

        let event = monitor.commandStartedEvents().first
        expect(event).toNot(beNil())
        expect(event?.command["find"]).toNot(beNil())
        expect(event?.command["allowDiskUse"]).to(beNil())
    }

    func testFindOptionsAllowDiskUseFalse() throws {
        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()

        let db = client.db(Self.testDatabase)

        let collection = db.collection("collection")
        try collection.insertOne(["test": "blahblah"])

        try monitor.captureEvents {
            let options = FindOptions(allowDiskUse: false)
            expect(try collection.find(["test": "blahblah"], options: options)).toNot(throwError())
        }

        let event = monitor.commandStartedEvents().first
        expect(event).toNot(beNil())
        expect(event?.command["find"]).toNot(beNil())
        expect(event?.command["allowDiskUse"]?.boolValue).to(beFalse())
    }

    func testFindOptionsAllowDiskUseTrue() throws {
        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()

        let db = client.db(Self.testDatabase)

        let collection = db.collection("collection")
        try collection.insertOne(["test": "blahblah"])

        try monitor.captureEvents {
            let options = FindOptions(allowDiskUse: true)
            expect(try collection.find(["test": "blahblah"], options: options)).toNot(throwError())
        }

        let event = monitor.commandStartedEvents().first
        expect(event).toNot(beNil())
        expect(event?.command["find"]).toNot(beNil())
        expect(event?.command["allowDiskUse"]?.boolValue).to(beTrue())
    }
}
