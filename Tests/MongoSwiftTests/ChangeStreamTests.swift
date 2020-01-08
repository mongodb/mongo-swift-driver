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

            try coll.watch().flatMap { stream in
                coll.insertOne(["x": 1])
                    .flatMap { _ in
                        coll.insertOne(["x": 2])
                    }.flatMap { _ in
                        coll.insertOne(["x": 3])
                    }.flatMap { _ -> EventLoopFuture<ChangeStreamEvent<Document>?> in
                        stream.next()
                    }.flatMap { event -> EventLoopFuture<ChangeStreamEvent<Document>?> in
                        expect(event?.fullDocument?["x"]).to(equal(1))
                        return stream.next()
                    }.flatMap { event -> EventLoopFuture<ChangeStreamEvent<Document>?> in
                        expect(event?.fullDocument?["x"]).to(equal(2))
                        return stream.next()
                    }.flatMap { event -> EventLoopFuture<ChangeStreamEvent<Document>?> in
                        expect(event?.fullDocument?["x"]).to(equal(3))
                        return stream.next()
                    }.flatMap { event -> EventLoopFuture<Void> in
                        expect(event).to(beNil())
                        return stream.close()
                    }
            }.wait()
        }
    }

    func testChangeStreamAll() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        try self.withTestClient { client in
            let db = client.db(type(of: self).testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            try coll.watch().flatMap { stream in
                coll.insertOne(["x": 1]).flatMap { _ in
                    coll.insertOne(["x": 2])
                }.flatMap { _ in
                    coll.insertOne(["x": 3])
                }.flatMap { _ in
                    stream.all()
                }.flatMap { events -> EventLoopFuture<Void> in
                    expect(events.count).to(equal(3))
                    expect(stream.resumeToken).toNot(beNil())
                    expect(events.map { $0.fullDocument?["x"]?.asInt() }).to(equal([1, 2, 3]))
                    return stream.close()
                }
            }.wait()
        }
    }

    func testChangeStreamForEach() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        var events: [ChangeStreamEvent<Document>] = []

        try self.withTestClient { client in
            let db = client.db(type(of: self).testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            try coll.watch().flatMap { stream -> EventLoopFuture<Void> in
                stream.forEach { result in
                    switch result {
                    case let .success(event):
                        events.append(event)
                    case let .failure(error):
                        fail("got an error while polling: \(error)")
                    }
                }

                return coll.insertOne(["x": 1])
                    .flatMap { _ in
                        coll.insertOne(["x": 2])
                    }.flatMap { _ -> EventLoopFuture<Void> in
                        client.wait(seconds: 2)
                    }.flatMap { _ in
                        stream.close()
                    }
            }.wait()
        }
        expect(events.count).to(equal(2))
        expect(events[0].fullDocument?["x"]).to(equal(1))
        expect(events[1].fullDocument?["x"]).to(equal(2))
    }

    func testChangeStreamError() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        try self.withTestClient { client in
            let db = client.db(type(of: self).testDatabase)
            try? db.collection(self.getCollectionName()).drop().wait()
            let coll = try db.createCollection(self.getCollectionName()).wait()

            try? coll.watch([["$project": ["_id": 0]]]).flatMap { stream -> EventLoopFuture<Void> in
                let future = coll.insertOne(["x": 1])
                    .flatMap { _ in
                        client.wait(seconds: 2)
                    }.flatMap { _ in
                        stream.next()
                    }
                future.whenComplete { result in
                    switch result {
                    case let .failure(error):
                        expect(error as? CommandError).toNot(beNil())
                        expect(stream.isAlive).to(beFalse())
                    case let .success(r):
                        fail("expected failure, but got \(String(describing: r))")
                    }
                }
                return future.flatMap { _ in
                    stream.close()
                }
            }.wait()
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

            try coll.watch().flatMap { stream in
                stream.next().flatMap { result -> EventLoopFuture<Void> in
                    expect(result).to(beNil())
                    return stream.close()
                }
            }.wait()
        }
    }
}
