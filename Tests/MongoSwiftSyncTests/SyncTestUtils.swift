import Foundation
import MongoSwift
import TestsCommon

extension MongoSwiftTestCase {
    /// Creates the given namespace and passes handles to it and its parents to the given function. After the function
    /// executes, the collection associated with the namespace is dropped.
    ///
    /// Note: If a collection is not specified as part of the input namespace, this function will throw an error.
    internal func withTestNamespace<T>(
        ns: MongoNamespace? = nil,
        clientOptions: ClientOptions? = nil,
        collectionOptions: CreateCollectionOptions? = nil,
        f: (MongoClient, MongoDatabase, MongoCollection<Document>)
            throws -> T
    )
        throws -> T {
        let client = try MongoClient.makeTestClient(options: clientOptions)

        return try self.withTestNamespace(client: client, ns: ns, options: collectionOptions) { db, coll in
            try f(client, db, coll)
        }
    }

    /// Creates the given namespace using the given client and passes handles to it and its parent database to the given
    /// function. After the function executes, the collection associated with the namespace is dropped.
    ///
    /// Note: If a collection is not specified as part of the input namespace, this function will throw an error.
    internal func withTestNamespace<T>(
        client: MongoClient,
        ns: MongoNamespace? = nil,
        options: CreateCollectionOptions? = nil,
        _ f: (MongoDatabase, MongoCollection<Document>) throws -> T
    )
        throws -> T {
        let ns = ns ?? self.getNamespace()

        guard let collName = ns.collection else {
            throw TestError(message: "missing collection")
        }

        let database = client.db(ns.db)
        let collection = try database.createCollection(collName, options: options)
        defer { try? collection.drop() }
        return try f(database, collection)
    }
}

extension MongoClient {
    internal func serverVersion() throws -> ServerVersion {
        let reply = try self.db("admin").runCommand(
            ["buildInfo": 1],
            options: RunCommandOptions(
                readPreference: ReadPreference(.primary)
            )
        )
        guard let versionString = reply["version"]?.stringValue else {
            throw TestError(message: " reply missing version string: \(reply)")
        }
        return try ServerVersion(versionString)
    }

    /// Get the max wire version of the primary.
    internal func maxWireVersion() throws -> Int {
        let options = RunCommandOptions(readPreference: ReadPreference(.primary))
        let isMaster = try self.db("admin").runCommand(["isMaster": 1], options: options)
        guard let max = isMaster["maxWireVersion"]?.asInt() else {
            throw TestError(message: "isMaster reply missing maxwireversion \(isMaster)")
        }
        return max
    }

    internal func serverVersionIsInRange(_ min: String?, _ max: String?) throws -> Bool {
        let version = try self.serverVersion()

        if let min = min, version < (try ServerVersion(min)) {
            return false
        }
        if let max = max, version > (try ServerVersion(max)) {
            return false
        }

        return true
    }

    static func makeTestClient(
        _ uri: String = MongoSwiftTestCase.connStr,
        options: ClientOptions? = nil
    ) throws -> MongoClient {
        var opts = options ?? ClientOptions()
        if MongoSwiftTestCase.ssl {
            opts.tlsOptions = TLSOptions(
                caFile: URL(string: MongoSwiftTestCase.sslCAFilePath ?? ""),
                pemFile: URL(string: MongoSwiftTestCase.sslPEMKeyFilePath ?? "")
            )
        }
        return try MongoClient(uri, options: opts)
    }

    internal func supportsFailCommand() -> Bool {
        guard let version = try? self.serverVersion() else {
            return false
        }
        switch MongoSwiftTestCase.topologyType {
        case .sharded:
            return version >= ServerVersion(major: 4, minor: 1, patch: 5)
        default:
            return version >= ServerVersion(major: 4, minor: 0)
        }
    }
}

/// Captures any command monitoring events filtered by type and name that are emitted during the execution of the
/// provided closure. Only events emitted by the provided client will be captured.
internal func captureCommandEvents(
    from _: MongoClient,
    eventTypes: [Notification.Name]? = nil,
    commandNames: [String]? = nil,
    f: () throws -> Void
) rethrows -> [MongoCommandEvent] {
    let center = NotificationCenter.default
    var events: [MongoCommandEvent] = []

    let observer = center.addObserver(forName: nil, object: nil, queue: nil) { notif in
        guard let event = notif.userInfo?["event"] as? MongoCommandEvent else {
            return
        }

        if let eventWhitelist = eventTypes {
            guard eventWhitelist.contains(type(of: event).eventName) else {
                return
            }
        }
        if let whitelist = commandNames {
            guard whitelist.contains(event.commandName) else {
                return
            }
        }
        events.append(event)
    }
    defer { center.removeObserver(observer) }

    try f()

    return events
}

/// Captures any command monitoring events filtered by type and name that are emitted during the execution of the
/// provided closure. A client pre-configured for command monitoring is passed into the closure.
internal func captureCommandEvents(
    eventTypes: [Notification.Name]? = nil,
    commandNames: [String]? = nil,
    f: (MongoClient) throws -> Void
) throws -> [MongoCommandEvent] {
    let client = try MongoClient.makeTestClient(options: ClientOptions(commandMonitoring: true))
    return try captureCommandEvents(from: client, eventTypes: eventTypes, commandNames: commandNames) {
        try f(client)
    }
}

extension ChangeStream {
    /// Repeatedly poll the change stream until either an event/error is returned or the timeout is hit.
    /// The default timeout is ChangeStreamTests.TIMEOUT.
    func nextWithTimeout(_ timeout: TimeInterval = ChangeStreamTests.TIMEOUT) throws -> T? {
        let start = DispatchTime.now()
        while DispatchTime.now() < start + timeout {
            if let event = self.next() {
                return event
            } else if let error = self.error {
                throw error
            }
        }
        return nil
    }
}
