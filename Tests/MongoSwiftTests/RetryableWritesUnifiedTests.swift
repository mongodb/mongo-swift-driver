import Foundation
import MongoSwift
import Nimble
import TestsCommon
import XCTest


final class RetryableWritesUnifiedTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    
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
