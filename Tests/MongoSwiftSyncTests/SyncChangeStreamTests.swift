import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

final class SyncChangeStreamTests: MongoSwiftTestCase {
    /// How long in total a change stream should poll for an event or error before returning.
    /// Used as a default value for `ChangeStream.nextWithTimeout`
    public static let TIMEOUT: TimeInterval = 15

    /// Prose test 1 of change stream spec.
    /// "ChangeStream must continuously track the last seen resumeToken"
    func testChangeStreamTracksResumeToken() throws {
        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        try withTestNamespace { _, _, coll in
            let changeStream = try coll.watch()
            for x in 0..<5 {
                try coll.insertOne(["x": BSON(x)])
            }

            expect(changeStream.resumeToken).to(beNil())

            var lastSeen: ResumeToken?
            for _ in 0..<5 {
                let change = try changeStream.nextWithTimeout()
                expect(change).toNot(beNil())
                expect(changeStream.resumeToken).toNot(beNil())
                expect(changeStream.resumeToken).to(equal(change?._id))
                if lastSeen != nil {
                    expect(changeStream.resumeToken).toNot(equal(lastSeen))
                }
                lastSeen = changeStream.resumeToken
            }
        }
    }

    /**
     * Prose test 2 of change stream spec.
     *
     * `ChangeStream` will throw an exception if the server response is missing the resume token (if wire version
     * is < 8, this is a driver-side error; for 8+, this is a server-side error).
     */
    func testChangeStreamMissingId() throws {
        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        try withTestNamespace { client, _, coll in
            let changeStream = try coll.watch([["$project": ["_id": false]]])
            for x in 0..<5 {
                try coll.insertOne(["x": BSON(x)])
            }

            if try client.maxWireVersion() >= 8 {
                let expectedError = MongoError.CommandError.new(
                    code: 280,
                    codeName: "ChangeStreamFatalError",
                    message: "",
                    errorLabels: ["NonResumableChangeStreamError"]
                )
                expect(try changeStream.nextWithTimeout()).to(throwError(expectedError))
            } else {
                expect(try changeStream.next()?.get()).to(throwError(errorType: MongoError.LogicError.self))
            }
        }
    }

    /**
     * Prose test 3 of change stream spec.
     *
     * `ChangeStream` will automatically resume one time on a resumable error (including not writable primary) with the
     * initial pipeline and options, except for the addition/update of a resumeToken.
     */
    func testChangeStreamAutomaticResume() throws {
        let testRequirements = TestRequirement(
            // TODO: SWIFT-1257: remove server version requirement
            maxServerVersion: ServerVersion(major: 4, minor: 9, patch: 0),
            acceptableTopologies: [.replicaSet, .sharded, .shardedReplicaSet, .loadBalanced]
        )

        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(testRequirements)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        guard try MongoClient.makeTestClient().supportsFailCommand() else {
            print("Skipping \(self.name) because server version doesn't support failCommand")
            return
        }

        let events = try captureCommandEvents(
            eventTypes: [.commandStartedEvent],
            commandNames: ["aggregate"]
        ) { client in
            try withTestNamespace(client: client) { _, coll in
                let options = ChangeStreamOptions(
                    batchSize: 123,
                    fullDocument: .updateLookup,
                    maxAwaitTimeMS: 100
                )
                let changeStream = try coll.watch([["$match": ["fullDocument.x": 2]]], options: options)
                for x in 0..<5 {
                    try coll.insertOne(["x": .int64(Int64(x))])
                }

                // notWritablePrimary error
                let failPoint = FailPoint.failCommand(
                    failCommands: ["getMore"],
                    mode: .times(1),
                    errorCode: 10107,
                    errorLabels: ["ResumableChangeStreamError"]
                )
                try failPoint.enable()
                defer { failPoint.disable() }

                // no error should reported to the user.
                while try changeStream.tryNext()?.get() != nil {}
            }
        }
        expect(events.count).to(equal(2))

        let originalCommand = events[0].commandStartedValue!.command
        let resumeCommand = events[1].commandStartedValue!.command

        let originalPipeline = originalCommand["pipeline"]!.arrayValue!.compactMap { $0.documentValue }
        let resumePipeline = resumeCommand["pipeline"]!.arrayValue!.compactMap { $0.documentValue }

        // verify the $changeStream stage is identical except for resume options.
        let filteredStreamStage = { (pipeline: [BSONDocument]) -> BSONDocument in
            let stage = pipeline[0]
            let streamDoc = stage["$changeStream"]?.documentValue
            expect(streamDoc).toNot(beNil())
            return streamDoc!.filter { $0.key != "resumeAfter" }
        }
        expect(filteredStreamStage(resumePipeline)).to(equal(filteredStreamStage(originalPipeline)))

        // verify the pipeline was preserved.
        expect(resumePipeline[1...]).to(equal(originalPipeline[1...]))

        // verify the cursor options were preserved.
        expect(resumeCommand["cursor"]).to(equal(originalCommand["cursor"]))
    }

