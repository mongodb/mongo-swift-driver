import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

/// The entity on which to start a change stream.
internal enum ChangeStreamTarget: String, Decodable {
    /// Indicates the change stream will be opened to watch a client.
    case client

    /// Indicates the change stream will be opened to watch a database.
    case database

    /// Indicates the change stream will be opened to watch a collection.
    case collection

    /// Open a change stream against this target. An error will be thrown if the necessary namespace information is not
    /// provided.
    internal func watch(
        _ client: MongoClient,
        _ database: String?,
        _ collection: String?,
        _ pipeline: [Document],
        _ options: ChangeStreamOptions
    ) throws -> ChangeStream<Document> {
        switch self {
        case .client:
            return try client.watch(pipeline, options: options, withEventType: Document.self)
        case .database:
            guard let database = database else {
                throw TestError(message: "missing db in watch")
            }
            return try client.db(database).watch(pipeline, options: options, withEventType: Document.self)
        case .collection:
            guard let collection = collection, let database = database else {
                throw TestError(message: "missing db or collection in watch")
            }
            return try client.db(database)
                .collection(collection)
                .watch(pipeline, options: options, withEventType: Document.self)
        }
    }
}

/// An operation performed as part of a `ChangeStreamTest` (e.g. a CRUD operation, an drop, etc.)
/// This struct includes the namespace against which it should be run.
internal struct ChangeStreamTestOperation: Decodable {
    /// The operation itself to run.
    private let operation: AnyTestOperation

    /// The database to run the operation against.
    private let database: String

    /// The collection to run the operation against.
    private let collection: String

    private enum CodingKeys: String, CodingKey {
        case database, collection
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.database = try container.decode(String.self, forKey: .database)
        self.collection = try container.decode(String.self, forKey: .collection)
        self.operation = try AnyTestOperation(from: decoder)
    }

    /// Run the operation against the namespace associated with this operation.
    internal func execute(using client: MongoClient) throws -> TestOperationResult? {
        let db = client.db(self.database)
        let coll = db.collection(self.collection)
        return try self.operation.op.execute(on: coll, sessions: [:])
    }
}

/// The outcome of a given `ChangeStreamTest`.
internal enum ChangeStreamTestResult: Decodable {
    /// Describes an error received during the test
    case error(code: Int, labels: [String]?)

    /// An array of event documents expected to be received from the change stream without error during the test.
    case success([Document])

    /// Top-level coding keys. Used for determining whether this result is a success or failure.
    internal enum CodingKeys: CodingKey {
        case error, success
    }

    /// Coding keys used specifically for decoding the `.error` case.
    internal enum ErrorCodingKeys: CodingKey {
        case code, errorLabels
    }

    /// Asserts that the given error matches the one expected by this result.
    internal func assertMatchesError(error: Error, description: String) {
        guard case let .error(code, labels) = self else {
            fail("\(description) failed: got error but result success")
            return
        }
        guard let seenError = error as? CommandError else {
            fail("\(description) failed: didn't get command error")
            return
        }

        expect(seenError.code).to(equal(code), description: description)
        if let labels = labels {
            expect(seenError.errorLabels).toNot(beNil(), description: description)
            expect(seenError.errorLabels).to(equal(labels), description: description)
        } else {
            expect(seenError.errorLabels).to(beNil(), description: description)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.success) {
            self = .success(try container.decode([Document].self, forKey: .success))
        } else {
            let nested = try container.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .error)
            let code = try nested.decode(Int.self, forKey: .code)
            let labels = try nested.decodeIfPresent([String].self, forKey: .errorLabels)
            self = .error(code: code, labels: labels)
        }
    }
}

/// Struct representing a single test within a spec test JSON file.
internal struct ChangeStreamTest: Decodable, FailPointConfigured {
    /// The title of this test.
    let description: String

    /// The minimum server version that this test can be run against.
    let minServerVersion: ServerVersion

    /// The fail point that should be set prior to running this test.
    let failPoint: FailPoint?

    /// The entity on which to run the change stream.
    let target: ChangeStreamTarget

    /// An array of server topologies against which to run the test.
    let topology: [String]

    /// An array of additional aggregation pipeline stages to pass to the `watch` used to create the change stream for
    /// this test.
    let changeStreamPipeline: [Document]

