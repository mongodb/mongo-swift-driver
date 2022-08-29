#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import Nimble
import TestsCommon
import NIO

@available(macOS 10.15, *)
class UnifiedTestRunner {
    enum InternalClient {
        /// For all topologies besides sharded, we use a single client.
        case single(MongoClient)
        /// For sharded topologies, we often need to target commands to particular mongoses, so we use a separate
        /// client for each host we're connecting to.
        case mongosClients([ServerAddress: MongoClient])

        /// Returns an internal client; for usage in situations where any client connected to the topology will do -
        /// that is, if the topology is sharded, we do not care about targeting a particular mongos.
        var anyClient: MongoClient {
            switch self {
            case let .single(c):
                return c
            case let .mongosClients(clientMap):
                return clientMap.first!.1
            }
        }

        /// If the internal client is a map of per-mongos clients, returns that map; otherwise throws an erorr.
        func asMongosClients() throws -> [ServerAddress: MongoClient] {
            guard case let .mongosClients(clientMap) = self else {
                throw TestError(
                    message: "Runner unexpectedly did not create per-mongos clients"
                )
            }
            return clientMap
        }

        /// Closes the internal clients (needed because can't  rely on `deinit` with async clients)
        func close() throws {
            switch self {
            case let .single(c):
                try c.syncClose()
            case let .mongosClients(clientMap):
                for elt in clientMap.values {
                    try elt.syncClose()
                }
            }
        }
    }

    let internalClient: InternalClient
    let serverVersion: ServerVersion
    let topologyType: TestTopologyConfiguration
    let serverParameters: BSONDocument
    let elg: MultiThreadedEventLoopGroup

    static let minSchemaVersion = SchemaVersion(rawValue: "1.0.0")!
    static let maxSchemaVersion = SchemaVersion(rawValue: "1.7.0")!

    init() async throws {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        switch MongoSwiftTestCase.topologyType {
        case .sharded:
            var mongosClients = [ServerAddress: MongoClient]()
            for host in MongoSwiftTestCase.getHosts() {
                let connString = MongoSwiftTestCase.getConnectionString(forHost: host)
                let client = try MongoClient.makeTestClient(connString, eventLoopGroup: self.elg)
                mongosClients[host] = client
            }
            self.internalClient = .mongosClients(mongosClients)
        default:
            let client = try MongoClient.makeTestClient(eventLoopGroup: self.elg)
            self.internalClient = .single(client)
        }
        self.serverVersion = try await self.internalClient.anyClient.serverVersion()
        self.topologyType = try await self.internalClient.anyClient.topologyType()
        self.serverParameters = try await self.internalClient.anyClient.serverParameters()
    }

    deinit {
        try? self.internalClient.close()
        try? self.elg.syncShutdownGracefully()
    }

    func terminateOpenTransactions() async throws {
        // Using the internal MongoClient, execute the killAllSessions command on either the primary or, if
        // connected to a sharded cluster, all mongos servers.
        switch self.topologyType {
        case .single,
             .loadBalanced,
             _ where MongoSwiftTestCase.serverless:
            return
        case .replicaSet:
            // The test runner MAY ignore any command failure with error Interrupted(11601) to work around
            // SERVER-38335.
            do {
                let opts = RunCommandOptions(readPreference: .primary)
                _ = try await self.internalClient.anyClient.db("admin").runCommand(
                    ["killAllSessions": []],
                    options: opts
                )
            } catch let commandError as MongoError.CommandError where commandError.code == 11601 {}
        case .sharded, .shardedReplicaSet:
            for (_, client) in try self.internalClient.asMongosClients() {
                do {
                    _ = try await client.db("admin").runCommand(["killAllSessions": []])
                } catch let commandError as MongoError.CommandError where commandError.code == 11601 {
                    continue
                }
            }
        }
    }

    func getUnmetRequirement(_ requirement: TestRequirement) -> UnmetRequirement? {
        requirement.getUnmetRequirement(givenCurrent: self.serverVersion, self.topologyType, self.serverParameters)
    }

