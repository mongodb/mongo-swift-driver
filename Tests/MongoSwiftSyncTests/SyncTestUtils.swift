import Foundation
@testable import class MongoSwift.ClientSession
@testable import MongoSwiftSync
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
    ) throws -> T {
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
    ) throws -> T {
        let ns = ns ?? self.getNamespace()

        guard let collName = ns.collection else {
            throw TestError(message: "missing collection")
        }

        let database = client.db(ns.db)
        let collection: MongoCollection<Document>
        do {
            collection = try database.createCollection(collName, options: options)
        } catch let error as CommandError where error.code == 48 {
            try database.collection(collName).drop()
            collection = try database.createCollection(collName, options: options)
        }
        defer { try? collection.drop() }
        return try f(database, collection)
    }
}

extension MongoClient {
    internal func serverVersion() throws -> ServerVersion {
        let reply = try self.db("admin").runCommand(
            ["buildInfo": 1],
            options: RunCommandOptions(readPreference: .primary)
        )
        guard let versionString = reply["version"]?.stringValue else {
            throw TestError(message: " reply missing version string: \(reply)")
        }
        return try ServerVersion(versionString)
    }

    /// Get the max wire version of the primary.
    internal func maxWireVersion() throws -> Int {
        let options = RunCommandOptions(readPreference: .primary)
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
        _ uri: String = MongoSwiftTestCase.getConnectionString(),
        options: ClientOptions? = nil
    ) throws -> MongoClient {
        var opts = options ?? ClientOptions()
        if MongoSwiftTestCase.ssl {
            opts.tlsCAFile = URL(string: MongoSwiftTestCase.sslCAFilePath ?? "")
            opts.tlsCertificateKeyFile = URL(string: MongoSwiftTestCase.sslPEMKeyFilePath ?? "")
        }
        return try MongoClient(uri, options: opts)
    }

    /// Attaches a `TestCommandMonitor` to the client and returns it.
    internal func addCommandMonitor() -> TestCommandMonitor {
        let monitor = TestCommandMonitor()
        self.addCommandEventHandler(monitor)
        return monitor
    }

    internal func supportsFailCommand() throws -> Bool {
        let version = try self.serverVersion()
        switch MongoSwiftTestCase.topologyType {
        case .sharded:
            return version >= ServerVersion(major: 4, minor: 1, patch: 5)
        default:
            return version >= ServerVersion(major: 4, minor: 0)
        }
    }
}

/// Captures any command monitoring events filtered by type and name that are emitted during the execution of the
/// provided closure. A client pre-configured for command monitoring is passed into the closure.
internal func captureCommandEvents(
    eventTypes: [CommandEvent.EventType]? = nil,
    commandNames: [String]? = nil,
    f: (MongoClient) throws -> Void
) throws -> [CommandEvent] {
    let client = try MongoClient.makeTestClient()
    let monitor = client.addCommandMonitor()

    try monitor.captureEvents {
        try f(client)
    }
    return monitor.events(withEventTypes: eventTypes, withNames: commandNames)
}

extension MongoSwiftSync.MongoCollection {
    public var _client: MongoSwiftSync.MongoClient {
        self.client
    }
}

func executeWithTimeout<T>(timeout: TimeInterval, _ f: @escaping () throws -> T) throws -> T {
    let queue = DispatchQueue(label: "timeoutQueue")
    let lock = DispatchSemaphore(value: 1)
    var result: Result<T, Error> = .failure(TestError(message: "got no result"))

    lock.wait()
    // signal lock after getting it, or signal it because `f` hasn't already
    defer { lock.signal() }

    queue.async {
        result = Result {
            try f()
        }
        lock.signal()
    }
    switch lock.wait(timeout: DispatchTime.now() + timeout) {
    case .success:
        return try result.get()
    case .timedOut:
        throw TestError(message: "timed out")
    }
}

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

extension MongoCursor {
    func all() throws -> [T] {
        try self._all()
    }
}

extension ChangeStream {
    /// Repeatedly poll the change stream until either an event/error is returned or the timeout is hit.
    /// The default timeout is ChangeStreamTests.TIMEOUT.
    func nextWithTimeout(_ timeout: TimeInterval = SyncChangeStreamTests.TIMEOUT) throws -> T? {
        let start = DispatchTime.now()
        while DispatchTime.now() < start + timeout {
            if let event = self.tryNext() {
                return try event.get()
            }
        }
        return nil
    }
}

extension MongoSwiftSync.ClientSession {
    internal var active: Bool { self.asyncSession.active }

    internal var id: Document? { self.asyncSession.id }

    internal var pinnedServerAddress: Address? { self.asyncSession.pinnedServerAddress }

    internal typealias TransactionState = MongoSwift.ClientSession.TransactionState

    internal var transactionState: TransactionState? { self.asyncSession.transactionState }

    internal var isPinned: Bool { self.pinnedServerAddress != nil }
}
