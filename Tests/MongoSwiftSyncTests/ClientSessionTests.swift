import Foundation
@testable import class MongoSwift.ClientSession
@testable import MongoSwiftSync
import Nimble
import TestsCommon

/// Describes an operation run on a collection that takes in a session.
struct CollectionSessionOp {
    let name: String
    let body: (MongoCollection<BSONDocument>, MongoSwiftSync.ClientSession?) throws -> Void
}

/// Describes an operation run on a database that takes in a session.
struct DatabaseSessionOp {
    let name: String
    let body: (MongoDatabase, MongoSwiftSync.ClientSession?) throws -> Void
}

/// Describes an operation run on a client that takes in a session.
struct ClientSessionOp {
    let name: String
    let body: (MongoClient, MongoSwiftSync.ClientSession?) throws -> Void
}

final class SyncClientSessionTests: MongoSwiftTestCase {
    override func tearDown() {
        do {
            let client = try MongoClient.makeTestClient()
            try client.db(Self.testDatabase).drop()
        } catch let commandError as MongoError.CommandError where commandError.code == 26 {
            // skip database not found errors
        } catch {
            fail("encountered error when tearing down: \(error)")
        }
        super.tearDown()
    }

    typealias SessionOp = (name: String, body: (MongoSwiftSync.ClientSession?) throws -> Void)

    // list of read only operations on MongoCollection that take in a session
    let collectionSessionReadOps = [
        CollectionSessionOp(name: "find") { _ = try $0.find([:], session: $1).next()?.get() },
        CollectionSessionOp(name: "findOne") { _ = try $0.findOne([:], session: $1) },
        CollectionSessionOp(name: "aggregate") { _ = try $0.aggregate([], session: $1).next()?.get() },
        CollectionSessionOp(name: "distinct") { _ = try $0.distinct(fieldName: "x", session: $1) },
        CollectionSessionOp(name: "countDocuments") { _ = try $0.countDocuments(session: $1) }
    ]

    // list of write operations on MongoCollection that take in a session
    let collectionSessionWriteOps = [
        CollectionSessionOp(name: "bulkWrite") { _ = try $0.bulkWrite([.insertOne([:])], session: $1) },
        CollectionSessionOp(name: "insertOne") { _ = try $0.insertOne([:], session: $1) },
        CollectionSessionOp(name: "insertMany") { _ = try $0.insertMany([[:]], session: $1) },
        CollectionSessionOp(name: "replaceOne") { _ = try $0.replaceOne(filter: [:], replacement: [:], session: $1) },
        CollectionSessionOp(name: "updateOne") { _ = try $0.updateOne(filter: [:], update: [:], session: $1) },
        CollectionSessionOp(name: "updateMany") { _ = try $0.updateMany(filter: [:], update: [:], session: $1) },
        CollectionSessionOp(name: "deleteOne") { _ = try $0.deleteOne([:], session: $1) },
        CollectionSessionOp(name: "deleteMany") { _ = try $0.deleteMany([:], session: $1) },
        CollectionSessionOp(name: "createIndex") { _ = try $0.createIndex([:], session: $1) },
        CollectionSessionOp(name: "createIndex1") { _ = try $0.createIndex(IndexModel(keys: ["x": 1]), session: $1) },
        CollectionSessionOp(name: "createIndexes") {
            _ = try $0.createIndexes([IndexModel(keys: ["x": 1])], session: $1)
        },
        CollectionSessionOp(name: "dropIndex") { _ = try $0.dropIndex(["x": 1], session: $1) },
        CollectionSessionOp(name: "dropIndex1") { _ = try $0.dropIndex(IndexModel(keys: ["x": 3]), session: $1) },
        CollectionSessionOp(name: "dropIndex2") { _ = try $0.dropIndex("x_7", session: $1) },
        CollectionSessionOp(name: "dropIndexes") { _ = try $0.dropIndexes(session: $1) },
        CollectionSessionOp(name: "listIndexes") { _ = try $0.listIndexes(session: $1).next() },
        CollectionSessionOp(name: "findOneAndDelete") {
            _ = try $0.findOneAndDelete([:], session: $1)
        },
        CollectionSessionOp(name: "findOneAndReplace") {
            _ = try $0.findOneAndReplace(filter: [:], replacement: [:], session: $1)
        },
        CollectionSessionOp(name: "findOneAndUpdate") {
            _ = try $0.findOneAndUpdate(filter: [:], update: [:], session: $1)
        },
        CollectionSessionOp(name: "drop") { _ = try $0.drop(session: $1) }
    ]

