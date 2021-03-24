import MongoSwiftSync
import Nimble
import TestsCommon

final class VersionedAPITests: MongoSwiftTestCase {
    func testVersionedAPI() throws {
        // just test that we can decode the tests for now.
        _ = try retrieveSpecTestFiles(
            specName: "versioned-api",
            asType: UnifiedTestFile.self
        ).map { $0.1 }
    }
}
