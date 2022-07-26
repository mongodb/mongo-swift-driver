import MongoSwift
import Nimble
import TestsCommon

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