    /**
     * Prose test 4 of change stream spec.
     *
     * ChangeStream will not attempt to resume on any error encountered while executing an aggregate command.
     */
    func testChangeStreamFailedAggregate() throws {
        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        // turn off retryReads so that retry attempts can be distinguished from resume attempts.
        let opts = MongoClientOptions(retryReads: false)

        try withTestNamespace(MongoClientOptions: opts) { client, _, coll in
            guard try client.supportsFailCommand() else {
                print("Skipping \(self.name) because server version doesn't support failCommand")
                return
            }

            let monitor = client.addCommandMonitor()
            let failpoint = FailPoint.failCommand(failCommands: ["aggregate"], mode: .times(1), errorCode: 10107)
            try failpoint.enable()
            defer { failpoint.disable() }

            try monitor.captureEvents {
                expect(try coll.watch()).to(throwError())
            }
            expect(monitor.commandStartedEvents(withNames: ["aggregate"])).to(haveCount(1))

            // The above failpoint was configured to only run once, so this aggregate will succeed.
            let changeStream = try coll.watch()

            let getMoreFailpoint = FailPoint.failCommand(
                failCommands: ["getMore", "aggregate"],
                mode: .times(2),
                errorCode: 10107,
                errorLabels: ["ResumableChangeStreamError"]
            )
            try getMoreFailpoint.enable()
            defer { getMoreFailpoint.disable() }

            try monitor.captureEvents {
                // getMore failure will trigger resume process, aggregate will fail and not retry again.
                expect(try changeStream.next()?.get()).to(throwError())
            }
            expect(monitor.commandStartedEvents(withNames: ["aggregate"])).to(haveCount(1))
        }
    }

    /**
     * Prose test 7 of change stream spec.
     *
     * Ensure that a cursor returned from an aggregate command with a cursor id and an initial empty batch is not
     * closed on the driver side.
     */
    func testChangeStreamDoesntCloseOnEmptyBatch() throws {
        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        // need to keep the stream alive so its deinit doesn't kill the cursor.
        var changeStream: ChangeStream<ChangeStreamEvent<BSONDocument>>?
        let events = try captureCommandEvents(commandNames: ["killCursors"]) { client in
            try withTestNamespace(client: client) { _, coll in
                changeStream =
                    try coll.watch(options: ChangeStreamOptions(maxAwaitTimeMS: 100))
                _ = try changeStream!.tryNext()?.get()
            }
        }
        expect(events).to(beEmpty())
    }

