import Foundation
import MongoSwift
import Nimble
import NIO
import TestsCommon

final class ChangeStreamTests: MongoSwiftTestCase {
    func testChangeStreamNext() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        try self.withTestClient { client in
            let db = client.db(type(of: self).testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let stream = try coll.watch().wait()
            expect(stream.isAlive).to(beTrue())

            _ = try coll.insertOne(["x": 1]).wait()
            _ = try coll.insertOne(["x": 2]).wait()
            _ = try coll.insertOne(["x": 3]).wait()

            expect(try stream.next().wait()?.fullDocument?["x"]).to(equal(1))
            expect(stream.isAlive).to(beTrue())

            expect(try stream.next().wait()?.fullDocument?["x"]).to(equal(2))
            expect(stream.isAlive).to(beTrue())

            expect(try stream.next().wait()?.fullDocument?["x"]).to(equal(3))
            expect(stream.isAlive).to(beTrue())

            // no more events, so to prevent this from blocking forever we use tryNext
            expect(try stream.tryNext().wait()).to(beNil())
            expect(stream.isAlive).to(beTrue())

            try stream.kill().wait()
            expect(stream.isAlive).to(beFalse())
        }
    }

    func testChangeStreamError() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        try self.withTestClient { client in
            guard try client.serverVersion().wait() < ServerVersion(major: 4, minor: 3, patch: 3) else {
                print("Skipping test; see SWIFT-722")
                return
            }

            let db = client.db(type(of: self).testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let stream = try coll.watch([["$project": ["_id": 0]]]).wait()
            _ = try coll.insertOne(["x": 1]).wait()
            switch Result(catching: { try stream.next().wait() }) {
            case let .success(r):
                try? stream.kill().wait()
                fail("expected failure, but got \(String(describing: r))")
            case .failure:
                expect(stream.isAlive).to(beFalse())
            }
        }
    }

    func testChangeStreamEmpty() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        try self.withTestClient { client in
            let db = client.db(type(of: self).testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let stream = try coll.watch().wait()
            expect(stream.isAlive).to(beTrue())

            expect(try stream.tryNext().wait()).to(beNil())
            expect(stream.isAlive).to(beTrue())

            // This future will not resolve since there are no events to be had.
            let nextFuture = stream.next()

            // after a bit of waiting, kill it and assert that no errors were reported.
            Thread.sleep(forTimeInterval: 1)
            try stream.kill().wait()
            expect(try nextFuture.wait()).to(beNil())
        }
    }

    func testChangeStreamToArray() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }
        try self.withTestClient { client in
            let db = client.db(type(of: self).testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            let options = ChangeStreamOptions(maxAwaitTimeMS: 10000)

            let stream = try coll.watch(options: options).wait()
            expect(stream.isAlive).to(beTrue())

            // initially, no events, but stream should stay alive
            expect(try stream.toArray().wait()).to(beEmpty())
            expect(stream.isAlive).to(beTrue())

            // we should get back single event now via toArray
            _ = try coll.insertOne(["x": 1]).wait()
            let results = try stream.toArray().wait()
            expect(results[0].fullDocument?["x"]).to(equal(1))
            expect(stream.isAlive).to(beTrue())

            // no more events, but stream should stay alive
            expect(try stream.toArray().wait()).to(beEmpty())
            expect(stream.isAlive).to(beTrue())

            try stream.kill().wait()
            expect(stream.isAlive).to(beFalse())
        }
    }
}
