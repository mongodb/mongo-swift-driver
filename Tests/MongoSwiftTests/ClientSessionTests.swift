import Foundation
@testable import MongoSwift
import Nimble
import XCTest

final class ClientSessionTests: MongoSwiftTestCase {
    override func tearDown() {
        do {
            let client = try MongoClient(MongoSwiftTestCase.connStr)
            try client.db(type(of: self).testDatabase).drop()
        } catch {
            fail("encountered error when tearing down: \(error)")
        }
        super.tearDown()
    }

    typealias CollectionSessionOp = (name: String, body: (MongoCollection<Document>, ClientSession?) throws -> Void)
    typealias DatabaseSessionOp = (name: String, body: (MongoDatabase, ClientSession?) throws -> Void)
    typealias ClientSessionOp = (name: String, body: (MongoClient, ClientSession?) throws -> Void)
    typealias SessionOp = (name: String, body: (ClientSession?) throws -> Void)

    typealias InsertOneModel = MongoCollection<Document>.InsertOneModel

    // list of read only operations on MongoCollection that take in a session
    let collectionSessionReadOps: [CollectionSessionOp] = [
        (name: "find", body: { _ = try $0.find([:], session: $1).nextOrError() }),
        (name: "aggregate", body: { _ = try $0.aggregate([], session: $1).nextOrError() }),
        (name: "distinct", body: { _ = try $0.distinct(fieldName: "x", session: $1) }),
        (name: "count", body: { _ = try $0.count(session: $1) })
    ]

    // list of write operations on MongoCollection that take in a session
    let collectionSessionWriteOps: [CollectionSessionOp] = [
        (name: "bulkWrite", body: { _ = try $0.bulkWrite([InsertOneModel([:])], session: $1) }),
        (name: "insertOne", body: { _ = try $0.insertOne([:], session: $1) }),
        (name: "insertMany", body: { _ = try $0.insertMany([[:]], session: $1) }),
        (name: "replaceOne", body: { _ = try $0.replaceOne(filter: [:], replacement: [:], session: $1) }),
        (name: "updateOne", body: { _ = try $0.updateOne(filter: [:], update: [:], session: $1) }),
        (name: "updateMany", body: { _ = try $0.updateMany(filter: [:], update: [:], session: $1) }),
        (name: "deleteOne", body: { _ = try $0.deleteOne([:], session: $1) }),
        (name: "deleteMany", body: { _ = try $0.deleteMany([:], session: $1) }),
        (name: "createIndex", body: { _ = try $0.createIndex([:], session: $1) }),
        (name: "createIndex1", body: { _ = try $0.createIndex(IndexModel(keys: ["x": 1] as Document), session: $1) }),
        (name: "createIndexes", body: { _ = try $0.createIndexes([], session: $1) }),
        (name: "dropIndex", body: { _ = try $0.dropIndex(["x": 1], session: $1) }),
        (name: "dropIndex1", body: { _ = try $0.dropIndex(IndexModel(keys: ["x": 3] as Document), session: $1) }),
        (name: "dropIndex2", body: { _ = try $0.dropIndex("x_7", session: $1) }),
        (name: "dropIndexes", body: { _ = try $0.dropIndexes(session: $1) }),
        (name: "listIndexes", body: { _ = try $0.listIndexes(session: $1).next() }),
        (name: "findOneAndDelete", body: { _ = try $0.findOneAndDelete([:], session: $1) }),
        (name: "findOneAndReplace", body: { _ = try $0.findOneAndReplace(filter: [:], replacement: [:], session: $1) }),
        (name: "findOneAndUpdate", body: { _ = try $0.findOneAndUpdate(filter: [:], update: [:], session: $1) })
    ]

    // list of operations on MongoDatabase that take in a session
    let databaseSessionOps: [DatabaseSessionOp] = [
        (name: "runCommand", { try $0.runCommand(["isMaster": 0], session: $1) }),
        (name: "createCollection", body: { _ = try $0.createCollection("asdf", session: $1) }),
        (name: "createCollection1", body: { _ = try $0.createCollection("asdf", withType: Document.self, session: $1) })
    ]

    // list of operatoins on MongoClient that take in a session
    let clientSessionOps: [ClientSessionOp] = [
        (name: "listDatabases", { _ = try $0.listDatabases(session: $1).nextOrError() })
    ]