    // list of operations on MongoDatabase that take in a session
    let databaseSessionOps = [
        DatabaseSessionOp(name: "listCollections") { _ = try $0.listCollections(session: $1).next() },
        DatabaseSessionOp(name: "runCommand") { try $0.runCommand(["isMaster": 0], session: $1) },
        DatabaseSessionOp(name: "createCollection") { _ = try $0.createCollection("asdf", session: $1) },
        DatabaseSessionOp(name: "createCollection1") {
            _ = try $0.createCollection("asf", withType: BSONDocument.self, session: $1)
        },
        DatabaseSessionOp(name: "drop") { _ = try $0.drop(session: $1) }
    ]

    // list of operatoins on MongoClient that take in a session
    let clientSessionOps = [
        ClientSessionOp(name: "listDatabases") { _ = try $0.listDatabases(session: $1) },
        ClientSessionOp(name: "listMongoDatabases") { _ = try $0.listMongoDatabases(session: $1) },
        ClientSessionOp(name: "listDatabaseNames") { _ = try $0.listDatabaseNames(session: $1) }
    ]

    /// iterate over all the different session op types, passing in the provided client/db/collection as needed.
    func forEachSessionOp(
        client: MongoClient,
        database: MongoDatabase,
        collection: MongoCollection<BSONDocument>,
        _ body: (SessionOp) throws -> Void
    ) rethrows {
        try (self.collectionSessionReadOps + self.collectionSessionWriteOps).forEach { op in
            try body((name: op.name, body: { try op.body(collection, $0) }))
        }
        try self.databaseSessionOps.forEach { op in
            try body((name: op.name, body: { try op.body(database, $0) }))
        }
        try self.clientSessionOps.forEach { op in
            try body((name: op.name, body: { try op.body(client, $0) }))
        }
    }

    /// Sessions spec test 1: Test that sessions are properly returned to the pool when ended.
    func testSessionCleanup() throws {
        let client = try MongoClient.makeTestClient()

        var sessionA: MongoSwiftSync.ClientSession? = client.startSession()
        // use the session to trigger starting the libmongoc session
        _ = try client.listDatabases(session: sessionA)
        expect(sessionA!.active).to(beTrue())

        var sessionB: MongoSwiftSync.ClientSession? = client.startSession()
        _ = try client.listDatabases(session: sessionB)
        expect(sessionB!.active).to(beTrue())

        let idA = sessionA!.id
        let idB = sessionB!.id

        // test via deinit
        sessionA = nil
        sessionB = nil

        let sessionC = client.startSession()
        _ = try client.listDatabases(session: sessionC)
        expect(sessionC.active).to(beTrue())
        expect(sessionC.id).to(equal(idB))

        let sessionD = client.startSession()
        _ = try client.listDatabases(session: sessionD)
        expect(sessionD.active).to(beTrue())
        expect(sessionD.id).to(equal(idA))

        // test via explicitly ending
        sessionC.end()
        expect(sessionC.active).to(beFalse())
        sessionD.end()
        expect(sessionD.active).to(beFalse())

        // test via withSession
        try client.withSession { session in
            _ = try client.listDatabases(session: session)
            expect(session.id).to(equal(idA))
        }

        try client.withSession { session in
            _ = try client.listDatabases(session: session)
            expect(session.id).to(equal(idA))
        }

        try client.withSession { session in
            _ = try client.listDatabases(session: session)
            expect(session.id).to(equal(idA))
            try client.withSession { nestedSession in
                _ = try client.listDatabases(session: nestedSession)
                expect(nestedSession.id).to(equal(idB))
            }
        }
    }

