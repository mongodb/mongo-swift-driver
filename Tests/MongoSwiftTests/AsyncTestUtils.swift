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

    internal func syncCloseOrLogError() {
        do {
            try self.close().wait()
        } catch {
            XCTFail("Error closing test client: \(error)")
        }
    }
}

extension MongoSwiftTestCase {
    internal func withTestClient<T>(options: ClientOptions? = nil, f: (MongoClient) throws -> T) throws -> T {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrLogError() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg, options: options)
        defer { client.syncCloseOrLogError() }
        return try f(client)
    }
}

extension MultiThreadedEventLoopGroup {
    internal func syncShutdownOrLogError() {
        do {
            try self.syncShutdownGracefully()
        } catch {
            XCTFail("Error shutting down test MultiThreadedEventLoopGroup: \(error)")
        }
    }
}
