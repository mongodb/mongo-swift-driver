import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

// sourcery: disableTests
class MongoSwiftTestCase: XCTestCase {
    /// Gets the name of the database the test case is running against.
    internal class var testDatabase: String {
        return "test"
    }

    /// Gets the connection string for the database being used for testing from the environment variable, $MONGODB_URI.
    /// If the environment variable does not exist, this will use a default of "mongodb://127.0.0.1/".
    static var connStr: String {
        if let connStr = ProcessInfo.processInfo.environment["MONGODB_URI"] {
            if self.topologyType == .sharded {
                guard let uri = mongoc_uri_new(connStr) else {
                    return connStr
                }

                defer {
                    mongoc_uri_destroy(uri)
                }

                guard let hosts = mongoc_uri_get_hosts(uri) else {
                    return connStr
                }

                let hostAndPort = withUnsafeBytes(of: hosts.pointee.host_and_port) { rawPtr -> String in
                    let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
                    return String(cString: ptr)
                }

                return "mongodb://\(hostAndPort)/"
            }

            return connStr
        }

        return "mongodb://127.0.0.1/"
    }

    // indicates whether we are running on a 32-bit platform
    static let is32Bit = MemoryLayout<Int>.size == 4

    /// Generates a unique collection name of the format "<Test Suite>_<Test Name>_<suffix>". If no suffix is provided,
    /// the last underscore is omitted.
    internal func getCollectionName(suffix: String? = nil) -> String {
        var name = self.name.replacingOccurrences(of: "[\\[\\]-]", with: "", options: [.regularExpression])
        if let suf = suffix {
            name += "_" + suf
        }
        return name.replacingOccurrences(of: "[ \\+\\$]", with: "_", options: [.regularExpression])
    }

    internal func getNamespace(suffix: String? = nil) -> MongoNamespace {
        return MongoNamespace(db: type(of: self).testDatabase, collection: self.getCollectionName(suffix: suffix))
    }

    static var topologyType: TopologyDescription.TopologyType {
        guard let topology = ProcessInfo.processInfo.environment["MONGODB_TOPOLOGY"] else {
            return .single
        }
        return TopologyDescription.TopologyType(from: topology)
    }

    /// Indicates that we are running the tests with SSL enabled, determined by the environment variable $SSL.
    static var ssl: Bool {
        return ProcessInfo.processInfo.environment["SSL"] == "ssl"
    }

    /// Returns the path where the SSL key file is located, determined by the environment variable $SSL_KEY_FILE.
    static var sslPEMKeyFilePath: String? {
        return ProcessInfo.processInfo.environment["SSL_KEY_FILE"]
    }

    /// Returns the path where the SSL CA file is located, determined by the environment variable $SSL_CA_FILE..
    static var sslCAFilePath: String? {
        return ProcessInfo.processInfo.environment["SSL_CA_FILE"]
    }

    /// Temporary helper to assist with skipping tests due to CDRIVER-3318. Returns whether we are running on MacOS.
    /// Remove when SWIFT-539 is completed.
    static var isMacOS: Bool {
#if os(OSX)
        return true
#else
        return false
#endif
    }

    /// Creates the given namespace and passes handles to it and its parents to the given function. After the function
    /// executes, the collection associated with the namespace is dropped.
    ///
    /// Note: If a collection is not specified as part of the input namespace, this function will throw an error.
    internal func withTestNamespace<T>(ns: MongoNamespace? = nil,
                                       clientOptions: ClientOptions? = nil,
                                       collectionOptions: CreateCollectionOptions? = nil,
                                       f: (SyncMongoClient, SyncMongoDatabase, SyncMongoCollection<Document>)
                                       throws -> T)
    throws -> T {
        let client = try SyncMongoClient.makeTestClient(options: clientOptions)

        return try withTestNamespace(client: client, ns: ns, options: collectionOptions) { db, coll in
            try f(client, db, coll)
        }
    }