    // Executes the body twice, once with the supplied session and once without, verifying that a correct lsid is
    // seen both times.
    func runArgTest(monitor: TestCommandMonitor, session: MongoSwiftSync.ClientSession, op: SessionOp) throws {
        monitor.captureEvents {
            // We don't care if they succeed (e.g. a drop index may fail if index doesn't exist)
            try? op.body(session)
            try? op.body(nil)
        }

        let capturedEvents = monitor.commandStartedEvents()
        expect(capturedEvents).to(haveCount(2))
        expect(capturedEvents[0].command["lsid"]).to(equal(.document(session.id!)), description: op.name)
        let implicitId = capturedEvents[1].command["lsid"]
        expect(implicitId).toNot(beNil())
        expect(implicitId).toNot(equal(.document(session.id!)), description: op.name)
    }

    /// Sessions spec test 3: test that every function that takes a session parameter passes the sends implicit and
    /// explicit lsids to server.
    func testSessionArguments() throws {
        let client1 = try MongoClient.makeTestClient()
        let monitor = client1.addCommandMonitor()
        let database = client1.db(Self.testDatabase)
        let collection = try database.createCollection(self.getCollectionName())
        let session = client1.startSession()

        try self.forEachSessionOp(client: client1, database: database, collection: collection) { op in
            try runArgTest(monitor: monitor, session: session, op: op)
        }
    }

    /// Sessions spec test 4: test that a session can only be used with db's and collections that were derived from the
    /// same client.
    func testSessionClientValidation() throws {
        let client1 = try MongoClient.makeTestClient()
        let client2 = try MongoClient.makeTestClient()

        let database = client1.db(Self.testDatabase)
        let collection = try database.createCollection(self.getCollectionName())

        let session = client2.startSession()
        try self.forEachSessionOp(client: client1, database: database, collection: collection) { op in
            expect(try op.body(session))
                .to(throwError(errorType: MongoError.InvalidArgumentError.self), description: op.name)
        }
    }

    /// Sessions spec test 5: Test that inactive sessions cannot be used.
    func testInactiveSession() throws {
        let client = try MongoClient.makeTestClient()
        let db = client.db(Self.testDatabase)
        let collection = try db.createCollection(self.getCollectionName())
        let session1 = client.startSession()

        session1.end()
        expect(session1.active).to(beFalse())

        try self.forEachSessionOp(client: client, database: db, collection: collection) { op in
            expect(try op.body(session1)).to(
                throwError(
                    MongoSwift.ClientSession.SessionInactiveError),
                description: op.name
            )
        }

        let session2 = client.startSession()
        let database = client.db(Self.testDatabase)
        let collection1 = database.collection(self.getCollectionName())

        try (1...3).forEach { try collection1.insertOne(["x": BSON($0)]) }

        let cursor = try collection.find(session: session2)
        expect(cursor.next()).toNot(beNil())
        session2.end()
        expect(try cursor.next()?.get()).to(throwError(MongoSwift.ClientSession.SessionInactiveError))
    }

    /// Sessions spec test 10: Test cursors have the same lsid in the initial find command and in subsequent getMores.
    func testSessionCursor() throws {
        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()

        let database = client.db(Self.testDatabase)
        let collection = try database.createCollection(self.getCollectionName())
        let session = client.startSession()

        for x in 1...3 {
            // use the session to trigger starting the libmongoc session
            try collection.insertOne(["x": BSON(x)], session: session)
        }

        // explicit
        try monitor.captureEvents {
            let cursor = try collection.find(options: FindOptions(batchSize: 2), session: session)
            expect(cursor.next()).toNot(beNil())
            expect(cursor.next()).toNot(beNil())
            expect(cursor.next()).toNot(beNil())
        }

        let explicitEvents = monitor.commandStartedEvents(withNames: ["find", "getMore"])
        expect(explicitEvents).to(haveCount(2))
        expect(explicitEvents[0].commandName).to(equal("find"))
        expect(explicitEvents[0].command["lsid"]).to(equal(.document(session.id!)))
        expect(explicitEvents[1].commandName).to(equal("getMore"))
        expect(explicitEvents[1].command["lsid"]).to(equal(.document(session.id!)))

        // implicit
        try monitor.captureEvents {
            let cursor1 = try collection.find(options: FindOptions(batchSize: 2))
            expect(cursor1.next()).toNot(beNil())
            expect(cursor1.next()).toNot(beNil())
            expect(cursor1.next()).toNot(beNil())
        }

        let implicitEvents = monitor.commandStartedEvents(withNames: ["find", "getMore"])
        expect(implicitEvents).to(haveCount(2))
        expect(implicitEvents[0].commandName).to(equal("find"))
        let id = implicitEvents[0].command["lsid"]
        expect(id).toNot(beNil())
        expect(implicitEvents[1].commandName).to(equal("getMore"))
        expect(implicitEvents[1].command["lsid"]).to(equal(id))
    }

