#if compiler(>=5.5.2) && canImport(_Concurrency)
import TestsCommon

@available(macOS 10.15, *)
final class CommandMonitoringTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testCommandMonitoringUnified() async throws {
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
        let runner = try await UnifiedTestRunner()
        try await runner.runFiles(files)
    }
}
#endif