    /// Runs the provided files. `skipTestCases` is a map of file description strings to arrays of test description
    /// strings indicating cases to skip. If the array contains a single string "*" all tests in the file will be
    /// skipped.
    func runFiles(_ files: [UnifiedTestFile], skipTests: [String: [String]] = [:]) async throws {
        for file in files {
            // Upon loading a file, the test runner MUST read the schemaVersion field and determine if the test file
            // can be processed further.
            guard file.schemaVersion >= Self.minSchemaVersion && file.schemaVersion <= Self.maxSchemaVersion else {
                throw TestError(
                    message: "Test file \"\(file.description)\" has unsupported schema version \(file.schemaVersion)"
                )
            }
            // If runOnRequirements is specified, the test runner MUST skip the test file unless one or more
            //  runOnRequirement objects are satisfied.
            if let requirements = file.runOnRequirements {
                guard requirements.contains(where: { self.getUnmetRequirement($0) == nil }) else {
                    fileLevelLog("Skipping tests from file \"\(file.description)\", deployment requirements not met.")
                    continue
                }
            }

            let skippedTestsForFile = skipTests[file.description] ?? []
            if skippedTestsForFile == ["*"] {
                fileLevelLog("Skipping all tests from file \"\(file.description)\", was included in skip list")
                continue
            }
            for test in file.tests {
                // If test.skipReason is specified, the test runner MUST skip this test and MAY use the string value to
                // log a message.
                if let skipReason = test.skipReason {
                    fileLevelLog(
                        "Skipping test \"\(test.description)\" from file \"\(file.description)\": \(skipReason)."
                    )
                    continue
                }

                if skippedTestsForFile.contains(test.description) {
                    fileLevelLog(
                        "Skipping test \"\(test.description)\" from file \"\(file.description)\", " +
                            "was included in skip list"
                    )
                    continue
                }

                // If test.runOnRequirements is specified, the test runner MUST skip the test unless one or more
                // runOnRequirement objects are satisfied.
                if let requirements = test.runOnRequirements {
                    guard requirements.contains(where: { self.getUnmetRequirement($0) == nil }) else {
                        fileLevelLog(
                            "Skipping test \"\(test.description)\" from file \"\(file.description)\", " +
                                "deployment requirements not met."
                        )
                        continue
                    }
                }
                // If initialData is specified, for each collectionData therein the test runner MUST drop the
                // collection and insert the specified documents (if any) using a "majority" write concern. If no
                // documents are specified, the test runner MUST create the collection with a "majority" write concern.
                // The test runner MUST use the internal MongoClient for these operations.
                if let initialData = file.initialData {
                    for collData in initialData {
                        let db = self.internalClient.anyClient.db(collData.databaseName)
                        let collOpts = MongoCollectionOptions(writeConcern: .majority)
                        let coll = db.collection(collData.collectionName, options: collOpts)
                        try await coll.drop()

                        guard !collData.documents.isEmpty else {
                            _ = try await db.createCollection(
                                collData.collectionName,
                                options: CreateCollectionOptions(writeConcern: .majority)
                            )
                            continue
                        }

                        try await coll.insertMany(collData.documents)
                    }
                }

                let context = Context(
                    path: [],
                    entities: try file.createEntities?.toEntityMap(elg: self.elg) ?? [:],
                    internalClient: self.internalClient
                )
                // Workaround for SERVER-39704:  a test runners MUST execute a non-transactional distinct command on
                // each mongos server before running any test that might execute distinct within a transaction. To ease
                // the implementation, test runners MAY execute distinct before every test.
                if self.topologyType.isSharded && !MongoSwiftTestCase.serverless {
                    let collEntities = context.entities.values.compactMap { try? $0.asCollection() }
                    let clientMap = try self.internalClient.asMongosClients()
                    for (_, client) in clientMap {
                        for entity in collEntities {
                            do {
                                _ = try await client.db(entity.namespace.db).runCommand(
                                    ["distinct": .string(entity.name), "key": "_id"]
                                )
                            } catch let commandError as MongoError.CommandError where commandError.code == 26 {
                                // ignore NamespaceNotFound errors from distinct.
                            }
                        }
                    }
                }
                fileLevelLog("Running test \"\(test.description)\" from file \"\(file.description)\"")
                do {
                    for (i, operation) in test.operations.enumerated() {
                        try await context.withPushedElt("Operation \(i) (\(operation.name))") {
                            try await operation.executeAndCheckResult(context: context)
                        }
                    }
                    var clientEvents = [String: [CommandEvent]]()
                    // If any event listeners were enabled on any client entities, the test runner MUST now disable
                    // those event listeners.
                    for (id, client) in context.entities.compactMapValues({ try? $0.asTestClient() }) {
                        clientEvents[id] = try client.stopCapturingEvents()
                    }
                    if let expectEvents = test.expectEvents {
                        // TODO: SWIFT-1321 don't skip CMAP event assertions here.
                        for expectedEventList in expectEvents where expectedEventList.eventType != .cmap {
                            let clientId = expectedEventList.client
                            guard let actualEvents = clientEvents[clientId] else {
                                throw TestError(message: "No client entity found with id \(clientId)")
                            }
                            try context.withPushedElt("Expected events for client \(clientId)") {
                                try matchesEvents(
                                    expected: expectedEventList.events,
                                    actual: actualEvents,
                                    context: context,
                                    ignoreExtraEvents: expectedEventList.ignoreExtraEvents
                                )
                            }
                        }
                    }
                    if let expectedOutcome = test.outcome {
                        for collectionData in expectedOutcome {
                            let collection = self.internalClient
                                .anyClient
                                .db(collectionData.databaseName)
                                .collection(collectionData.collectionName)
                            let opts = FindOptions(
                                readConcern: .local,
                                readPreference: .primary,
                                sort: ["_id": 1]
                            )
                            let documents = try await collection.find(options: opts).toArray()
                            expect(documents.count).to(equal(collectionData.documents.count))
                            for (expected, actual) in zip(collectionData.documents, documents) {
                                expect(actual).to(
                                    sortedEqual(expected),
                                    description: "Test outcome did not match expected"
                                )
                            }
                        }
                    }
                    // Manual clean up
                    try await self.terminateOpenTransactions()
                    await context.disableFailpoints()
                    try await self.closeEntities(context: context)
                } catch let testErr {
                    // Test runners SHOULD terminate all open transactions after each failed test by killing all
                    // sessions in the cluster.
                    do {
                        // Clean up to prevent a client closing error from obscuring the real error
                        try? await self.terminateOpenTransactions()
                        await context.disableFailpoints()
                        try await self.closeEntities(context: context)
                    } catch {
                        print("Failed to close unified test runner elements: \(error)")
                    }
                    throw testErr
                }
            }
        }
    }

    func closeEntities(context: Context) async throws {
        // Must close streams and cursors before closing the parent client
        for entity in context.entities.values {
            switch entity {
            case let .changeStream(changeStream):
                // Operations doesnt exist in async extension, so .get()
                try await changeStream.kill().get()
            case let .session(session):
                // Operation doesnt exist in async extension, so .get()
                try await session.end().get()
            case let .findCursor(cursor):
                // Operation doesnt exist in async extension, so .get()
                try await cursor.kill().get()
            default:
                continue
            }
        }
        // Close clients once all its streams/cursors are correctly closed
        for entity in context.entities.values {
            switch entity {
            case let .client(c):
                try await c.client.close()
            default:
                continue
            }
        }
    }
}
#endif
