#if compiler(>=5.5) && canImport(_Concurrency) && os(Linux)

import Foundation
import MongoSwift
import NIO
import TestsCommon
import XCTest

/// Temporary utility function until XCTest supports `async` tests.
func testAsync(_ block: @escaping () async throws -> Void) {
    let group = DispatchGroup()
    group.enter()
    Task.detached {
        do {
            try await block()
        } catch {
            XCTFail("\(error)")
        }
        group.leave()
    }
    group.wait()
}

extension Task where Success == Never, Failure == Never {
    ///  Helper taken from https://www.hackingwithswift.com/quick-start/concurrency/how-to-make-a-task-sleep to support
    /// configuring with seconds rather than nanoseconds.
    static func sleep(seconds: TimeInterval) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}

/// Asserts that the provided block returns true within the specified timeout. Nimble's `toEventually` can only be used
/// rom the main testing thread which is too restrictive for our purposes testing the async/await APIs.
func assertIsEventuallyTrue(
    description: String,
    timeout: TimeInterval = 5,
    sleepInterval: TimeInterval = 0.1,
    _ block: () -> Bool
) async throws {
    let start = DispatchTime.now()
    while DispatchTime.now() < start + timeout {
        if block() {
            return
        }
        try await Task.sleep(seconds: sleepInterval)
    }
    XCTFail("Expected condition \"\(description)\" to be true within \(timeout) seconds, but was not")
}

extension MongoSwiftTestCase {
    internal func withTestClient<T>(
        _ uri: String = MongoSwiftTestCase.getConnectionString().toString(),
        options: MongoClientOptions? = nil,
        eventLoopGroup: EventLoopGroup? = nil,
        f: (MongoClient) async throws -> T
    ) async throws -> T {
        let elg = eventLoopGroup ?? MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(uri, eventLoopGroup: elg, options: options)
        defer { client.syncCloseOrFail() }
        return try await f(client)
    }

    // swiftlint:disable large_tuple
    // see: https://github.com/realm/SwiftLint/issues/3753
    internal func withTestNamespace<T>(
        ns: MongoNamespace? = nil,
        collectionOptions: CreateCollectionOptions? = nil,
        _ f: (MongoClient, MongoDatabase, MongoCollection<BSONDocument>) async throws -> T
    ) async throws -> T {
        let ns = ns ?? self.getNamespace()
        guard let collName = ns.collection else {
            throw TestError(message: "missing collection")
        }
        return try await self.withTestClient { client in
            let database = client.db(ns.db)
            let collection: MongoCollection<BSONDocument>
            do {
                collection = try await database.createCollection(collName, options: collectionOptions)
            } catch let error as MongoError.CommandError where error.code == 48 {
                try await database.collection(collName).drop()
                collection = try await database.createCollection(collName, options: collectionOptions)
            }
            defer { collection.syncDropOrFail() }
            return try await f(client, database, collection)
        }
    }
    // swiftlint:enable large_tuple
}

extension MongoClient {
    internal func serverVersion() async throws -> ServerVersion {
        let reply = try await self.db("admin").runCommand(
            ["buildInfo": 1],
            options: RunCommandOptions(readPreference: .primary)
        )
        guard let versionString = reply["version"]?.stringValue else {
            throw TestError(message: " reply missing version string: \(reply)")
        }
        return try ServerVersion(versionString)
    }

    internal func serverParameters() async throws -> BSONDocument {
        try await self.db("admin").runCommand(["getParameter": "*"])
    }

    internal func getUnmetRequirement(_ testRequirement: TestRequirement) async throws -> UnmetRequirement? {
        async let helloReply = try self.db("admin").runCommand(["hello": 1])
        async let shards = try self.db("config").collection("shards").find().get().toArray().get()
        async let serverVersion = try self.serverVersion()
        async let params = try self.serverParameters()
        let topologyType = try await TestTopologyConfiguration(helloReply: helloReply, shards: shards)
        return try await testRequirement.getUnmetRequirement(givenCurrent: serverVersion, topologyType, params)
    }

    internal func meetsAnyRequirement(in requirements: [TestRequirement]) async throws -> Bool {
        try await withThrowingTaskGroup(of: UnmetRequirement?.self) { group in
            for req in requirements {
                group.addTask {
                    try await self.getUnmetRequirement(req)
                }
            }
            for try await taskResult in group where taskResult == nil {
                group.cancelAll()
                return true
            }
            return false
        }
    }

    internal func supportsTransactions() async throws -> Bool {
        try await self.meetsAnyRequirement(in: TestRequirement.transactionsSupport)
    }
}

#endif
