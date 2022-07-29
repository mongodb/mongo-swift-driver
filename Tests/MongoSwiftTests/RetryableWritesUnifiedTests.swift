#if compiler(>=5.5.2) && canImport(_Concurrency)
import Foundation
import MongoSwift
import Nimble
import TestsCommon
import XCTest

@available(macOS 10.15, *)
final class RetryableWritesUnifiedTests: MongoSwiftTestCase {
    func testRetryableWritesUnified() async throws {
        let tests = try retrieveSpecTestFiles(
            specName: "retryable-writes",
            subdirectory: "unified",
            asType: UnifiedTestFile.self
        ).map { $0.1 }

        let runner = try await UnifiedTestRunner()
        try await runner.runFiles(tests)
    }
}
#endif