    // iterate over all the different session op types, passing in the provided client/db/collection as needed.
    func forEachSessionOp(client: MongoClient,
                          database: MongoDatabase,
                          collection: MongoCollection<Document>,
                          _ body: (SessionOp) throws -> Void) rethrows {
        try (collectionSessionReadOps + collectionSessionWriteOps).forEach { op in
            try body((name: op.name, body: { try op.body(collection, $0) }))
        }
        try databaseSessionOps.forEach { op in
            try body((name: op.name, body: { try op.body(database, $0) }))
        }
        try clientSessionOps.forEach { op in
            try body((name: op.name, body: { try op.body(client, $0) }))
        }
    }

    /// Sessions spec test 1: Test that sessions are properly returned to the pool when ended.
    func testSessionCleanup() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr)

        var sessionA: ClientSession? = try client.startSession()
        expect(sessionA!.active).to(beTrue())

        var sessionB: ClientSession? = try client.startSession()
        expect(sessionB!.active).to(beTrue())

        let idA = sessionA!.id
        let idB = sessionB!.id

        // test via deinit
        sessionA = nil
        sessionB = nil

        let sessionC: ClientSession = try client.startSession()
        expect(sessionC.active).to(beTrue())
        expect(sessionC.id).to(bsonEqual(idB))

        let sessionD: ClientSession = try client.startSession()
        expect(sessionD.active).to(beTrue())
        expect(sessionD.id).to(bsonEqual(idA))

        // test via explicitly ending
        sessionC.end()
        expect(sessionC.active).to(beFalse())
        sessionD.end()
        expect(sessionD.active).to(beFalse())

        // test via withSession
        try client.withSession { session in
            expect(session.id).to(bsonEqual(idA))
        }

        try client.withSession { session in
            expect(session.id).to(bsonEqual(idA))
        }

        try client.withSession { session in
            expect(session.id).to(bsonEqual(idA))
            try client.withSession { nestedSession in
                expect(nestedSession.id).to(bsonEqual(idB))
            }
        }
    }

    // Executes the body twice, once with the supplied session and once without, verifying that a correct lsid is
    // seen both times.
    func runArgTest(session: ClientSession, op: SessionOp) throws {
        let center = NotificationCenter.default

        var seenExplicit = false
        var seenImplicit = false
        let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
            guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                return
            }

            expect(event.command["lsid"]).toNot(beNil(), description: op.name)
            if !seenExplicit {
                expect(event.command["lsid"]).to(bsonEqual(session.id), description: op.name)
                seenExplicit = true
            } else {
                expect(seenImplicit).to(beFalse())
                expect(event.command["lsid"]).toNot(bsonEqual(session.id), description: op.name)
                seenImplicit = true
            }
        }
        // We don't care if they succeed (e.g. a drop index may fail if index doesn't exist)
        try? op.body(session)
        try? op.body(nil)

        expect(seenImplicit).to(beTrue(), description: op.name)
        expect(seenExplicit).to(beTrue(), description: op.name)

        center.removeObserver(observer)
    }

    /// Sessions spec test 3: test that every function that takes a session parameter passes the sends implicit and
    /// explicit lsids to server.
    func testSessionArguments() throws {
        let client1 = try MongoClient(MongoSwiftTestCase.connStr, options: ClientOptions(eventMonitoring: true))
        client1.enableMonitoring(forEvents: .commandMonitoring)

        let database = client1.db(type(of: self).testDatabase)
        let collection = database.collection(self.getCollectionName())
        let session = try client1.startSession()

        try forEachSessionOp(client: client1, database: database, collection: collection) { op in
            try runArgTest(session: session, op: op)
        }

        try database.drop()
    }

    /// Sessions spec test 4: test that a session can only be used with db's and collections that were derived from the
    /// same client.
    func testSessionClientValidation() throws {
        let client1 = try MongoClient(MongoSwiftTestCase.connStr)
        let client2 = try MongoClient(MongoSwiftTestCase.connStr)

        let database = client1.db(type(of: self).testDatabase)
        defer { try? database.drop() }
        let collection = database.collection(self.getCollectionName())

        let session = try client2.startSession()
        try forEachSessionOp(client: client1, database: database, collection: collection) { op in
            expect(try op.body(session))
                    .to(throwError(UserError.invalidArgumentError(message: "")), description: op.name)
        }
    }

    /// Sessions spec test 5: Test that inactive sessions cannot be used.
    func testInactiveSession() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr)
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let collection = db.collection(self.getCollectionName())
        let session1 = try client.startSession()

        session1.end()
        expect(session1.active).to(beFalse())

        try forEachSessionOp(client: client, database: db, collection: collection) { op in
            expect(try op.body(session1)).to(throwError(ClientSession.SessionInactiveError), description: op.name)
        }

        let session2 = try client.startSession()
        let database = client.db(type(of: self).testDatabase)
        let collection1 = database.collection(self.getCollectionName())

        try (1...3).forEach { try collection1.insertOne(["x": $0]) }

        let cursor = try collection.find(session: session2)
        expect(cursor.next()).toNot(beNil())
        session2.end()
        expect(try cursor.nextOrError()).to(throwError(ClientSession.SessionInactiveError))
    }

    /// Sessions spec test 10: Test cursors have the same lsid in the initial find command and in subsequent getMores.
    func testSessionCursor() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr, options: ClientOptions(eventMonitoring: true))
        client.enableMonitoring(forEvents: .commandMonitoring)

        let database = client.db(type(of: self).testDatabase)
        let collection = database.collection(self.getCollectionName())
        let session = try client.startSession()

        for x in 1...3 {
            try collection.insertOne(["x": x])
        }

        var id: Document?
        var seenFind = false
        var seenGetMore = false

        let center = NotificationCenter.default
        let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
            guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                return
            }

            if event.command["find"] != nil {
                seenFind = true
                if let id = id {
                    expect(id).to(bsonEqual(event.command["lsid"]))
                } else {
                    expect(event.command["lsid"]).toNot(beNil())
                    id = event.command["lsid"] as? Document
                }
            } else if event.command["getMore"] != nil {
                seenGetMore = true
                expect(id).toNot(beNil())
                expect(event.command["lsid"]).toNot(beNil())
                expect(event.command["lsid"]).to(bsonEqual(id))
            }
        }

        // explicit
        id = session.id
        seenFind = false
        seenGetMore = false
        let cursor = try collection.find(options: FindOptions(batchSize: 2), session: session)
        expect(cursor.next()).toNot(beNil())
        expect(cursor.next()).toNot(beNil())
        expect(cursor.next()).toNot(beNil())
        expect(seenFind).to(beTrue())
        expect(seenGetMore).to(beTrue())

        // implicit
        seenFind = false
        seenGetMore = false
        id = nil
        let cursor1 = try collection.find(options: FindOptions(batchSize: 2))
        expect(cursor1.next()).toNot(beNil())
        expect(cursor1.next()).toNot(beNil())
        expect(cursor1.next()).toNot(beNil())
        expect(seenFind).to(beTrue())
        expect(seenGetMore).to(beTrue())

        center.removeObserver(observer)
    }

    /// Sessions spec test 11: Test that the clusterTime is reported properly.
    func testClusterTime() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let client = try MongoClient(MongoSwiftTestCase.connStr)

        try client.withSession { session in
            expect(session.clusterTime).to(beNil())
            _ = try client.listDatabases(session: session).next()
            expect(session.clusterTime).toNot(beNil())
        }

        try client.withSession { session in
            let date = Date()
            expect(session.clusterTime).to(beNil())
            let newTime: Document = ["clusterTime": Timestamp(timestamp: Int(date.timeIntervalSince1970), inc: 100)]
            session.advanceClusterTime(to: newTime)
            expect(session.clusterTime).to(bsonEqual(newTime))
        }
    }

    /// Test that causal consistency guarantees are met.
    func testCausalConsistency() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let center = NotificationCenter.default
        let client = try MongoClient(MongoSwiftTestCase.connStr, options: ClientOptions(eventMonitoring: true))
        client.enableMonitoring()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let collection = db.collection(self.getCollectionName())

        // spec test 1
        let session1 = try client.startSession()
        expect(session1.operationTime).to(beNil())
        session1.end()

        // spec test 2 + 3
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            var seenCommand = false
            let startObserver = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                    return
                }
                expect((event.command["readConcern"] as? Document)?["afterClusterTime"]).to(beNil())
                seenCommand = true
            }
            defer { center.removeObserver(startObserver) }

            var replyOpTime: Timestamp?
            let succeedObserver = center.addObserver(forName: .commandSucceeded, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandSucceededEvent else {
                    return
                }
                expect(seenCommand).to(beTrue())
                replyOpTime = event.reply["operationTime"] as? Timestamp
            }
            defer { center.removeObserver(succeedObserver) }

            _ = try collection.find(session: session).next()
            expect(seenCommand).to(beTrue())
            expect(replyOpTime).toNot(beNil())
            expect(replyOpTime).to(bsonEqual(session.operationTime))
        }

        // spec test 4 + 8
        try collectionSessionReadOps.forEach { op in
            try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
                _ = try collection.find(session: session).next()
                let opTime = session.operationTime
                var seenCommand = false
                let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                    guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                        return
                    }
                    let readConcern = event.command["readConcern"] as? Document
                    expect(readConcern).toNot(beNil(), description: op.name)
                    expect(readConcern!["afterClusterTime"]).to(bsonEqual(opTime), description: op.name)
                    expect(readConcern!["level"]).to(beNil(), description: op.name)
                    seenCommand = true
                }
                defer { center.removeObserver(observer) }
                try op.body(collection, session)
                expect(seenCommand).to(beTrue(), description: op.name)
            }
        }

        // spec test 5
        try collectionSessionWriteOps.forEach { op in
            try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
                try? op.body(collection, session)
                let opTime = session.operationTime

                var seenCommand = false
                let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                    guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                        return
                    }
                    expect((event.command["readConcern"] as? Document)?["afterClusterTime"])
                            .to(bsonEqual(opTime), description: op.name)
                    seenCommand = true
                }
                defer { center.removeObserver(observer) }
                _ = try collection.find(session: session).next()
                expect(seenCommand).to(beTrue(), description: op.name)
            }
        }

        // spec test 6
        try client.withSession(options: ClientSessionOptions(causalConsistency: false)) { session in
            var seenCommand = false
            _ = try collection.find(session: session).next()
            let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                    return
                }
                expect((event.command["readConcern"] as? Document)?["afterClusterTime"]).to(beNil())
                seenCommand = true
            }
            defer { center.removeObserver(observer) }
            _ = try collection.aggregate([["$match": ["x": 1] as Document]], session: session).next()
            expect(seenCommand).to(beTrue())
        }

        // spec test 9
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            let collection1 = db.collection(self.getCollectionName(),
                                            options: CollectionOptions(readConcern: ReadConcern(.snapshot)))
            _ = try collection1.find(session: session).next()
            let opTime = session.operationTime

            var seenCommand = false
            let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                    return
                }
                let readConcern = event.command["readConcern"] as? Document
                expect(readConcern).toNot(beNil())
                expect(readConcern!["afterClusterTime"]).to(bsonEqual(opTime))
                expect(readConcern!["level"]).to(bsonEqual("snapshot"))
                seenCommand = true
            }
            defer { center.removeObserver(observer) }
            _ = try collection1.find(session: session).next()
            expect(seenCommand).to(beTrue())
        }

        // spec test 10
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            let collection1 = db.collection(self.getCollectionName(),
                                            options: CollectionOptions(writeConcern: try WriteConcern(w: .number(0))))
            try collection1.insertOne(["x": 3])
            expect(session.operationTime).to(beNil())
        }

        // spec test 12
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            var seenCommand = false
            let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                    return
                }
                expect(event.command["$clusterTime"]).toNot(beNil())
                seenCommand = true
            }
            defer { center.removeObserver(observer) }
            _ = try collection.find(session: session).next()
            expect(seenCommand).to(beTrue())
        }
    }

    /// Test causal consistent behavior on a topology that doesn't support cluster time.
    func testCausalConsistencyStandalone() throws {
        guard MongoSwiftTestCase.topologyType == .single else {
            print("Skipping test case because of unsupported topology type \(MongoSwiftTestCase.topologyType)")
            return
        }

        let center = NotificationCenter.default
        let client = try MongoClient(MongoSwiftTestCase.connStr, options: ClientOptions(eventMonitoring: true))
        client.enableMonitoring()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let collection = db.collection(self.getCollectionName())

        // spec test 7
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            _ = try collection.find(session: session).next()

            var seenCommand = false
            let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                    return
                }
                expect((event.command["readConcern"] as? Document)?["afterClusterTime"]).to(beNil())
                seenCommand = true
            }
            defer { center.removeObserver(observer) }
            _ = try collection.listIndexes(session: session).next()
            expect(seenCommand).to(beTrue())
        }

        // spec test 11
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            _ = try collection.insertOne([:], session: session)
            let opTime = session.operationTime

            var seenCommand = false
            let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                    return
                }
                expect(event.command["$clusterTime"]).to(beNil())
                seenCommand = true
            }
            defer { center.removeObserver(observer) }
            _ = try collection.listIndexes(session: session).next()
            expect(seenCommand).to(beTrue())
        }
    }
}
