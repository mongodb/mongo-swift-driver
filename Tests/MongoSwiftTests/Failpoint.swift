#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import NIOPosix
import TestsCommon

@available(macOS 10.15, *)
/// Convenience type which wraps a `FailPoint` and its corresponding client to handle closing.
struct EnabledFailpoint {
    /// The failpoint.
    let failPoint: FailPoint
    /// Client to use when disabling the failpoint.
    let client: MongoClient

    init(failPoint: FailPoint, client: MongoClient) {
        self.failPoint = failPoint
        self.client = client
    }

    func close() async {
        await self.failPoint.disable(using: self.client)
    }
}

/// Struct modeling a MongoDB fail point.
///
/// - Note: if a fail point results in a connection being closed / interrupted, libmongoc built in debug mode will print
///         a warning.
@available(macOS 10.15, *)
extension FailPoint {
    /// Enables the failpoint, and returns a `EnabledFailpoint` which can handle disabling when needed
    internal func enable(
        using client: MongoClient,
        options: RunCommandOptions? = nil
    ) async throws -> EnabledFailpoint {
        try await client.db("admin").runCommand(self.failPoint, options: options)
        return EnabledFailpoint(failPoint: self, client: client)
    }

    internal func disable(using client: MongoClient) async {
        do {
            let command: BSONDocument = ["configureFailPoint": .string(self.name), "mode": "off"]
            try await client.db("admin").runCommand(command)
        } catch {
            print("Failed to disable failpoint: \(error)")
        }
    }
}

#endif