    /**
     * Prose tests 8 and 10 of change stream spec.
     *
     * The killCursors command sent during the "Resume Process" must not be allowed to throw an exception, and
     * `ChangeStream` will resume after a killCursors command is issued for its child cursor.
     *
     * Note: we're skipping prose test 9 because it tests against a narrow server version range that we don't have as
     * part of our evergreen matrix.
     */
    func testChangeStreamFailedKillCursors() throws {
        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        try withTestNamespace { client, _, collection in
            guard try client.supportsFailCommand() else {
                print("Skipping \(self.name) because server version doesn't support failCommand")
                return
            }

            let monitor = client.addCommandMonitor()
            var changeStream: ChangeStream<ChangeStreamEvent<BSONDocument>>?
            let options = ChangeStreamOptions(batchSize: 1)

            try monitor.captureEvents {
                changeStream = try collection.watch(options: options)
            }

            for _ in 0..<5 {
                try collection.insertOne(["x": 1])
            }

            expect(try changeStream?.nextWithTimeout()).toNot(throwError())

            // kill the underlying cursor to trigger a resume.
            let reply = monitor.commandSucceededEvents(withNames: ["aggregate"]).first!.reply["cursor"]!.documentValue!
            let cursorId = reply["id"]!
            try client.db("admin").runCommand(["killCursors": .string(self.getCollectionName()), "cursors": [cursorId]])

            // Make the killCursors command fail as part of the resume process.
            let failPoint = FailPoint.failCommand(failCommands: ["killCursors"], mode: .times(1), errorCode: 10107)
            try failPoint.enable()
            defer { failPoint.disable() }

            // even if killCursors command fails, no error should be returned to the user.
            for _ in 0..<4 {
                expect(try changeStream?.nextWithTimeout()).toNot(beNil())
            }
        }
    }

    // TODO: SWIFT-567: Implement prose test 11

    /**
     * Prose test 12 of change stream spec.
     *
     * For a ChangeStream under these conditions:
     *   - Running against a server <4.0.7.
     *   - The batch is empty or has been iterated to the last document.
     * Expected result:
     *   - getResumeToken must return the _id of the last document returned if one exists.
     *   - getResumeToken must return resumeAfter from the initial aggregate if the option was specified.
     *   - If resumeAfter was not specified, the getResumeToken result must be empty.
     */
    func testChangeStreamResumeTokenUpdatesEmptyBatch() throws {
        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        try withTestNamespace { client, _, coll in
            guard try client.serverVersion() < ServerVersion(major: 4, minor: 0, patch: 7) else {
                print(unsupportedServerVersionMessage(testName: self.name))
                return
            }

            let basicStream = try coll.watch()
            _ = try basicStream.nextWithTimeout()
            expect(basicStream.resumeToken).to(beNil())
            try coll.insertOne(["x": 1])
            let firstToken = try basicStream.next()?.get()._id
            expect(basicStream.resumeToken).to(equal(firstToken))

            let options = ChangeStreamOptions(resumeAfter: firstToken)
            let resumeStream = try coll.watch(options: options)
            expect(resumeStream.resumeToken).to(equal(firstToken))
            _ = try resumeStream.nextWithTimeout()
            expect(resumeStream.resumeToken).to(equal(firstToken))
            try coll.insertOne(["x": 1])
            let lastId = try resumeStream.nextWithTimeout()?._id
            expect(lastId).toNot(beNil())
            expect(resumeStream.resumeToken).to(equal(lastId))
        }
    }

    /**
     * Prose test 13 of the change stream spec.
     *
     * For a ChangeStream under these conditions:
     *    - The batch is not empty.
     *    - The batch has been iterated up to but not including the last element.
     * Expected result:
     *    - getResumeToken must return the _id of the previous document returned.
     */
    func testChangeStreamResumeTokenUpdatesNonemptyBatch() throws {
        let unmetRequirement = try MongoClient.makeTestClient().getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        try withTestNamespace { client, _, coll in
            guard try client.serverVersion() < ServerVersion(major: 4, minor: 0, patch: 7) else {
                print("Skipping \(self.name) because of unsupported server version")
                return
            }

            let changeStream = try coll.watch()
            for i in 0..<5 {
                try coll.insertOne(["x": BSON(i)])
            }
            for _ in 0..<3 {
                _ = try changeStream.nextWithTimeout()
            }
            let lastId = try changeStream.nextWithTimeout()?._id
            expect(lastId).toNot(beNil())
            expect(changeStream.resumeToken).to(equal(lastId))
        }
    }

