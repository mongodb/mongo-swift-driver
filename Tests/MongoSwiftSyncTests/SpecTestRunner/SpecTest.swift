// swiftlint:disable duplicate_imports
import Foundation
@testable import struct MongoSwift.ReadPreference
import MongoSwiftSync
@testable import struct MongoSwiftSync.MongoClientOptions
import Nimble
import TestsCommon
import XCTest

/// A struct containing the portions of a `CommandStartedEvent` the spec tests use for testing.
internal struct TestCommandStartedEvent: Decodable, Matchable {
    let command: BSONDocument

    let commandName: String?

    let databaseName: String?

    internal enum CodingKeys: String, CodingKey {
        case command, commandName = "command_name", databaseName = "database_name"
    }

    internal enum TopLevelCodingKeys: String, CodingKey {
        case type = "command_started_event"
    }

    internal init(from event: CommandStartedEvent, sessionIds: [BSONDocument: String]? = nil) {
        var command = event.command

        // If command started event has "lsid": Document(...), change the value to correpond to "session0",
        // "session1", etc.
        if let sessionIds = sessionIds, let sessionDoc = command["lsid"]?.documentValue {
            for (sessionId, sessionName) in sessionIds where sessionId == sessionDoc {
                command["lsid"] = .string(sessionName)
            }
        }
        // If command is "findAndModify" and does not have key "new", add the default value "new": false.
        // This is necessary because `libmongoc` only sends a value for "new" in a command if "new": true.
        if event.commandName == "findAndModify" && command["new"] == nil {
            command["new"] = .bool(false)
        }

        self.command = command
        self.databaseName = event.databaseName
        self.commandName = event.commandName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TopLevelCodingKeys.self)
        let eventContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .type)
        self.command = try eventContainer.decode(BSONDocument.self, forKey: .command)
        self.commandName = try eventContainer.decodeIfPresent(String.self, forKey: .commandName)
        self.databaseName = try eventContainer.decodeIfPresent(String.self, forKey: .databaseName)
    }

    internal func contentMatches(expected: TestCommandStartedEvent) -> Bool {
        if let expectedDbName = expected.databaseName {
            guard let dbName = self.databaseName, dbName.matches(expected: expectedDbName) else {
                return false
            }
        }

        return self.command.matches(expected: expected.command)
    }
}

/// Enum representing the contents of deployment before a spec test has been run.
internal enum TestData: Decodable {
    /// Data for multiple collections, with the name of the collection mapping to its contents.
    case multiple([String: [BSONDocument]])

    /// The contents of a single collection.
    case single([BSONDocument])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([BSONDocument].self) {
            self = .single(array)
        } else if let document = try? container.decode(BSONDocument.self) {
            var mapping: [String: [BSONDocument]] = [:]
            for (k, v) in document {
                guard let documentArray = v.arrayValue?.compactMap({ $0.documentValue }) else {
                    throw DecodingError.typeMismatch(
                        [BSONDocument].self,
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Expected array of documents, got \(v) instead"
                        )
                    )
                }
                mapping[k] = documentArray
            }
            self = .multiple(mapping)
        } else {
            throw DecodingError.typeMismatch(
                TestData.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode `TestData`")
            )
        }
    }
}

/// Struct representing the contents of a collection after a spec test has been run.
internal struct CollectionTestInfo: Decodable {
    /// An optional name specifying a collection whose documents match the `data` field of this struct.
    /// If nil, whatever collection used in the test should be used instead.
    let name: String?

    /// The documents found in the collection.
    let data: [BSONDocument]
}

/// Struct representing an "outcome" defined in a spec test.
internal struct TestOutcome: Decodable {
    /// Whether an error is expected or not.
    let error: Bool?

    /// The expected result of running the operation associated with this test.
    let result: TestOperationResult?

    /// The expected state of the collection at the end of the test.
    let collection: CollectionTestInfo
}

/// Protocol defining the behavior of an entire spec test file.
internal protocol SpecTestFile: Decodable {
    associatedtype TestType: SpecTest

    /// The name of the file.
    /// This field must be added to the file this test is decoded from.
    var name: String { get }

    /// Server version and topology requirements in order for tests from this file to be run.
    var runOn: [TestRequirement]? { get }

    /// The database to use for testing.
    var databaseName: String { get }

    /// The collection to use for testing.
    var collectionName: String? { get }

    /// Data that should exist in the collection before running any of the tests.
    var data: TestData { get }

    /// List of tests to run in this file.
    var tests: [TestType] { get }

    /// Keywords that will cause the tests in the file to be skipped if contained in the test file's name.
    static var skippedTestFileNameKeywords: [String] { get }
}

extension SpecTestFile {
    static var skippedTestFileNameKeywords: [String] { [] }

