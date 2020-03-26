import Foundation
import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

/// A struct containing the portions of a `CommandStartedEvent` the spec tests use for testing.
internal struct TestCommandStartedEvent: Decodable, Matchable {
    var command: Document

    let commandName: String

    let databaseName: String?

    internal enum CodingKeys: String, CodingKey {
        case command, commandName = "command_name", databaseName = "database_name"
    }

    internal enum TopLevelCodingKeys: String, CodingKey {
        case type = "command_started_event"
    }

    internal init(from event: CommandStartedEvent) {
        self.command = event.command
        self.databaseName = event.databaseName
        self.commandName = event.commandName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TopLevelCodingKeys.self)
        let eventContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .type)
        self.command = try eventContainer.decode(Document.self, forKey: .command)
        if let commandName = try eventContainer.decodeIfPresent(String.self, forKey: .commandName) {
            self.commandName = commandName
        } else if let firstKey = self.command.keys.first {
            self.commandName = firstKey
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.commandName,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "commandName not found")
            )
        }
        self.databaseName = try eventContainer.decodeIfPresent(String.self, forKey: .databaseName)
    }

    internal func contentMatches(expected: TestCommandStartedEvent) -> Bool {
        if let expectedDbName = expected.databaseName {
            guard let dbName = self.databaseName, dbName.matches(expected: expectedDbName) else {
                return false
            }
        }
        return self.commandName.matches(expected: expected.commandName)
            && self.command.matches(expected: expected.command)
    }

    internal mutating func excludeKeys(keys: [String]) throws {
        var newCommand = Document()
        try self.command.copyElements(to: &newCommand, excluding: keys)
        self.command = newCommand
    }
}

/// Struct representing conditions that a deployment must meet in order for a test file to be run.
internal struct TestRequirement: Decodable {
    private let minServerVersion: ServerVersion?
    private let maxServerVersion: ServerVersion?
    private let topology: [String]?

    /// Determines if the given deployment meets this requirement.
    func isMet(by version: ServerVersion, _ topology: TopologyDescription.TopologyType) -> Bool {
        if let minVersion = self.minServerVersion {
            guard minVersion <= version else {
                return false
            }
        }
        if let maxVersion = self.maxServerVersion {
            guard maxVersion >= version else {
                return false
            }
        }
        if let topologies = self.topology?.map({ TopologyDescription.TopologyType(from: $0) }) {
            guard topologies.contains(topology) else {
                return false
            }
        }
        return true
    }
}

/// Enum representing the contents of deployment before a spec test has been run.
internal enum TestData: Decodable {
    /// Data for multiple collections, with the name of the collection mapping to its contents.
    case multiple([String: [Document]])

    /// The contents of a single collection.
    case single([Document])

