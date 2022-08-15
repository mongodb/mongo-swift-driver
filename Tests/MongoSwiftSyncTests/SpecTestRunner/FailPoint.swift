import MongoSwiftSync
import TestsCommon

extension FailPointConfigured {
    /// Sets the active fail point to the provided fail point and enables it.
    internal mutating func activateFailPoint(
        _ failPoint: FailPoint,
        using client: MongoClient
    ) throws {
        self.activeFailPoint = failPoint
        try self.activeFailPoint?.enable(using: client)
    }

    /// If a fail point is active, it is disabled and cleared.
    internal mutating func disableActiveFailPoint(using client: MongoClient) {
        guard let failPoint = self.activeFailPoint else {
            return
        }
        failPoint.disable(using: client)
        self.activeFailPoint = nil
    }
}

/// Convenience class which wraps a `FailPoint` and disables it upon deinitialization.
class FailPointGuard {
    /// The failpoint.
    let failPoint: FailPoint
    /// Client to use when disabling the failpoint.
    let client: MongoClient

    init(failPoint: FailPoint, client: MongoClient) {
        self.failPoint = failPoint
        self.client = client
    }

    deinit {
        self.failPoint.disable(using: self.client)
    }
}

/// Struct modeling a MongoDB fail point.
///
/// - Note: if a fail point results in a connection being closed / interrupted, libmongoc built in debug mode will print
///         a warning.
extension FailPoint {
    internal func enable(
        using client: MongoClient,
        options: RunCommandOptions? = nil
    ) throws {
        try client.db("admin").runCommand(self.failPoint, options: options)
    }

    /// Enables the failpoint, and returns a `FailPointGuard` which will automatically disable the failpoint
    /// upon deinitialization.
    internal func enableWithGuard(
        using client: MongoClient,
        options: RunCommandOptions? = nil
    ) throws -> FailPointGuard {
        try self.enable(using: client, options: options)
        return FailPointGuard(failPoint: self, client: client)
    }

    internal func enable() throws {
        let client = try MongoClient.makeTestClient()
        try self.enable(using: client)
    }

    internal func disable(using client: MongoClient? = nil) {
        do {
            let clientToUse: MongoClient
            if let client = client {
                clientToUse = client
            } else {
                clientToUse = try MongoClient.makeTestClient()
            }

            let command: BSONDocument = ["configureFailPoint": .string(self.name), "mode": "off"]
            try clientToUse.db("admin").runCommand(command)
        } catch {
            print("Failed to disable failpoint: \(error)")
        }
    }
}
