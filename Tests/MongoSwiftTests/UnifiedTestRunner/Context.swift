import MongoSwift

/// Context passed around while executing tests.
class Context {
    /// Path taken to get to the current state.
    var path: [String]

    /// Entities created for the test.
    var entities: EntityMap

    /// Fail points that have been set during test execution and should be disabled on completion.
    //var enabledFailPoints: [FailPointGuard] = []

    let internalClient: UnifiedTestRunner.InternalClient

    init(path: [String], entities: EntityMap, internalClient: UnifiedTestRunner.InternalClient) {
        self.path = path
        self.entities = entities
        self.internalClient = internalClient
    }

    /// Executes a closure with the given path element added to the path, removing it after the closure is complete.
    func withPushedElt<T>(_ elt: String, work: () throws -> T) rethrows -> T {
        self.path.append(elt)
        defer { self.path.removeLast() }
        return try work()
    }
    
    /// Executes an async closure with the given path element added to the path, removing it after the closure is complete.
    func withPushedElt<T>(_ elt: String, work: () async throws -> T) async rethrows -> T {
        self.path.append(elt)
        defer { self.path.removeLast() }
        return try await work()
    }
}
