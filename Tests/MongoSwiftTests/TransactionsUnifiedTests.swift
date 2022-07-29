#if compiler(>=5.5.2) && canImport(_Concurrency)
import Foundation
import MongoSwift
import Nimble
import TestsCommon

@available(macOS 10.15, *)
final class TransactionsTests: MongoSwiftTestCase {
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
#endif