    /// Additional options to pass to the `watch` used to create the change stream for this test.
    let changeStreamOptions: ChangeStreamOptions

    /// An array of documents, each describing an operation that should be run as part of this test.
    let operations: [ChangeStreamTestOperation]

    /// A list of command-started events that are expected to have been emitted by the client that starts the change
    /// stream for this test.
    let expectations: [TestCommandStartedEvent]?

    // The expected result of running this test.
    let result: ChangeStreamTestResult

    var activeFailPoint: FailPoint?

    internal mutating func run(globalClient: MongoClient, database: String, collection: String) throws {
        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()

        if let failPoint = self.failPoint {
            try self.activateFailPoint(failPoint)
        }
        defer { self.disableActiveFailPoint() }

        monitor.captureEvents {
            do {
                let changeStream = try self.target.watch(
                    client,
                    database,
                    collection,
                    self.changeStreamPipeline,
                    self.changeStreamOptions
                )
                for operation in self.operations {
                    _ = try operation.execute(using: globalClient)
                }

                switch self.result {
                case .error:
                    _ = try changeStream.nextWithTimeout()
                    fail("\(self.description) failed: expected error but got none while iterating")
                case let .success(events):
                    var seenEvents: [Document] = []
                    for _ in 0..<events.count {
                        let event = try changeStream.tryNext()?.get()
                        expect(event).toNot(beNil(), description: self.description)
                        seenEvents.append(event!)
                    }
                    expect(seenEvents).to(match(events), description: self.description)
                }
            } catch {
                self.result.assertMatchesError(error: error, description: self.description)
            }
        }

        if let expectations = self.expectations {
            let commandEvents = monitor.commandStartedEvents()
                .filter { $0.commandName != "isMaster" }
                .map { TestCommandStartedEvent(from: $0) }
            expect(commandEvents).to(match(expectations), description: self.description)
        }
    }
}

/// Struct representing a single change-streams spec test JSON file.
private struct ChangeStreamTestFile: Decodable {
    private enum CodingKeys: String, CodingKey {
        case databaseName = "database_name",
            collectionName = "collection_name",
            database2Name = "database2_name",
            collection2Name = "collection2_name",
            tests
    }

    /// The default database.
    let databaseName: String

    /// The default collection.
    let collectionName: String

    /// Secondary database.
    let database2Name: String

    // Secondary collection.
    let collection2Name: String

    /// An array of tests that are to be run independently of each other.
    let tests: [ChangeStreamTest]
}

/// Class covering the JSON spec tests associated with change streams.
final class ChangeStreamSpecTests: MongoSwiftTestCase {
    func testChangeStreamSpec() throws {
        let tests = try retrieveSpecTestFiles(specName: "change-streams", asType: ChangeStreamTestFile.self)

        let globalClient = try MongoClient.makeTestClient()

        let version = try globalClient.serverVersion()
        let topology = MongoSwiftTestCase.topologyType

        for (testName, testFile) in tests {
            let db1 = globalClient.db(testFile.databaseName)
            let db2 = globalClient.db(testFile.database2Name)
            defer {
                try? db1.drop()
                try? db2.drop()
            }
            print("\n------------\nExecuting tests from file \(testName)...\n")
            for var test in testFile.tests {
                let testTopologies = test.topology.map { TopologyDescription.TopologyType(from: $0) }
                guard testTopologies.contains(topology) else {
                    print(unsupportedTopologyMessage(testName: test.description, topology: topology))
                    continue
                }

                guard version >= test.minServerVersion else {
                    print("Skipping test case \"\(test.description)\": minimum required server " +
                        "version \(test.minServerVersion) not met.")
                    continue
                }

                guard !(test.description == "Change Stream should error when _id is projected out" &&
                    version >= ServerVersion(major: 4, minor: 3, patch: 3)) else {
                    print("Skipping test case \"\(test.description)\"; see SWIFT-722")
                    continue
                }

                print("Executing test: \(test.description)")

                try db1.drop()
                try db2.drop()
                _ = try db1.createCollection(testFile.collectionName)
                _ = try db2.createCollection(testFile.collection2Name)

                try test.run(
                    globalClient: globalClient,
                    database: testFile.databaseName,
                    collection: testFile.collectionName
                )
            }
        }
    }
}

