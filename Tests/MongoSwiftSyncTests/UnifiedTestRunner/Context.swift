import MongoSwiftSync

/// Context passed around while executing tests.
class Context {
    /// Path taken to get to the current state.
    var path: [String]

    /// Entities created for the test.
    var entities: EntityMap

    /// List of (fail point name, server address fail point was set on).
    var enabledFailPoints: [(String, ServerAddress?)] = []

    let internalClient: MongoClient

    init(path: [String], entities: EntityMap, internalClient: MongoClient) {
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
}
