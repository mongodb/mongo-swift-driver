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

    /// Test that sessions are properly returned to the pool when ended.
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

    struct SessionsArgTest {
        let name: String
        let body: (ClientSession?) throws -> Void

        func execute(session: ClientSession) throws {
            let center = NotificationCenter.default

            var seenExplicit = false
            var seenImplicit = false
            let observer = center.addObserver(forName: .commandStarted, object: nil, queue: nil) { notif in
                guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                    return
                }
                expect(event.command["lsid"]).toNot(beNil(), description: self.name)
                if !seenExplicit {
                    expect(event.command["lsid"]).to(bsonEqual(session.id), description: self.name)
                    seenExplicit = true
                } else {
                    expect(seenImplicit).to(beFalse())
                    expect(event.command["lsid"]).toNot(bsonEqual(session.id), description: self.name)
                    seenImplicit = true
                }
            }
            // We don't care if they succeed (e.g. a drop index may fail if index doesn't exist)
            try? self.body(session)
            try? self.body(nil)

            expect(seenImplicit).to(beTrue(), description: self.name)
            expect(seenExplicit).to(beTrue(), description: self.name)

            center.removeObserver(observer)
        }
    }

    /// Test that every function that takes a session parameter passes the sends implicit and explicit lsids to server.
    func testSessionArguments() throws {
        let client1 = try MongoClient(MongoSwiftTestCase.connStr, options: ClientOptions(eventMonitoring: true))
        client1.enableMonitoring(forEvents: .commandMonitoring)

        let database = client1.db(type(of: self).testDatabase)
        let collection = database.collection(self.getCollectionName())
        let session = try client1.startSession()

        let doc: Document = ["a": 1]
        let update: Document = ["$set": ["x": 1] as Document]
        let model: WriteModel = MongoCollection<Document>.UpdateOneModel(filter: doc, update: update)
        let models = (1...8).map { IndexModel(keys: ["x": $0 ]) }

        let collectionCases = [
            SessionsArgTest(name: "bulkWrite") { try collection.bulkWrite([model], session: $0) },
            SessionsArgTest(name: "insertOne") { try collection.insertOne(doc, session: $0) },
            SessionsArgTest(name: "insertMany") { try collection.insertMany([doc], session: $0) },
            SessionsArgTest(name: "replaceOne") {
                try collection.replaceOne(filter: doc, replacement: doc, session: $0)
            },
            SessionsArgTest(name: "updateOne") { try collection.updateOne(filter: doc, update: update, session: $0) },
            SessionsArgTest(name: "updateMany") { try collection.updateMany(filter: doc, update: update, session: $0) },
            SessionsArgTest(name: "deleteOne") { try collection.deleteOne(doc, session: $0) },
            SessionsArgTest(name: "deleteMany") { try collection.deleteMany(doc, session: $0) },
            SessionsArgTest(name: "find") { _ = try collection.find(doc, session: $0).next() },
            SessionsArgTest(name: "aggregate") {
                _ = try collection.aggregate([] as [Document], session: $0).next()
            },
            SessionsArgTest(name: "distinct") { _ = try collection.distinct(fieldName: "x", session: $0) },
            SessionsArgTest(name: "findOneAndDelete") { try collection.findOneAndDelete(doc, session: $0) },
            SessionsArgTest(name: "findOneAndReplace") {
                try collection.findOneAndReplace(filter: doc, replacement: doc, session: $0)
            },
            SessionsArgTest(name: "findOneAndUpdate") {
                try collection.findOneAndUpdate(filter: doc, update: update, session: $0)
            },
            SessionsArgTest(name: "createIndex") { try collection.createIndex(doc, session: $0) },
            SessionsArgTest(name: "createIndex1") {
                try collection.createIndex(IndexModel(keys: ["x": 1] as Document), session: $0)
            },
            SessionsArgTest(name: "createIndexes") { try collection.createIndexes(models, session: $0) },
            SessionsArgTest(name: "dropIndex") { try collection.dropIndex(["x": 1], session: $0) },
            SessionsArgTest(name: "dropIndex1") {
                try collection.dropIndex(IndexModel(keys: ["x": 3] as Document), session: $0)
            },
            SessionsArgTest(name: "dropIndex2") { try collection.dropIndex("x_7", session: $0) },
            SessionsArgTest(name: "dropIndexes") { try collection.dropIndexes(session: $0) },
            SessionsArgTest(name: "listIndexes") { _ = try collection.listIndexes(session: $0).next() }
        ]
        try collectionCases.forEach { try $0.execute(session: session) }

        try database.drop()

        let databaseCases = [
            SessionsArgTest(name: "runCommand") { try database.runCommand(["isMaster": 0], session: $0) },
            SessionsArgTest(name: "createCollection") {
                _ = try database.createCollection(self.getCollectionName(), session: $0)
            },
            SessionsArgTest(name: "createCollection1") {
                _ = try database.createCollection(self.getCollectionName(), withType: Document.self, session: $0)
            }
        ]
        try databaseCases.forEach { try $0.execute(session: session) }

        // client case
        try SessionsArgTest(name: "listDatabases") {
            _ = try client1.listDatabases(session: $0).next()
        }.execute(session: session)

        try database.drop()
    }

    /// Test that a session can only be used with db's and collections that were derived from the same client.
    func testSessionClientValidation() throws {
        let client1 = try MongoClient(MongoSwiftTestCase.connStr)
        let client2 = try MongoClient(MongoSwiftTestCase.connStr)

        let database = client1.db(type(of: self).testDatabase)
        let collection = database.collection(self.getCollectionName())

        let session = try client2.startSession()
        expect(try collection.insertOne(["x": 1], session: session))
                .to(throwError(UserError.invalidArgumentError(message: "")))
    }

    /// Test that inactive sessions cannot be used.
    func testInactiveSession() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr)
        let session1 = try client.startSession()

        session1.end()
        expect(session1.active).to(beFalse())
        expect(try client.listDatabases(session: session1)).to(throwError(ClientSession.SessionInactiveError))

        let session2 = try client.startSession()
        let database = client.db(type(of: self).testDatabase)
        let collection = database.collection(self.getCollectionName())

        try (1...3).forEach { try collection.insertOne(["x": $0]) }

        let cursor = try collection.find(session: session2)
        expect(cursor.next()).toNot(beNil())
        session2.end()
        expect(try cursor.nextOrError()).to(throwError(ClientSession.SessionInactiveError))
    }

    /// Test cursors have the same lsid in the initial find command and in subsequent getMores.
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

    /// Test that the clusterTime is reported properly.
    func testClusterTime() throws {
        guard MongoSwiftTestCase.topologyType == .sharded else {
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
}
