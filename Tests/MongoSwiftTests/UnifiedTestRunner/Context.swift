#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift

/// Context passed around while executing tests.
@available(macOS 10.15, *)
class Context {
    /// Path taken to get to the current state.
    var path: [String]

    /// Entities created for the test.
    var entities: EntityMap

    /// Fail points that have been set during test execution and should be disabled on completion.
    var enabledFailPoints: [EnabledFailpoint] = []

    let internalClient: UnifiedTestRunner.InternalClient

    init(path: [String], entities: EntityMap, internalClient: UnifiedTestRunner.InternalClient) {
        self.path = path
        self.entities = entities
        self.internalClient = internalClient
    }

    /// Disables all failpoints that were enabled during the execution of this context's corresponding test case.
    func disableFailpoints() async {
        for enabledFailPoint in self.enabledFailPoints {
            await enabledFailPoint.close()
        }
    }

    /// Executes a closure with the given path element added to the path, removing it after closure completes.
    func withPushedElt<T>(_ elt: String, work: () throws -> T) rethrows -> T {
        self.path.append(elt)
        defer { self.path.removeLast() }
        return try work()
    }

    /// Executes an async closure with the given path element added to the path, removing it after closure completes.
    func withPushedElt<T>(_ elt: String, work: () async throws -> T) async rethrows -> T {
        self.path.append(elt)
        defer { self.path.removeLast() }
        return try await work()
    }
}
#endif
