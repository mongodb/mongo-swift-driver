import Foundation
import MongoSwift
import Nimble
import TestsCommon

final class TransactionsTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testTransactionsUnified() async throws {
        let files = try retrieveSpecTestFiles(
            specName: "transactions",
            subdirectory: "unified",
            asType: UnifiedTestFile.self
        )
        let runner = try await UnifiedTestRunner()
        try await runner.runFiles(files.map { $0.1 })
    }
}