    /// Populate the database and collection specified by this test file using the provided client.
    internal func populateData(using client: MongoSwiftSync.MongoClient) throws {
        let database = client.db(
            self.databaseName,
            options: MongoDatabaseOptions(writeConcern: try WriteConcern(w: .majority))
        )

        func populateCollection(name: String, docs: [BSONDocument]) throws {
            try? database.collection(name).drop(options: DropCollectionOptions(writeConcern: WriteConcern.majority))
            let createOptions = CreateCollectionOptions(writeConcern: WriteConcern.majority)
            let collection = try database.createCollection(name, options: createOptions)

            guard !docs.isEmpty else {
                return
            }
            try collection.insertMany(docs)
        }

        switch self.data {
        case let .single(docs):
            guard let collName = self.collectionName else {
                throw TestError(message: "missing collection name")
            }
            try populateCollection(name: collName, docs: docs)
        case let .multiple(mapping):
            for (k, v) in mapping {
                try populateCollection(name: k, docs: v)
            }
        }
    }

    func terminateOpenTransactions(
        using client: MongoSwiftSync.MongoClient,
        mongosClients: [MongoSwiftSync.MongoClient]?
    ) throws {
        // if connected to a replica set, use the provided client to execute killAllSessions on the primary.
        // if connected to a sharded cluster, use the per-mongos clients to execute killAllSessions on each mongos.
        switch try client.topologyType() {
        case .single,
             .loadBalanced,
             _ where MongoSwiftTestCase.serverless:
            return
        case .replicaSet:
            // The test runner MAY ignore any command failure with error Interrupted(11601) to work around
            // SERVER-38335.
            do {
                let opts = RunCommandOptions(readPreference: .primary)
                _ = try client.db("admin").runCommand(["killAllSessions": []], options: opts)
            } catch let commandError as MongoError.CommandError where commandError.code == 11601 {}
        case .sharded, .shardedReplicaSet:
            for mongosClient in mongosClients! {
                do {
                    _ = try mongosClient.db("admin").runCommand(["killAllSessions": []])
                    break
                } catch let commandError as MongoError.CommandError where commandError.code == 11601 {}
            }
        }
    }

    /// Run all the tests specified in this file, optionally specifying keywords that, if included in a test's
    /// description, will cause certain tests to be skipped.
    internal func runTests() throws {
        if let keyword = Self.skippedTestFileNameKeywords.first(where: { self.name.contains($0) }) {
            fileLevelLog("Skipping tests from file \(self.name), matched skipped keyword \"\(keyword)\".")
            return
        }

        // setup client needs to be able to talk to all mongoses for targetedFailPoint and for
        // the distinct workaround.
        let connString = MongoSwiftTestCase.getConnectionString(singleMongos: false).toString()
        var setupClientOptions = MongoClientOptions()
        setupClientOptions.minHeartbeatFrequencyMS = 50
        setupClientOptions.heartbeatFrequencyMS = 50
        let setupClient = try MongoClient.makeTestClient(connString, options: setupClientOptions)

        if let requirements = self.runOn {
            guard try requirements.contains(where: { try setupClient.getUnmetRequirement($0) == nil }) else {
                fileLevelLog("Skipping tests from file \(self.name), deployment requirements not met.")
                return
            }
        }

        let topologyType = try setupClient.topologyType()

        var mongosClients: [MongoClient]?
        if topologyType.isSharded {
            var opts = setupClientOptions
            opts.directConnection = true // connect directly to mongoses
            mongosClients = try MongoSwiftTestCase.getConnectionStringPerHost()
                .map { try MongoClient.makeTestClient($0.toString(), options: opts) }
        }

        fileLevelLog("Executing tests from file \(self.name)...")
        for var test in self.tests {
            if let keyword = Self.TestType.skippedTestKeywords.first(where: { test.description.contains($0) }) {
                print("Skipping test \(test.description) due to matched keyword \"\(keyword)\".")
                continue
            }
            try self.terminateOpenTransactions(using: setupClient, mongosClients: mongosClients)
            try self.populateData(using: setupClient)

            // Due to strange behavior in mongos, a "distinct" command needs to be run against each mongos
            // before the tests run to prevent certain errors from ocurring. (SERVER-39704)
            if topologyType.isSharded, test.description.contains("distinct"), let collName = self.collectionName {
                for client in mongosClients! {
                    _ = try client.db(self.databaseName).runCommand(["distinct": .string(collName), "key": "_id"])
                }
            }

            try test.run(setupClient: setupClient, dbName: self.databaseName, collName: self.collectionName)
        }
    }
}

/// Protocol defining the behavior of an individual spec test.
internal protocol SpecTest: Decodable, FailPointConfigured {
    /// The name of the test.
    var description: String { get }

