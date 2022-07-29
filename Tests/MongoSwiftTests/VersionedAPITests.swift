#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import Nimble
import TestsCommon

@available(macOS 10.15, *)
final class VersionedAPITests: MongoSwiftTestCase {
    func testVersionedAPI() async throws {
        let tests = try retrieveSpecTestFiles(
            specName: "versioned-api",
            asType: UnifiedTestFile.self
        ).map { $0.1 }

        let runner = try await UnifiedTestRunner()
        try await runner.runFiles(tests)
    }
}
#endif
