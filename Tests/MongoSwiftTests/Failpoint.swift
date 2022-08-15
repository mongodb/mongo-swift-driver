#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import TestsCommon

@available(macOS 10.15, *)
extension FailPointConfigured {
    /// Sets the active fail point to the provided fail point and enables it.
    internal mutating func activateFailPoint(
        _ failPoint: FailPoint,
        using client: MongoClient
    ) async throws {
        self.activeFailPoint = failPoint
        try await self.activeFailPoint?.enable(using: client)
    }

    /// If a fail point is active, it is disabled and cleared.
    internal mutating func disableActiveFailPoint(using client: MongoClient) async {
        guard let failPoint = self.activeFailPoint else {
            return
        }
        await failPoint.disable(using: client)
        self.activeFailPoint = nil
    }
}

/// Convenience class which wraps a `FailPoint` and disables it upon deinitialization.
class EnabledFailpoint {
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
    internal func enable(
        using client: MongoClient,
        options: RunCommandOptions? = nil
    ) async throws {
        try await client.db("admin").runCommand(self.failPoint, options: options)
    }

    /// Enables the failpoint, and returns a `EnabledFailpoint` which can handle disabling when needed
    internal func enableWithGuard(
        using client: MongoClient,
        options: RunCommandOptions? = nil
    ) async throws -> EnabledFailpoint {
        try await self.enable(using: client, options: options)
        return EnabledFailpoint(failPoint: self, client: client)
    }

    internal func enable() async throws {
        let client = try MongoClient.makeTestClient()
        try await self.enable(using: client)
    }

    internal func disable(using client: MongoClient? = nil) async {
        do {
            let clientToUse: MongoClient
            if let client = client {
                clientToUse = client
            } else {
                clientToUse = try MongoClient.makeTestClient()
            }

            let command: BSONDocument = ["configureFailPoint": .string(self.name), "mode": "off"]
            try await clientToUse.db("admin").runCommand(command)
        } catch {
            print("Failed to disable failpoint: \(error)")
        }
    }
}

#endif