    /// Options used to configure the `MongoClient` used for this test.
    var clientOptions: MongoClientOptions? { get }

    /// If true, the `MongoClient` for this test should be initialized with multiple mongos seed addresses.
    /// If false or omitted, only a single mongos address should be specified.
    /// This field has no effect for non-sharded topologies.
    var useMultipleMongoses: Bool? { get }

    /// Reason why this test should be skipped, if applicable.
    var skipReason: String? { get }

    /// The optional fail point to configure before running this test.
    /// This option and useMultipleMongoses: true are mutually exclusive.
    var failPoint: FailPoint? { get }

    /// Descriptions of the operations to be run and their expected outcomes.
    var operations: [TestOperationDescription] { get }

    /// List of expected CommandStartedEvents.
    var expectations: [TestCommandStartedEvent]? { get }

    /// Document describing the return value and/or expected state of the collection after the operation is executed.
    var outcome: TestOutcome? { get }

    /// Map of session names (e.g. "session0") to parameters to pass to `MongoClient.startSession()` when creating that
    /// session.
    var sessionOptions: [String: ClientSessionOptions]? { get }

    /// Array of session names (e.g. "session0", "session1") that the test refers to. Each session is proactively
    /// started in `run()`.
    static var sessionNames: [String] { get }

    /// Keywords that will cause a test to be skipped if contained in the test's description.
    static var skippedTestKeywords: [String] { get }
}

/// Default implementation of a test execution.
extension SpecTest {
    var outcome: TestOutcome? { nil }

    var sessionOptions: [String: ClientSessionOptions]? { nil }

    static var sessionNames: [String] { [] }

    static var skippedTestKeywords: [String] { [] }

    internal mutating func run(
        setupClient: MongoClient,
        dbName: String,
        collName: String?
    ) throws {
        guard self.skipReason == nil else {
            print("Skipping test for reason: \(self.skipReason!)")
            return
        }

        print("Executing test: \(self.description)")

        let connectionString = MongoSwiftTestCase.getConnectionString(singleMongos: self.useMultipleMongoses != true)

        // We need to lower heartbeat frequency to speed up tests on 4.4+ since failpoints don't trigger proper
        // topology updates when using streamable hello. See CDRIVER-3793 for more information.
        var options = self.clientOptions ?? MongoClientOptions()

        if options.heartbeatFrequencyMS == nil {
            options.minHeartbeatFrequencyMS = 50
            options.heartbeatFrequencyMS = 50
        }

        let client = try MongoClient.makeTestClient(
            connectionString.toString(), options: options
        )
        let monitor = client.addCommandMonitor()

        if let failPoint = self.failPoint {
            // if only using a single mongos, make sure to enable the failpoint on the correct mongos.
            if try client.topologyType().isSharded, self.useMultipleMongoses != true {
                try self.activateFailPoint(failPoint, using: setupClient, on: connectionString.hosts![0])
            } else {
                try self.activateFailPoint(failPoint, using: setupClient)
            }
        }
        // this defer will cover any failpoints set in `validateExecution` as well.
        defer {
            self.disableActiveFailPoint(using: setupClient)
        }

        var sessions = [String: MongoSwiftSync.ClientSession]()
        for session in Self.sessionNames {
            sessions[session] = client.startSession(options: self.sessionOptions?[session])
        }

        var sessionIds = [BSONDocument: String]()

        try monitor.captureEvents {
            for operation in self.operations {
                try operation.validateExecution(
                    test: &self,
                    setupClient: setupClient,
                    client: client,
                    dbName: dbName,
                    collName: collName,
                    sessions: sessions
                )
            }
            // Keep track of the session IDs assigned to each session.
            // Deinitialize each session thereby implicitly ending them.
            for session in sessions.keys {
                if let sessionId = sessions[session]?.id { sessionIds[sessionId] = session }
                sessions[session] = nil
            }
        }

        let events = monitor.commandStartedEvents().map { commandStartedEvent -> TestCommandStartedEvent in
            TestCommandStartedEvent(from: commandStartedEvent, sessionIds: sessionIds)
        }

        if let expectations = self.expectations {
            expect(events).to(match(expectations), description: self.description)
        }

        guard let outcome = self.outcome else {
            return
        }
        guard let collName = collName else {
            throw TestError(message: "outcome specifies a collection but spec test omits collection name")
        }
        let verifyColl = setupClient.db(dbName).collection(collName)
        let foundDocs = try verifyColl.find().all()
        expect(foundDocs.count).to(equal(outcome.collection.data.count))
        zip(foundDocs, outcome.collection.data).forEach {
            expect($0).to(sortedEqual($1), description: self.description)
        }
    }
}