    // TODO: SWIFT-576: Implement prose tests 14, 17, & 18

    func testChangeStreamOnAClient() throws {
        let client = try MongoClient.makeTestClient()
        let testRequirements = TestRequirement(
            minServerVersion: ServerVersion(major: 4, minor: 0),
            acceptableTopologies: [.replicaSet, .sharded, .shardedReplicaSet, .loadBalanced]
        )

        let unmetRequirement = try client.getUnmetRequirement(testRequirements)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        let changeStream = try client.watch()

        let db1 = client.db("db1")
        defer { try? db1.drop() }
        let coll1 = db1.collection("coll1")
        let coll2 = db1.collection("coll2")

        let doc1: BSONDocument = ["_id": 1, "a": 1]
        let doc2: BSONDocument = ["_id": 2, "x": 123]
        try coll1.insertOne(doc1)
        try coll2.insertOne(doc2)

        let change1 = try changeStream.nextWithTimeout()
        expect(change1).toNot(beNil())
        expect(change1?.operationType).to(equal(.insert))
        expect(change1?.fullDocument).to(equal(doc1))
        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change1?._id))

        // test that a change exists for a different collection in the same database
        let change2 = try changeStream.nextWithTimeout()
        expect(change2).toNot(beNil())
        expect(change2?.operationType).to(equal(.insert))
        expect(change2?.fullDocument).to(equal(doc2))
        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change2?._id))

        // test that a change exists for a collection in a different database
        let db2 = client.db("db2")
        defer { try? db2.drop() }
        let coll = db2.collection("coll3")

        let doc3: BSONDocument = ["_id": 3, "y": 321]
        try coll.insertOne(doc3)

        let change3 = try changeStream.nextWithTimeout()
        expect(change3).toNot(beNil())
        expect(change3?.operationType).to(equal(.insert))
        expect(change3?.fullDocument).to(equal(doc3))
        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change3?._id))
    }

    func testChangeStreamOnADatabase() throws {
        let client = try MongoClient.makeTestClient()
        let testRequirements = TestRequirement(
            minServerVersion: ServerVersion(major: 4, minor: 0),
            acceptableTopologies: [.replicaSet, .sharded, .shardedReplicaSet, .loadBalanced]
        )

        let unmetRequirement = try client.getUnmetRequirement(testRequirements)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let changeStream = try db.watch(options: ChangeStreamOptions(maxAwaitTimeMS: 100))

        // expect the first iteration to be nil since no changes have been made to the database.
        expect(try changeStream.tryNext()?.get()).to(beNil())

        let coll = db.collection(self.getCollectionName(suffix: "1"))
        let doc1: BSONDocument = ["_id": 1, "a": 1]
        try coll.insertOne(doc1)

        // test that the change stream contains a change document for the `insert` operation
        let change1 = try changeStream.nextWithTimeout()
        expect(change1).toNot(beNil())
        expect(change1?.operationType).to(equal(.insert))
        expect(change1?.fullDocument).to(equal(doc1))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change1?._id))

        // expect the change stream to contain a change document for the `drop` operation
        try db.drop()
        let change2 = try changeStream.nextWithTimeout()
        expect(change2).toNot(beNil())
        expect(change2?.operationType).to(equal(.drop))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change2?._id))
    }

    func testChangeStreamOnACollection() throws {
        let client = try MongoClient.makeTestClient()
        let unmetRequirement = try client.getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let changeStream = try coll.watch(options: options)

        let doc: BSONDocument = ["_id": 1, "x": 1]
        try coll.insertOne(doc)

        // expect the change stream to contain a change document for the `insert` operation
        let change1 = try changeStream.nextWithTimeout()
        expect(change1).toNot(beNil())
        expect(change1?.operationType).to(equal(.insert))
        expect(change1?.fullDocument).to(equal(doc))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change1?._id))

        try coll.updateOne(filter: ["x": 1], update: ["$set": ["x": 2]])

        // expect the change stream to contain a change document for the `update` operation
        let change2 = try changeStream.nextWithTimeout()
        expect(change2).toNot(beNil())
        expect(change2?.operationType).to(equal(.update))
        expect(change2?.fullDocument).to(equal(["_id": 1, "x": 2]))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change2?._id))

        try coll.deleteOne(["x": 2])
        // expect the change stream contains a change document for the `delete` operation
        let change3 = try changeStream.nextWithTimeout()
        expect(change3).toNot(beNil())
        expect(change3?.operationType).to(equal(.delete))

        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change3?._id))
    }

    func testChangeStreamWithPipeline() throws {
        let client = try MongoClient.makeTestClient()
        let unmetRequirement = try client.getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let pipeline: [BSONDocument] = [["$match": ["fullDocument.a": 1]]]
        let changeStream = try coll.watch(pipeline, options: options)

        let doc1: BSONDocument = ["_id": 1, "a": 1]
        try coll.insertOne(doc1)
        let change1 = try changeStream.nextWithTimeout()

        expect(change1).toNot(beNil())
        expect(change1?.operationType).to(equal(.insert))
        expect(change1?.fullDocument).to(equal(doc1))

        // test that a change event does not exists for this insert since this field's been excluded by the pipeline.
        try coll.insertOne(["b": 2])
        let change2 = try changeStream.nextWithTimeout()
        expect(change2).to(beNil())
    }

    func testChangeStreamResumeToken() throws {
        let client = try MongoClient.makeTestClient()
        let unmetRequirement = try client.getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        let changeStream1 = try coll.watch()

        try coll.insertOne(["x": 1])
        try coll.insertOne(["y": 2])
        _ = try changeStream1.nextWithTimeout()

        // save the current resumeToken and use it as the resumeAfter in a new change stream
        let resumeToken = changeStream1.resumeToken
        let options = ChangeStreamOptions(resumeAfter: resumeToken)
        let changeStream2 = try coll.watch(options: options)

        // expect this change stream to have its resumeToken set to the resumeAfter
        expect(changeStream2.resumeToken).to(equal(resumeToken))

        // expect this change stream to have more events after resuming
        expect(try changeStream2.nextWithTimeout()).toNot(beNil())

        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 2) else {
            print("Skipping test case for server version \(try client.serverVersion())")
            return
        }

        // test with startAfter
        _ = try coll.renamed(to: self.getCollectionName(suffix: "2"))

        _ = try changeStream2.nextWithTimeout()
        expect(try changeStream2.nextWithTimeout()?.operationType).to(equal(.invalidate))

        // insert before starting a new change stream with this resumeToken
        try coll.insertOne(["kitty": "cat"])

        let opts = ChangeStreamOptions(startAfter: changeStream2.resumeToken)
        // resuming (with startAfter) after an invalidate event should work
        let changeStream3 = try coll.watch(options: opts)

        try coll.findOneAndUpdate(filter: ["kitty": "cat"], update: ["$set": ["kitty": "kat"]])

        // the new change stream should pick up where the last change stream left off
        expect(try changeStream3.nextWithTimeout()?.operationType).to(equal(.insert))
        expect(try changeStream3.nextWithTimeout()?.operationType).to(equal(.update))
    }

    struct MyFullDocumentType: Codable, Equatable {
        let id: Int
        let x: Int
        let y: Int

        enum CodingKeys: String, CodingKey {
            case id = "_id", x, y
        }
    }

    struct MyEventType: Codable, Equatable {
        let id: BSONDocument
        let operation: String
        let fullDocument: MyFullDocumentType
        let nameSpace: BSONDocument
        let updateDescription: BSONDocument?

        enum CodingKeys: String, CodingKey {
            case id = "_id", operation = "operationType", fullDocument, nameSpace = "ns", updateDescription
        }
    }

    func testChangeStreamWithEventType() throws {
        let client = try MongoClient.makeTestClient()
        let unmetRequirement = try client.getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        // test that the change stream works on a collection when using withEventType
        let collChangeStream = try coll.watch(withEventType: MyEventType.self)

        let doc: BSONDocument = ["_id": 1, "x": 1, "y": 2]
        try coll.insertOne(doc)

        let collChange = try collChangeStream.nextWithTimeout()
        expect(collChange).toNot(beNil())
        expect(collChange?.operation).to(equal("insert"))
        expect(collChange?.fullDocument).to(equal(MyFullDocumentType(id: 1, x: 1, y: 2)))

        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 0) else {
            print("Skipping test case for server version \(try client.serverVersion())")
            return
        }

        // test that the change stream works on client and database when using withEventType
        let clientChangeStream = try client.watch(withEventType: MyEventType.self)
        let dbChangeStream = try db.watch(withEventType: MyEventType.self)

        let expectedFullDocument = MyFullDocumentType(id: 2, x: 1, y: 2)

        try coll.insertOne(["_id": 2, "x": 1, "y": 2])

        let clientChange = try clientChangeStream.nextWithTimeout()
        expect(clientChange).toNot(beNil())
        expect(clientChange?.operation).to(equal("insert"))
        expect(clientChange?.fullDocument).to(equal(expectedFullDocument))

        let dbChange = try dbChangeStream.nextWithTimeout()
        expect(dbChange).toNot(beNil())
        expect(dbChange?.operation).to(equal("insert"))
        expect(dbChange?.fullDocument).to(equal(expectedFullDocument))
    }

    func testChangeStreamWithFullDocumentType() throws {
        let expectedDoc1 = MyFullDocumentType(id: 1, x: 1, y: 2)

        let client = try MongoClient.makeTestClient()
        let unmetRequirement = try client.getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }

        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        // test that the change stream works on a collection when using withFullDocumentType
        let collChangeStream = try coll.watch(withFullDocumentType: MyFullDocumentType.self)
        try coll.insertOne(["_id": 1, "x": 1, "y": 2])
        let collChange = try collChangeStream.nextWithTimeout()
        expect(collChange).toNot(beNil())
        expect(collChange?.fullDocument).to(equal(expectedDoc1))

        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 0) else {
            print("Skipping test case for server version \(try client.serverVersion())")
            return
        }

        // test that the change stream works on client and database when using withFullDocumentType
        let clientChangeStream = try client.watch(withFullDocumentType: MyFullDocumentType.self)
        let dbChangeStream = try db.watch(withFullDocumentType: MyFullDocumentType.self)

        let expectedDoc2 = MyFullDocumentType(id: 2, x: 1, y: 2)
        try coll.insertOne(["_id": 2, "x": 1, "y": 2])

        let clientChange = try clientChangeStream.nextWithTimeout()
        expect(clientChange).toNot(beNil())
        expect(clientChange?.fullDocument).to(equal(expectedDoc2))

        let dbChange = try dbChangeStream.nextWithTimeout()
        expect(dbChange).toNot(beNil())
        expect(dbChange?.fullDocument).to(equal(expectedDoc2))
    }

    struct MyType: Codable, Equatable {
        let foo: String
        let bar: Int
    }

    func testChangeStreamOnACollectionWithCodableType() throws {
        let client = try MongoClient.makeTestClient()
        let unmetRequirement = try client.getUnmetRequirement(.changeStreamOnCollectionSupport)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }

        let coll = try db.createCollection(self.getCollectionName(suffix: "1"), withType: MyType.self)
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let changeStream = try coll.watch(options: options)

        let myType = MyType(foo: "blah", bar: 123)
        try coll.insertOne(myType)

        let change = try changeStream.nextWithTimeout()
        expect(change).toNot(beNil())
        expect(change?.operationType).to(equal(.insert))
        expect(change?.fullDocument).to(equal(myType))
    }

    func testChangeStreamLazySequence() throws {
        // skip sharded since this test would take longer than necessary.
        let client = try MongoClient.makeTestClient()
        let testRequirements = TestRequirement(
            acceptableTopologies: [.replicaSet]
        )
        let unmetRequirement = try client.getUnmetRequirement(testRequirements)
        guard unmetRequirement == nil else {
            printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
            return
        }

        // Verify that map/filter are lazy by using a change stream.
        try self.withTestNamespace { _, _, coll in
            let stream = try coll.watch()

            _ = try coll.insertMany([["_id": 1], ["_id": 2], ["_id": 3]])

            // verify the cursor is lazy and doesn't block indefinitely.
            let results = try executeWithTimeout(timeout: 1) { () -> [Int] in
                var results: [Int] = []
                // If the filter or map below eagerly exhausted the cursor, then the body of the for loop would
                // never execute, since the tailable cursor would be blocked in a `next` call indefinitely.
                // Because they're lazy, the for loop will execute its body 3 times for each available result then
                // return manually when count == 3.
                for id in stream.filter({ $0.isSuccess }).compactMap({ try! $0.get().fullDocument?["_id"]?.toInt() }) {
                    results.append(id)
                    if results.count == 3 {
                        return results
                    }
                }
                return results
            }
            expect(results.sorted()).to(equal([1, 2, 3]))
            expect(stream.isAlive()).to(beTrue())
            stream.kill()
            expect(stream.isAlive()).to(beFalse())
        }
    }

    /// Test that we properly manually populate the `ns` field of `ChangeStreamEvent`s for invalidate events on
    /// collections.
    func testDecodingInvalidateEventsOnCollection() throws {
        // invalidated change stream on a collection
        try self.withTestNamespace { client, _, collection in
            let unmetRequirement = try MongoClient
                .makeTestClient()
                .getUnmetRequirement(.changeStreamOnCollectionSupport)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }

            let stream = try collection.watch()

            // insert to create the collection
            try collection.insertOne(["x": 1])
            let insertEvent = try stream.next()?.get()
            expect(insertEvent?.operationType).to(equal(.insert))

            // drop the collection to generate an invalidate event
            try collection.drop()

            // as of 4.0.1, the server first emits a drop event and then an invalidate event.
            // on 3.6, there is only an invalidate event.
            if try client.serverVersion() >= ServerVersion(major: 4, minor: 0, patch: 1) {
                let drop = try stream.next()?.get()
                expect(drop?.operationType).to(equal(.drop))
            }

            let invalidate = try stream.next()?.get()
            expect(invalidate?.operationType).to(equal(.invalidate))
            expect(invalidate?.ns).to(equal(collection.namespace))
        }
    }

    /// Test that we properly manually populate the `ns` field of `ChangeStreamEvent`s for invalidate events on
    /// databases.
    func testDecodingInvalidateEventsOnDatabase() throws {
        // invalidated change stream on a DB
        try self.withTestNamespace { client, db, collection in
            // DB change streams are supported as of 4.0
            let unmetRequirement = try client.getUnmetRequirement(.changeStreamOnDBOrClientSupport)
            guard unmetRequirement == nil else {
                printSkipMessage(testName: self.name, unmetRequirement: unmetRequirement!)
                return
            }

            let stream = try db.watch()

            // insert to collection to create the db
            try collection.insertOne(["x": 1])
            let insertEvent = try stream.next()?.get()
            expect(insertEvent?.operationType).to(equal(.insert))

            // drop the db to generate an invalidate event
            try db.drop()
            // first we see collection drop, then db drop
            let dropColl = try stream.next()?.get()
            expect(dropColl?.operationType).to(equal(.drop))
            let dropDB = try stream.next()?.get()
            expect(dropDB?.operationType).to(equal(.dropDatabase))

            let invalidate = try stream.next()?.get()
            expect(invalidate?.operationType).to(equal(.invalidate))
            expect(invalidate?.ns.db).to(equal(db.name))
            expect(invalidate?.ns.collection).to(beNil())
        }
    }
}