    /// Creates the given namespace using the given client and passes handles to it and its parent database to the given
    /// function. After the function executes, the collection associated with the namespace is dropped.
    ///
    /// Note: If a collection is not specified as part of the input namespace, this function will throw an error.
    internal func withTestNamespace<T>(client: SyncMongoClient,
                                       ns: MongoNamespace? = nil,
                                       options: CreateCollectionOptions? = nil,
                                       _ f: (SyncMongoDatabase, SyncMongoCollection<Document>) throws -> T)
                                      throws -> T {
        let ns = ns ?? self.getNamespace()

        guard let collName = ns.collection else {
            throw UserError.invalidArgumentError(message: "missing collection")
        }

        let database = client.db(ns.db)
        let collection = try database.createCollection(collName, options: options)
        defer { try? collection.drop() }
        return try f(database, collection)
    }
}

extension SyncMongoClient {
    internal func serverVersion() throws -> ServerVersion {
        // TODO SWIFT-539: switch to always using buildInfo. fails on MacOS + SSL due to CDRIVER-3318
        let cmd = MongoSwiftTestCase.ssl && MongoSwiftTestCase.isMacOS ? "serverStatus" : "buildInfo"
        let reply = try self.db("admin").runCommand([cmd: 1],
                                                    options: RunCommandOptions(
                                                    readPreference: ReadPreference(.primary)))
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

    static func makeTestClient(_ uri: String = MongoSwiftTestCase.connStr,
                               options: ClientOptions? = nil) throws -> SyncMongoClient {
        var opts = options ?? ClientOptions()
        if MongoSwiftTestCase.ssl {
            opts.tlsOptions = TLSOptions(caFile: URL(string: MongoSwiftTestCase.sslCAFilePath ?? ""),
                                         pemFile: URL(string: MongoSwiftTestCase.sslPEMKeyFilePath ?? ""))
        }
        return try SyncMongoClient(uri, options: opts)
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

extension Document {
    internal func sortedEquals(_ other: Document) -> Bool {
        let keys = self.keys.sorted()
        let otherKeys = other.keys.sorted()

        // first compare keys, because rearrangeDoc will discard any that don't exist in `expected`
        expect(keys).to(equal(otherKeys))

        let rearranged = rearrangeDoc(other, toLookLike: self)
        return self == rearranged
    }
}

/// Cleans and normalizes a given JSON string for comparison purposes
func clean(json: String?) -> String {
    guard let str = json else {
        return ""
    }
    do {
        let doc = try Document(fromJSON: str.data(using: .utf8)!)
        return doc.extendedJSON
    } catch {
        print("Failed to clean string: \(str)")
        return String()
    }
}

// Adds a custom "cleanEqual" predicate that compares two JSON strings for equality after normalizing
// them with the "clean" function
internal func cleanEqual(_ expectedValue: String?) -> Predicate<String> {
    return Predicate.define("cleanEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()
        let matches = clean(json: actualValue) == clean(json: expectedValue) && expectedValue != nil
        if expectedValue == nil || actualValue == nil {
            if expectedValue == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

// Adds a custom "sortedEqual" predicate that compares two `Document`s and returns true if they
// have the same key/value pairs in them
internal func sortedEqual(_ expectedValue: Document?) -> Predicate<Document> {
    return Predicate.define("sortedEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()

        guard let expected = expectedValue, let actual = actualValue else {
            if expectedValue == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }

        let matches = expected.sortedEquals(actual)
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

/// Captures any command monitoring events filtered by type and name that are emitted during the execution of the
/// provided closure. Only events emitted by the provided client will be captured.
internal func captureCommandEvents(from client: SyncMongoClient,
                                   eventTypes: [Notification.Name]? = nil,
                                   commandNames: [String]? = nil,
                                   f: () throws -> Void) rethrows -> [MongoCommandEvent] {
    let center = client.notificationCenter
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
internal func captureCommandEvents(eventTypes: [Notification.Name]? = nil,
                                   commandNames: [String]? = nil,
                                   f: (SyncMongoClient) throws -> Void) throws -> [MongoCommandEvent] {
    let client = try SyncMongoClient.makeTestClient(options: ClientOptions(commandMonitoring: true))
    return try captureCommandEvents(from: client, eventTypes: eventTypes, commandNames: commandNames) {
        try f(client)
    }
}

internal func unsupportedTopologyMessage(testName: String,
                                         topology: TopologyDescription.TopologyType = MongoSwiftTestCase.topologyType)
                -> String {
    return "Skipping \(testName) due to unsupported topology type \(topology)"
}

internal func unsupportedServerVersionMessage(testName: String) -> String {
    return "Skipping \(testName) due to unsupported server version."
}
