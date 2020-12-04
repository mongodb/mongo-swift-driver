/// Context passed around while executing tests.
class Context {
    /// Path taken to get to the current state.
    var path: [String]

    init(_ path: [String]) {
        self.path = path
    }

    /// Executes a closure with the given path element added to the path, removing it after the closure is complete.
    func withPushedElt<T>(_ elt: String, work: () throws -> T) rethrows -> T {
        self.path.append(elt)
        defer { self.path.removeLast() }
        return try work()
    }
}