    /// Sessions spec test 11: Test that the clusterTime is reported properly.
    func testClusterTime() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()

        try client.withSession { session in
            expect(session.clusterTime).to(beNil())
            _ = try client.listDatabases(session: session)
            expect(session.clusterTime).toNot(beNil())
        }

        client.withSession { session in
            let date = Date()
            expect(session.clusterTime).to(beNil())
            let newTime: BSONDocument = [
                "clusterTime": .timestamp(BSONTimestamp(timestamp: Int(date.timeIntervalSince1970), inc: 100))
            ]
            session.advanceClusterTime(to: newTime)
            expect(session.clusterTime).to(equal(newTime))
        }
    }

    /// Test that causal consistency guarantees are met on deployments that support cluster time.
    func testCausalConsistency() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()
        let db = client.db(Self.testDatabase)
        let collection = try db.createCollection(self.getCollectionName())

        // Causal consistency spec test 3: the first read/write on a session should update the operationTime of a
        // session.
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            try monitor.captureEvents {
                _ = try collection.countDocuments(session: session)
            }

            let succeededEvents = monitor.commandSucceededEvents()
            expect(succeededEvents).toNot(beEmpty())
            let replyOpTime = succeededEvents[0].reply["operationTime"]?.timestampValue
            expect(replyOpTime).toNot(beNil())
            expect(replyOpTime).to(equal(session.operationTime))
        }

        // Causal consistency spec test 3: the first read/write on a session should update the operationTime of a
        // session, even when there is an error.
        client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            _ = try? db.runCommand(["insert": "foo", "bar": "bar"], session: session)
            expect(session.operationTime).toNot(beNil())
        }

        // Causal consistency spec test 4: A find followed by any other read operation should
        // include the operationTime returned by the server for the first operation in the afterClusterTime parameter of
        // the second operation
        //
        // Causal consistency spec test 8: When using the default server ReadConcern the readConcern parameter in the
        // command sent to the server should not include a level field
        try self.collectionSessionReadOps.forEach { op in
            try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
                _ = try collection.find(session: session).next()
                let opTime = session.operationTime

                try monitor.captureEvents {
                    try op.body(collection, session)
                }

                let startedEvents = monitor.commandStartedEvents()
                expect(startedEvents).toNot(beEmpty(), description: op.name)
                for event in startedEvents {
                    let readConcern = event.command["readConcern"]?.documentValue
                    expect(readConcern).toNot(beNil(), description: op.name)
                    expect(readConcern!["afterClusterTime"]?.timestampValue).to(equal(opTime), description: op.name)
                    expect(readConcern!["level"]).to(beNil(), description: op.name)
                }
            }
        }

        // Causal consistency spec test 5: Any write operation followed by a find operation should include the
        // operationTime of the first operation in the afterClusterTime parameter of the second operation, including the
        // case where the first operation returned an error
        try self.collectionSessionWriteOps.forEach { op in
            try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
                try? op.body(collection, session)
                let opTime = session.operationTime

                try monitor.captureEvents {
                    _ = try collection.find(session: session).next()
                }

                let startedEvents = monitor.commandStartedEvents(withNames: ["find"])
                expect(startedEvents).toNot(beEmpty(), description: op.name)
                expect(startedEvents[0].command["readConcern"]?.documentValue?["afterClusterTime"]?.timestampValue)
                    .to(equal(opTime), description: op.name)
            }
        }

        // Causal consistency spec test 6: A read operation in a ClientSession that is not causally consistent should
        // not include the afterClusterTime parameter in the command sent to the server
        try client.withSession(options: ClientSessionOptions(causalConsistency: false)) { session in
            _ = try collection.countDocuments(session: session)

            try monitor.captureEvents {
                _ = try collection.countDocuments(session: session)
            }

            let startedEvents = monitor.commandStartedEvents()
            expect(startedEvents).to(haveCount(1))
            expect(startedEvents[0].command["readConcern"]?.documentValue?["afterClusterTime"]).to(beNil())
        }

        // Causal consistency spec test 9: When using a custom ReadConcern the readConcern field in the command sent to
        // the server should be a merger of the ReadConcern value and the afterClusterTime field
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            let collection1 = db.collection(
                self.getCollectionName(),
                options: MongoCollectionOptions(readConcern: .local)
            )
            _ = try collection1.countDocuments(session: session)
            let opTime = session.operationTime

            try monitor.captureEvents {
                _ = try collection1.countDocuments(session: session)
            }

            let startedEvents = monitor.commandStartedEvents()
            expect(startedEvents).to(haveCount(1))
            let readConcern = startedEvents[0].command["readConcern"]?.documentValue
            expect(readConcern).toNot(beNil())
            expect(readConcern!["afterClusterTime"]?.timestampValue).to(equal(opTime))
            expect(readConcern!["level"]).to(equal("local"))
        }

        // Causal consistency spec test 12: When connected to a deployment that does support cluster times messages sent
        // to the server should include $clusterTime
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            try monitor.captureEvents {
                _ = try collection.countDocuments(session: session)
            }

            let startedEvents = monitor.commandStartedEvents()
            expect(startedEvents).to(haveCount(1))
            expect(startedEvents[0].command["$clusterTime"]).toNot(beNil())
        }
    }

    /// Test causal consistent behavior on a topology that doesn't support cluster time.
    func testCausalConsistencyStandalone() throws {
        guard MongoSwiftTestCase.topologyType == .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()
        let db = client.db(Self.testDatabase)
        let collection = db.collection(self.getCollectionName())

        // Causal consistency spec test 7: A read operation in a causally consistent session against a deployment that
        // does not support cluster times does not include the afterClusterTime parameter in the command sent to the
        // server
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            _ = try collection.countDocuments(session: session)

            try monitor.captureEvents {
                _ = try collection.countDocuments(session: session)
            }

            let startedEvents = monitor.commandStartedEvents()
            expect(startedEvents).to(haveCount(1))
            expect(startedEvents[0].command["readConcern"]?.documentValue?["afterClusterTime"]).to(beNil())
        }

        // Causal consistency spec test 11: When connected to a deployment that does not support cluster times messages
        // sent to the server should not include $clusterTime
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            _ = try collection.insertOne([:], session: session)

            try monitor.captureEvents {
                _ = try collection.countDocuments(session: session)
            }

            let startedEvents = monitor.commandStartedEvents()
            expect(startedEvents).to(haveCount(1))
            expect(startedEvents[0].command["$clusterTime"]).to(beNil())
        }
    }

    /// Test causal consistent behavior that is expected on any topology, regardless of whether it supports cluster time
    func testCausalConsistencyAnyTopology() throws {
        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()
        let db = client.db(Self.testDatabase)
        let collection = db.collection(self.getCollectionName())

        // Causal consistency spec test 1: When a ClientSession is first created the operationTime has no value
        let session1 = client.startSession()
        expect(session1.operationTime).to(beNil())
        session1.end()

        // Causal consistency spec test 2: The first read in a causally consistent session must not send
        // afterClusterTime to the server (because the operationTime has not yet been determined)
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            try monitor.captureEvents {
                _ = try collection.countDocuments(session: session)
            }

            let startedEvents = monitor.commandStartedEvents()
            expect(startedEvents).to(haveCount(1))
            expect(startedEvents[0].command["readConcern"]?.documentValue?["afterClusterTime"]).to(beNil())
        }

        // Causal consistency spec test 10: When an unacknowledged write is executed in a causally consistent
        // ClientSession the operationTime property of the ClientSession is not updated
        try client.withSession(options: ClientSessionOptions(causalConsistency: true)) { session in
            let collection1 = db.collection(
                self.getCollectionName(),
                options: MongoCollectionOptions(writeConcern: try WriteConcern(w: .number(0)))
            )
            try collection1.insertOne(["x": 3])
            expect(session.operationTime).to(beNil())
        }
    }
}
