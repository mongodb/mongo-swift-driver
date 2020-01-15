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
        return try self.withTestClient { client in
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
