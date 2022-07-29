import MongoSwift
import Nimble
import TestsCommon

final class CrudUnifiedTests: MongoSwiftTestCase {
    func testCrudUnified() async throws {
        let skipFiles: [String] = [
            // Skipping because we use bulk-write for these commands and can't pass extra options
            // TODO: SWIFT-1429 unskip
            "deleteOne-let.json",
            "deleteMany-let.json",
            "updateOne-let.json",
            "updateMany-let.json",
            // TODO: SWIFT-1515 unskip
            "estimatedDocumentCount-comment.json"
        ]
        let files = try retrieveSpecTestFiles(
            specName: "crud",
            subdirectory: "unified",
            excludeFiles: skipFiles,
            asType: UnifiedTestFile.self
        )
        let runner = try await UnifiedTestRunner()
        try await runner.runFiles(files.map { $0.1 })
    }
}
