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
        let skipTests = [
            // TODO SWIFT-1099: unskip these once we have vendored in C code that handles this.
            "CRUD Api Version 1 (strict)": ["estimatedDocumentCount appends declared API version"],
            "CRUD Api Version 1": ["estimatedDocumentCount appends declared API version on 4.9.0 or greater"]
        ]

        try runner.runFiles(tests, skipTests: skipTests)
    }
}