    public init(from decoder: Decoder) throws {
        if let array = try? [Document](from: decoder) {
            self = .single(array)
        } else if let document = try? Document(from: decoder) {
            var mapping: [String: [Document]] = [:]
            for (k, v) in document {
                guard let documentArray = v.arrayValue?.compactMap({ $0.documentValue }) else {
                    throw DecodingError.typeMismatch(
                        [Document].self,
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
    let data: [Document]
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
}

extension SpecTestFile {
    /// Populate the database and collection specified by this test file using the provided client.
    internal func populateData(using client: MongoClient) throws {
        let database = client.db(self.databaseName)

        // Majority write concern ensures that initial data is propagated to all nodes in a replica set or sharded
        // cluster.
        let collectionOptions = CollectionOptions(writeConcern: try WriteConcern(w: .majority))

        try? database.drop()

        switch self.data {
        case let .single(docs):
            guard let collName = self.collectionName else {
                throw TestError(message: "missing collection name")
            }

            guard !docs.isEmpty else {
                return
            }

            try database.collection(collName, options: collectionOptions).insertMany(docs)
        case let .multiple(mapping):
            for (k, v) in mapping {
                guard !v.isEmpty else {
                    continue
                }
                try database.collection(k, options: collectionOptions).insertMany(v)
            }
        }
    }

    /// Run all the tests specified in this file, optionally specifying keywords that, if included in a test's
    /// description, will cause certain tests to be skipped.
    internal func runTests(parent: FailPointConfigured, skippedTestKeywords: [String] = []) throws {
        let setupClient = try MongoClient.makeTestClient()
        let version = try setupClient.serverVersion()

        if let requirements = self.runOn {
            guard requirements.contains(where: { $0.isMet(by: version, MongoSwiftTestCase.topologyType) }) else {
                fileLevelLog("Skipping tests from file \(self.name), deployment requirements not met.")
                return
            }
        }

        fileLevelLog("Executing tests from file \(self.name)...")
        for test in self.tests {
            guard skippedTestKeywords.allSatisfy({ !test.description.contains($0) }) else {
                print("Skipping test \(test.description)")
                return
            }
            try self.populateData(using: setupClient)
            try test.run(parent: parent, dbName: self.databaseName, collName: self.collectionName)
        }
    }
}

/// Protocol defining the behavior of an individual spec test.
internal protocol SpecTest: Decodable {
    /// The name of the test.
    var description: String { get }

    /// Options used to configure the `MongoClient` used for this test.
    var clientOptions: ClientOptions? { get }

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
}

/// Default implementation of a test execution.
extension SpecTest {
    var outcome: TestOutcome? { nil }

    var sessionOptions: [String: ClientSessionOptions]? { nil }

    internal func run(
        parent: FailPointConfigured,
        dbName: String,
        collName: String?
    ) throws {
        guard self.skipReason == nil else {
            print("Skipping test for reason: \(self.skipReason!)")
            return
        }

        print("Executing test: \(self.description)")

        let clientOptions = self.clientOptions ?? ClientOptions(retryReads: true)

        let client = try MongoClient.makeTestClient(options: clientOptions)
        let monitor = client.addCommandMonitor()

        if let collName = collName {
            _ = try? client.db(dbName).createCollection(collName)
            // Run the distinct command before every test to prevent `StableDbVersion` error in sharded cluster
            // transactions. This workaround can be removed once SERVER-39704 is resolved.
            _ = try? client.db(dbName).collection(collName).distinct(fieldName: "_id")
        }

        if let failPoint = self.failPoint {
            try parent.activateFailPoint(failPoint)
        }
        defer { parent.disableActiveFailPoint() }

        // The spec tests refer to the sessions below. Proactively start them in case this spec test requires one.
        let sessionsToStart = ["session0", "session1"]

        var sessionDict = [String: ClientSession]()
        for session in sessionsToStart {
            sessionDict[session] = client.startSession(options: self.sessionOptions?[session])
        }

        var sessionIds = [String: Document]()

        try monitor.captureEvents {
            for operation in self.operations {
                try operation.validateExecution(
                    client: client,
                    dbName: dbName,
                    collName: collName,
                    sessionDict: sessionDict
                )
            }
            // Keep track of the session IDs assigned to each session.
            // Deinitialize each session thereby implicitly ending them.
            for session in sessionDict.keys {
                sessionIds[session] = sessionDict[session]?.id
                sessionDict[session] = nil
            }
        }

        let events = try monitor.commandStartedEvents().map { commandStartedEvent in
            try processCommandStartedEvent(commandStartedEvent: commandStartedEvent, sessionIds: sessionIds)
        }

        if let expectations = self.expectations {
            expect(events).to(match(expectations), description: self.description)
        }

        if let outcome = self.outcome {
            try self.checkOutcome(outcome: outcome, dbName: dbName, collName: collName!)
        }
    }

    internal func processCommandStartedEvent(
        commandStartedEvent: CommandStartedEvent,
        sessionIds: [String: Document]
    )
        throws -> TestCommandStartedEvent {
        var event = TestCommandStartedEvent(from: commandStartedEvent)
        try event.excludeKeys(keys: ["$db", "$clusterTime"])

        // If command started event has "lsid": Document(...), change the value to correpond to "session0",
        // "session1", etc.
        if let sessionDoc = event.command["lsid"]?.documentValue {
            for session in sessionIds.keys {
                if let sessionId = sessionIds[session], sessionId == sessionDoc {
                    event.command["lsid"] = .string(session)
                }
            }
        }
        // If command is "findAndModify" and does not have key "new", add the default value "new": false.
        if event.commandName == "findAndModify" && event.command["new"] == nil {
            event.command["new"] = .bool(false)
        }

        return event
    }

    internal func checkOutcome(outcome: TestOutcome, dbName: String, collName: String) throws {
        let client = try MongoClient.makeTestClient()
        let verifyColl = client.db(dbName).collection(collName)
        let foundDocs = try Array(verifyColl.find().all())
        expect(foundDocs.count).to(equal(outcome.collection.data.count))
        zip(foundDocs, outcome.collection.data).forEach {
            expect($0).to(sortedEqual($1), description: self.description)
        }
    }
}
