import MongoSwiftSync
import Nimble
import TestsCommon

final class VersionedAPITests: MongoSwiftTestCase {
    func testVersionedAPI() throws {
        let tests = try retrieveSpecTestFiles(
            specName: "versioned-api",
            asType: UnifiedTestFile.self
        ).map { $0.1 }

        let runner = try UnifiedTestRunner()
        try runner.runFiles(tests)
    }
}
