import Foundation
import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

// TODO: remove with SWIFT-780
/// A place for CrudV2 Tests until the swift crud v2 runner is shipped
final class MongoCrudV2Tests: MongoSwiftTestCase {
    func testFindOptionsAllowDiskUse() throws {
        try self.withTestNamespace { client, _, coll in
            let monitor = client.addCommandMonitor()
            try coll.insertOne(["dog": "notCat"])

            try monitor.captureEvents({
                let optionAllowDiskUseNil = FindOptions()
                expect(try coll.find(["dog": "notCat"], options: optionAllowDiskUseNil)).toNot(throwError())

                let optionAllowDiskUseFalse = FindOptions(allowDiskUse: false)
                expect(try coll.find(["dog": "notCat"], options: optionAllowDiskUseFalse)).toNot(throwError())

                let optionAllowDiskUseTrue = FindOptions(allowDiskUse: true)
                expect(try coll.find(["dog": "notCat"], options: optionAllowDiskUseTrue)).toNot(throwError())
            })

            let events = monitor.commandStartedEvents()
            expect(events).to(haveCount(3))

            let eventAllowDiskUseNil = events[0]
            expect(eventAllowDiskUseNil.command["find"]).toNot(beNil())
            expect(eventAllowDiskUseNil.command["allowDiskUse"]).to(beNil())

            let eventAllowDiskUseFalse = events[1]
            expect(eventAllowDiskUseFalse.command["find"]).toNot(beNil())
            expect(eventAllowDiskUseFalse.command["allowDiskUse"]?.boolValue).to(beFalse())

            let eventAllowDiskUseTrue = events[2]
            expect(eventAllowDiskUseTrue.command["find"]).toNot(beNil())
            expect(eventAllowDiskUseTrue.command["allowDiskUse"]?.boolValue).to(beTrue())
        }
    }
}