/// Class for spec prose tests and other integration tests associated with change streams.
final class SyncChangeStreamTests: MongoSwiftTestCase {
    /// How long in total a change stream should poll for an event or error before returning.
    /// Used as a default value for `ChangeStream.nextWithTimeout`
    public static let TIMEOUT: TimeInterval = 15

    /// Prose test 1 of change stream spec.
    /// "ChangeStream must continuously track the last seen resumeToken"
    func testChangeStreamTracksResumeToken() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        guard try MongoClient.makeTestClient().serverVersion() < ServerVersion(major: 4, minor: 3, patch: 3) else {
            print("Skipping test; see SWIFT-722")
            return
        }

        try withTestNamespace { client, _, coll in
            let changeStream = try coll.watch([["$project": ["_id": false]]])
            for x in 0..<5 {
                try coll.insertOne(["x": BSON(x)])
            }

            if try client.maxWireVersion() >= 8 {
                let expectedError = CommandError.new(
                    code: 280,
                    codeName: "ChangeStreamFatalError",
                    message: "",
                    errorLabels: ["NonResumableChangeStreamError"]
                )
                expect(try changeStream.nextWithTimeout()).to(throwError(expectedError))
            } else {
                expect(try changeStream.next()?.get()).to(throwError(errorType: LogicError.self))
            }
        }
    }

    /**
     * Prose test 3 of change stream spec.
     *
     * `ChangeStream` will automatically resume one time on a resumable error (including not master) with the initial
     * pipeline and options, except for the addition/update of a resumeToken.
     */
    func testChangeStreamAutomaticResume() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        guard try MongoClient.makeTestClient().supportsFailCommand() else {
            print("Skipping \(self.name) because server version doesn't support failCommand")
            return
        }

        let events = try captureCommandEvents(eventTypes: [.commandStarted], commandNames: ["aggregate"]) { client in
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

                // notMaster error
                let failPoint = FailPoint.failCommand(failCommands: ["getMore"], mode: .times(1), errorCode: 10107)
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
        let filteredStreamStage = { (pipeline: [Document]) -> Document in
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        // turn off retryReads so that retry attempts can be distinguished from resume attempts.
        let opts = ClientOptions(retryReads: false)

        try withTestNamespace(clientOptions: opts) { client, _, coll in
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
                errorCode: 10107
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
     * Prose test 5 of change stream spec.
     *
     * `ChangeStream` will not attempt to resume after encountering error code 11601 (Interrupted),
     * 136 (CappedPositionLost), or 237 (CursorKilled) while executing a getMore command.
     */
    func testChangeStreamDoesntResume() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        guard try MongoClient.makeTestClient().supportsFailCommand() else {
            print("Skipping \(self.name) because server version doesn't support failCommand")
            return
        }

        let interrupted = FailPoint.failCommand(failCommands: ["getMore"], mode: .times(1), errorCode: 11601)
        try interrupted.enable()
        defer { interrupted.disable() }
        let interruptedAggs = try captureCommandEvents(eventTypes: [.commandStarted], commandNames: ["aggregate"]) {
            expect(try $0.watch().next()?.get()).to(throwError())
        }
        expect(interruptedAggs.count).to(equal(1))

        let cappedPositionLost = FailPoint.failCommand(failCommands: ["getMore"], mode: .times(1), errorCode: 136)
        try cappedPositionLost.enable()
        defer { cappedPositionLost.disable() }
        let cappedAggs = try captureCommandEvents(eventTypes: [.commandStarted], commandNames: ["aggregate"]) {
            expect(try $0.watch().next()?.get()).to(throwError())
        }
        expect(cappedAggs.count).to(equal(1))

        let cursorKilled = FailPoint.failCommand(failCommands: ["getMore"], mode: .times(1), errorCode: 237)
        try cursorKilled.enable()
        defer { cursorKilled.disable() }
        let killedAggs = try captureCommandEvents(eventTypes: [.commandStarted], commandNames: ["aggregate"]) {
            expect(try $0.watch().next()?.get()).to(throwError())
        }
        expect(killedAggs.count).to(equal(1))

        let version = try MongoClient.makeTestClient().serverVersion()
        // the next set of assertions relies on the presence of the NonResumableChangeStreamError label, which was
        // introduced in 4.1.1 via SERVER-40446.
        guard version >= ServerVersion(major: 4, minor: 1, patch: 1) else {
            return
        }

        // skip on 4.3.3+ due to removal of NonResumableChangeStreamError label; see SWIFT-722
        guard version < ServerVersion(major: 4, minor: 3, patch: 3) else {
            return
        }

        let nonResumableLabel = FailPoint.failCommand(failCommands: ["getMore"], mode: .times(1), errorCode: 280)
        try nonResumableLabel.enable()
        defer { nonResumableLabel.disable() }
        let labelAggs = try captureCommandEvents(eventTypes: [.commandStarted], commandNames: ["aggregate"]) {
            expect(try $0.watch().next()?.get()).to(throwError())
        }
        expect(labelAggs.count).to(equal(1))
    }

    /**
     * Prose test 7 of change stream spec.
     *
     * Ensure that a cursor returned from an aggregate command with a cursor id and an initial empty batch is not
     * closed on the driver side.
     */
    func testChangeStreamDoesntCloseOnEmptyBatch() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        // need to keep the stream alive so its deinit doesn't kill the cursor.
        var changeStream: ChangeStream<ChangeStreamEvent<Document>>?
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        try withTestNamespace { client, _, collection in
            guard try client.supportsFailCommand() else {
                print("Skipping \(self.name) because server version doesn't support failCommand")
                return
            }

            let monitor = client.addCommandMonitor()
            var changeStream: ChangeStream<ChangeStreamEvent<Document>>?
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 0) else {
            print("Skipping test case for server version \(try client.serverVersion())")
            return
        }

        let changeStream = try client.watch()

        let db1 = client.db("db1")
        defer { try? db1.drop() }
        let coll1 = db1.collection("coll1")
        let coll2 = db1.collection("coll2")

        let doc1: Document = ["_id": 1, "a": 1]
        let doc2: Document = ["_id": 2, "x": 123]
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

        let doc3: Document = ["_id": 3, "y": 321]
        try coll.insertOne(doc3)

        let change3 = try changeStream.nextWithTimeout()
        expect(change3).toNot(beNil())
        expect(change3?.operationType).to(equal(.insert))
        expect(change3?.fullDocument).to(equal(doc3))
        // expect the resumeToken to be updated to the _id field of the most recently accessed document
        expect(changeStream.resumeToken).to(equal(change3?._id))
    }

    func testChangeStreamOnADatabase() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 0) else {
            print("Skipping test case for server version \(try client.serverVersion())")
            return
        }

        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let changeStream = try db.watch(options: ChangeStreamOptions(maxAwaitTimeMS: 100))

        // expect the first iteration to be nil since no changes have been made to the database.
        expect(try changeStream.tryNext()?.get()).to(beNil())

        let coll = db.collection(self.getCollectionName(suffix: "1"))
        let doc1: Document = ["_id": 1, "a": 1]
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))
        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let changeStream = try coll.watch(options: options)

        let doc: Document = ["_id": 1, "x": 1]
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        let options = ChangeStreamOptions(fullDocument: .updateLookup)
        let pipeline: [Document] = [["$match": ["fullDocument.a": 1]]]
        let changeStream = try coll.watch(pipeline, options: options)

        let doc1: Document = ["_id": 1, "a": 1]
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
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
        let id: Document
        let operation: String
        let fullDocument: MyFullDocumentType
        let nameSpace: Document
        let updateDescription: Document?

        enum CodingKeys: String, CodingKey {
            case id = "_id", operation = "operationType", fullDocument, nameSpace = "ns", updateDescription
        }
    }

    func testChangeStreamWithEventType() throws {
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        let db = client.db(Self.testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        // test that the change stream works on a collection when using withEventType
        let collChangeStream = try coll.watch(withEventType: MyEventType.self)

        let doc: Document = ["_id": 1, "x": 1, "y": 2]
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let expectedDoc1 = MyFullDocumentType(id: 1, x: 1, y: 2)

        let client = try MongoClient.makeTestClient()
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
        guard MongoSwiftTestCase.topologyType != .single else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
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
        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print(unsupportedTopologyMessage(testName: self.name))
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
                for id in stream.filter({ $0.isSuccess }).compactMap({ try! $0.get().fullDocument?["_id"]?.asInt() }) {
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
}
