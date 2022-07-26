import MongoSwift
import Nimble
import TestsCommon

final class LoadBalancerTests: MongoSwiftTestCase {
    let skipFiles: [String] = [
        // We don't support this option.
        "wait-queue-timeouts.json"
    ]

    func testLoadBalancers() async throws {
        let tests = try retrieveSpecTestFiles(
            specName: "load-balancers",
            excludeFiles: skipFiles,
            asType: UnifiedTestFile.self
        ).map { $0.1 }

        let skipTests = [
            // The sessions spec requires that sessions can only be used with the MongoClient that created them.
            // Consequently, libmongoc enforces that a `mongoc_client_session_t` may only be used with the
            // `mongoc_client_t` that created it. In Swift, this translates to a requirement that we always pin
            // `Connection`s to `ClientSession`s from the time the session is first used until it is closed/
            // deinitialized. Since all of these tests use a session entity that is created before the tests are run
            // and closed after they complete, the session always has the connection pinned to it, and we never release
            // the connection as these tests expect.
            "transactions are correctly pinned to connections for load-balanced clusters": [
                "pinned connection is released after a non-transient abort error",
                "pinned connection is released after a transient non-network CRUD error",
                "pinned connection is released after a transient network CRUD error",
                "pinned connection is released after a transient non-network commit error",
                "pinned connection is released after a transient network commit error",
                "pinned connection is released after a transient non-network abort error",
                "pinned connection is released after a transient network abort error",
                "pinned connection is released on successful abort",
                "pinned connection is returned when a new transaction is started",
                "pinned connection is returned when a non-transaction operation uses the session",
                "a connection can be shared by a transaction and a cursor"
            ],
            "cursors are correctly pinned to connections for load-balanced clusters": [
                // This test assumes that we release a cursor's pinned connection as soon as the cursor is exhausted
                // server-side, regardless of if it has been fully iterated. However, we do not release connections
                // until the first iteration attempt after the last document in the cursor.
                "no connection is pinned if all documents are returned in the initial batch",
                // This test assumes that we release a cursor's pinned connection after the last document is returned.
                // However, currently there is no way for us to reliably tell a libmongoc cursor is at its end without
                // attempting to iterate it first. To avoid having to implement some sort of caching mechanism we do
                // not close cursors until we attempt to iterate and get nil back, so this cursor is not closed/its
                // connection is not released after 3 iterations, as the test expects.
                "pinned connections are returned when the cursor is drained",
                // These tests assume we do not automatically close the cursor when we encounter such errors, however
                // we close cursors on all errors besides decoding errors, so the connections do get returned.
                "pinned connections are not returned after an network error during getMore",
                "pinned connections are not returned to the pool after a non-network error on getMore",
                // TODO: SWIFT-1322 Unskip.
                "listCollections pins the cursor to a connection",
                // Skipping as we do not support a batchSize for listIndexes. We closed SWIFT-1325 as "won't fix", but
                // should we ever decide to do it we could unskip this test then.
                "listIndexes pins the cursor to a connection"
            ]
        ]

        let runner = try await UnifiedTestRunner()
        try await runner.runFiles(tests, skipTests: skipTests)
    }
}
