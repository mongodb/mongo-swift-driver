import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

let center = NotificationCenter.default

final class CommandMonitoringTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testCommandMonitoringUnified() throws {
        // these require that command events expose server connection IDs.
        // TODO: SWIFT-1262 Unskip.
        let excludeList = [
            "pre-42-server-connection-id.json",
            "server-connection-id.json"
        ]

        let files = try retrieveSpecTestFiles(
            specName: "command-monitoring",
            subdirectory: "unified",
            excludeFiles: excludeList,
            asType: UnifiedTestFile.self
        ).map { $0.1 }
        let runner = try UnifiedTestRunner()
        try runner.runFiles(files)
    }
}
