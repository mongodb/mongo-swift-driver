import Foundation
import MongoSwift
import Nimble
import NIO
import TestsCommon

final class ChangeStreamTests: MongoSwiftTestCase {
    func testChangeStreamNext() throws {
        try self.withTestClient { client in
            let testRequirements = TestRequirement(
                acceptableTopologies: [.replicaSet, .sharded]
            )

            let unmetRequirement = try client.getUnmetRequirement(testRequirements)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }

            let db = client.db(Self.testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let stream = try coll.watch().wait()
            expect(try stream.isAlive().wait()).to(beTrue())

            _ = try coll.insertOne(["x": 1]).wait()
            _ = try coll.insertOne(["x": 2]).wait()
            _ = try coll.insertOne(["x": 3]).wait()

            expect(try stream.next().wait()?.fullDocument?["x"]).to(equal(1))
            expect(try stream.isAlive().wait()).to(beTrue())

            expect(try stream.next().wait()?.fullDocument?["x"]).to(equal(2))
            expect(try stream.isAlive().wait()).to(beTrue())

            expect(try stream.next().wait()?.fullDocument?["x"]).to(equal(3))
            expect(try stream.isAlive().wait()).to(beTrue())

            // no more events, so to prevent this from blocking forever we use tryNext
            expect(try stream.tryNext().wait()).to(beNil())
            expect(try stream.isAlive().wait()).to(beTrue())

            try stream.kill().wait()
            expect(try stream.isAlive().wait()).to(beFalse())
        }
    }

    func testChangeStreamError() throws {
        try self.withTestClient { client in
            let testRequirements = TestRequirement(
                maxServerVersion: ServerVersion(major: 4, minor: 3, patch: 3),
                acceptableTopologies: [.sharded, .replicaSet]
            )
            let unmetRequirement = try client.getUnmetRequirement(testRequirements)
            guard unmetRequirement == nil else {
                switch unmetRequirement {
                case .minServerVersion, .maxServerVersion:
                    print("Skipping test; see SWIFT-722")
                default:
                    printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                }
                return
            }

            let db = client.db(Self.testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let stream = try coll.watch([["$project": ["_id": 0]]]).wait()
            _ = try coll.insertOne(["x": 1]).wait()
            switch Result(catching: { try stream.next().wait() }) {
            case let .success(r):
                try? stream.kill().wait()
                fail("expected failure, but got \(String(describing: r))")
            case .failure:
                expect(try stream.isAlive().wait()).to(beFalse())
            }
        }
    }

    func testChangeStreamEmpty() throws {
        try self.withTestClient { client in
            let testRequirements = TestRequirement(
                acceptableTopologies: [.replicaSet, .sharded]
            )

            let unmetRequirement = try client.getUnmetRequirement(testRequirements)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }

            let db = client.db(Self.testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let stream = try coll.watch().wait()
            expect(try stream.isAlive().wait()).to(beTrue())

            expect(try stream.tryNext().wait()).to(beNil())
            expect(try stream.isAlive().wait()).to(beTrue())

            // This future will not resolve since there are no events to be had.
            let nextFuture = stream.next()

            // after a bit of waiting, kill it and assert that no errors were reported.
            Thread.sleep(forTimeInterval: 1)
            try stream.kill().wait()
            expect(try nextFuture.wait()).to(beNil())
        }
    }

    func testChangeStreamToArray() throws {
        try self.withTestClient { client in
            let testRequirements = TestRequirement(
                acceptableTopologies: [.replicaSet, .sharded])

            let unmetRequirement = try client.getUnmetRequirement(testRequirements)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }

            let db = client.db(Self.testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let options = ChangeStreamOptions(maxAwaitTimeMS: 10000)

            let stream = try coll.watch(options: options).wait()
            expect(try stream.isAlive().wait()).to(beTrue())

            // initially, no events, but stream should stay alive
            expect(try stream.toArray().wait()).to(beEmpty())
            expect(try stream.isAlive().wait()).to(beTrue())

            // we should get back single event now via toArray
            _ = try coll.insertOne(["x": 1]).wait()
            let results = try stream.toArray().wait()
            expect(results[0].fullDocument?["x"]).to(equal(1))
            expect(try stream.isAlive().wait()).to(beTrue())

            // no more events, but stream should stay alive
            expect(try stream.toArray().wait()).to(beEmpty())
            expect(try stream.isAlive().wait()).to(beTrue())

            try stream.kill().wait()
            expect(try stream.isAlive().wait()).to(beFalse())
        }
    }

    func testChangeStreamForEach() throws {
        var count = 0
        let increment: (ChangeStreamEvent<BSONDocument>) -> Void = { _ in count += 1 }

        try self.withTestClient { client in
            let testRequirements = TestRequirement(
                acceptableTopologies: [.replicaSet, .sharded]
            )

            let unmetRequirement = try client.getUnmetRequirement(testRequirements)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }
            let db = client.db(Self.testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let stream = try coll.watch().wait()
            expect(try stream.isAlive().wait()).to(beTrue())

            // future won't resolve until we close the stream later
            let future = stream.forEach(increment)

            _ = try coll.insertOne(["x": 1]).wait()
            expect(count).toEventually(equal(1), timeout: 10)

            _ = try coll.insertOne(["x": 2]).wait()
            expect(count).toEventually(equal(2), timeout: 10)

            try stream.kill().wait()
            expect(try future.wait()).toNot(throwError())

            // calling forEach on dead stream should error
            expect(try stream.forEach(increment).wait()).to(throwError(errorType: MongoError.LogicError.self))
        }
    }
}
