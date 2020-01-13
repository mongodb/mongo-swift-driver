import Foundation
import MongoSwift
import NIO
import TestsCommon
import XCTest

extension MongoClient {
    fileprivate static func makeTestClient(
        _ uri: String = MongoSwiftTestCase.connStr,
        eventLoopGroup: EventLoopGroup,
        options: ClientOptions? = nil
    ) throws -> MongoClient {
        var opts = options ?? ClientOptions()
        if MongoSwiftTestCase.ssl {
            opts.tlsOptions = TLSOptions(
                caFile: URL(string: MongoSwiftTestCase.sslCAFilePath ?? ""),
                pemFile: URL(string: MongoSwiftTestCase.sslPEMKeyFilePath ?? "")
            )
        }
        return try MongoClient(uri, using: eventLoopGroup, options: opts)
    }

    internal func syncCloseOrFail() {
        do {
            try self.close().wait()
        } catch {
            XCTFail("Error closing test client: \(error)")
        }
    }
}

extension MongoDatabase {
    fileprivate func syncDropOrFail() {
        do {
            try self.drop().wait()
        } catch {
            XCTFail("Error dropping test database: \(error)")
        }
    }
}

extension MongoSwiftTestCase {
    internal func withTestNamespace<T>(
        options: ClientOptions? = nil,
        f: (MongoClient, MongoDatabase, MongoCollection<Document>) throws -> T
    ) throws -> T {
        return try self.withTestClient(options: options) { client in
            let db = client.db(type(of: self).testDatabase)
            let coll = db.collection(self.getCollectionName())
            defer { db.syncDropOrFail() }
            return try f(client, db, coll)
        }
    }

    internal func withTestClient<T>(options: ClientOptions? = nil, f: (MongoClient) throws -> T) throws -> T {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg, options: options)
        defer { client.syncCloseOrFail() }
        return try f(client)
    }

    /// Creates the given namespace using the given client and passes handles to it and its parent database to the given
    /// function. After the function executes, the collection associated with the namespace is dropped.
    ///
    /// Note: If a collection is not specified as part of the input namespace, this function will throw an error.
    internal func withTestNamespace<T>(
        client: MongoClient,
        ns: MongoNamespace? = nil,
        collectionOptions: CreateCollectionOptions? = nil,
        _ f: (MongoDatabase, MongoCollection<Document>) throws -> T
    ) throws -> T {
        let ns = ns ?? self.getNamespace()

        guard let collName = ns.collection else {
            throw TestError(message: "missing collection")
        }

        let database = client.db(ns.db)
        let collection = try database.createCollection(collName, options: collectionOptions).wait()
        defer { try? collection.drop().wait() }
        return try f(database, collection)
    }

    /// Creates the given namespace and passes handles to it and its parents to the given function. After the function
    /// executes, the collection associated with the namespace is dropped.
    ///
    /// Note: If a collection is not specified as part of the input namespace, this function will throw an error.
    internal func withTestNamespace<T>(
        ns: MongoNamespace? = nil,
        collectionOptions: CreateCollectionOptions? = nil,
        _ f: (MongoClient, MongoDatabase, MongoCollection<Document>) throws -> T
    ) throws -> T {
        return try self.withTestClient { client in
            try self.withTestNamespace(client: client, ns: ns, collectionOptions: collectionOptions) { db, coll in
                try f(client, db, coll)
            }
        }
    }
}

extension MultiThreadedEventLoopGroup {
    internal func syncShutdownOrFail() {
        do {
            try self.syncShutdownGracefully()
        } catch {
            XCTFail("Error shutting down test MultiThreadedEventLoopGroup: \(error)")
        }
    }
}
