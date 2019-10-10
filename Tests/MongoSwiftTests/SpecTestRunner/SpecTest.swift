import Foundation
@testable import MongoSwift
import Nimble
import XCTest

/// A struct containing the portions of a `CommandStartedEvent` the spec tests use for testing.
internal struct TestCommandStartedEvent: Decodable, Matchable {
    let command: Document

    let commandName: String

    let databaseName: String

    internal enum CodingKeys: String, CodingKey {
        case command, commandName = "command_name", databaseName = "database_name"
    }

    internal enum TopLevelCodingKeys: String, CodingKey {
        case type = "command_started_event"
    }

    internal init(from event: CommandStartedEvent) {
        self.command = event.command
        self.databaseName = event.databaseName
        self.commandName = event.commandName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TopLevelCodingKeys.self)
        let eventContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .type)
        self.command = try eventContainer.decode(Document.self, forKey: .command)
        self.commandName = try eventContainer.decode(String.self, forKey: .commandName)
        self.databaseName = try eventContainer.decode(String.self, forKey: .databaseName)
    }

    internal func contentMatches(expected: TestCommandStartedEvent) -> Bool {
        return self.commandName.matches(expected: expected.commandName)
                && self.databaseName.matches(expected: expected.databaseName)
                && self.command.matches(expected: expected.command)
    }
}

/// Protocol that test cases which configure fail points during their execution conform to.
internal protocol FailPointConfigured: class {
    /// The fail point currently set, if one exists.
    var activeFailPoint: FailPoint? { get set }
}

extension FailPointConfigured {
    /// Sets the active fail point to the provided fail point and enables it.
    internal func activateFailPoint(_ failPoint: FailPoint) throws {
        self.activeFailPoint = failPoint
        try self.activeFailPoint?.enable()
    }

    /// If a fail point is active, it is disabled and cleared.
    internal func disableActiveFailPoint() {
        if let failPoint = self.activeFailPoint {
            failPoint.disable()
            self.activeFailPoint = nil
        }
    }
}

/// Struct modeling a MongoDB fail point.
///
/// - Note: if a fail point results in a connection being closed / interrupted, libmongoc built in debug mode will print
///         a warning.
internal struct FailPoint: Decodable {
    private var failPoint: Document

    /// The fail point being configured.
    internal var name: String {
        return self.failPoint["configureFailPoint"]?.stringValue ?? ""
    }

    private init(_ document: Document) {
        self.failPoint = document
    }

    public init(from decoder: Decoder) throws {
        self.failPoint = try Document(from: decoder)
    }

    internal func enable() throws {
        var commandDoc = ["configureFailPoint": self.failPoint["configureFailPoint"]!] as Document
        for (k, v) in self.failPoint {
            guard k != "configureFailPoint" else {
                continue
            }

            // Need to convert error codes to int32's due to c driver bug (CDRIVER-3121)
            if k == "data",
               var data = v.documentValue,
               var wcErr = data["writeConcernError"]?.documentValue,
               let code = wcErr["code"] {
                wcErr["code"] = .int32(code.asInt32()!)
                data["writeConcernError"] = .document(wcErr)
                commandDoc["data"] = .document(data)
            } else {
                commandDoc[k] = v
            }
        }
        let client = try SyncMongoClient.makeTestClient()
        try client.db("admin").runCommand(commandDoc)
    }

    internal func disable() {
        do {
            let client = try SyncMongoClient.makeTestClient()
            try client.db("admin").runCommand(["configureFailPoint": .string(self.name), "mode": "off"])
        } catch {
            print("Failed to disable fail point \(self.name): \(error)")
        }
    }

    /// Enum representing the options for the "mode" field of a `configureFailPoint` command.
    public enum Mode {
        case times(Int)
        case alwaysOn
        case off
        case activationProbability(Double)

        internal func toBSON() -> BSON {
            switch self {
            case let .times(i):
                return ["times": BSON(i)]
            case let .activationProbability(d):
                return ["activationProbability": .double(d)]
            default:
                return .string(String(describing: self))
            }
        }
    }

    /// Factory function for creating a `failCommand` failpoint.
    /// Note: enabling a `failCommand` failpoint will override any other `failCommand` failpoint that is currently
    /// enabled.
    /// For more information, see the wiki: https://github.com/mongodb/mongo/wiki/The-%22failCommand%22-fail-point
    public static func failCommand(failCommands: [String],
                                   mode: Mode,
                                   closeConnection: Bool? = nil,
                                   errorCode: Int? = nil,
                                   writeConcernError: Document? = nil) -> FailPoint {
        var data: Document = [
            "failCommands": .array(failCommands.map { .string($0) })
        ]
        if let close = closeConnection {
            data["closeConnection"] = .bool(close)
        }
        if let code = errorCode {
            data["errorCode"] = BSON(code)
        }
        if let writeConcernError = writeConcernError {
            data["writeConcernError"] = .document(writeConcernError)
        }

        let command: Document = [
            "configureFailPoint": "failCommand",
            "mode": mode.toBSON(),
            "data": .document(data)
        ]
        return FailPoint(command)
    }
}

/// A struct representing a server version.
internal struct ServerVersion: Comparable, Decodable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    /// initialize a server version from a string
    init(_ str: String) throws {
        let versionComponents = str.split(separator: ".").prefix(3)
        guard versionComponents.count >= 2 else {
            throw TestError(message: "Expected version string \(str) to have at least two .-separated components")
        }

        guard let major = Int(versionComponents[0]) else {
            throw TestError(message: "Error parsing major version from \(str)")
        }
        guard let minor = Int(versionComponents[1]) else {
            throw TestError(message: "Error parsing minor version from \(str)")
        }

        var patch = 0
        if versionComponents.count == 3 {
            // in case there is text at the end, for ex "3.6.0-rc1", stop first time
            /// we encounter a non-numeric character.
            let numbersOnly = versionComponents[2].prefix { "0123456789".contains($0) }
            guard let patchValue = Int(numbersOnly) else {
                throw TestError(message: "Error parsing patch version from \(str)")
            }
            patch = patchValue
        }

        self.init(major: major, minor: minor, patch: patch)
    }

    init(from decoder: Decoder) throws {
        let str = try decoder.singleValueContainer().decode(String.self)
        try self.init(str)
    }

    // initialize given major, minor, and optional patch
    init(major: Int, minor: Int, patch: Int? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch ?? 0
    }

    var description: String {
        return "\(major).\(minor).\(patch)"
    }

    static func < (lhs: ServerVersion, rhs: ServerVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        } else if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        } else {
            return lhs.patch < rhs.patch
        }
    }
}

/// Struct representing conditions that a deployment must meet in order for a test file to be run.
internal struct TestRequirement: Decodable {
    private let minServerVersion: ServerVersion?
    private let maxServerVersion: ServerVersion?
    private let topology: [String]?

    /// Determines if the given deployment meets this requirement.
    func isMet(by version: ServerVersion, _ topology: TopologyDescription.TopologyType) -> Bool {
        if let minVersion = self.minServerVersion {
            guard minVersion <= version else {
                return false
            }
        }
        if let maxVersion = self.maxServerVersion {
            guard maxVersion >= version else {
                return false
            }
        }
        if let topologies = self.topology?.map({ TopologyDescription.TopologyType(from: $0) }) {
            guard topologies.contains(topology) else {
                return false
            }
        }
        return true
    }
}

/// Struct representing the contents of a collection after a spec test has been run.
internal struct CollectionTestInfo: Decodable {
    /// An optional name specifying a collection whose documents match the `data` field of this struct.
    /// If nil, whatever collection used in the test should be used instead.
    let name: String?

    /// The documents found in the collection.
    let data: [Document]
}

/// Struct representing an "outcome" defined in a spec test.
internal struct TestOutcome: Decodable {
    /// Whether an error is expected or not.
    let error: Bool?

    /// The expected result of running the operation associated with this test.
    let result: TestOperationResult?

    /// The expected state of the collection at the end of the test.
    let collection: CollectionTestInfo
}

/// Protocol defining the behavior of an individual spec test.
internal protocol SpecTest {
    var description: String { get }
    var outcome: TestOutcome { get }
    var operation: AnyTestOperation { get }

    /// Runs the operation with the given context and performs assertions on the result based upon the expected outcome.
    func run(client: SyncMongoClient,
             db: SyncMongoDatabase,
             collection: SyncMongoCollection<Document>,
             session: SyncClientSession?) throws
}

/// Default implementation of a test execution.
extension SpecTest {
    internal func run(client: SyncMongoClient,
                      db: SyncMongoDatabase,
                      collection: SyncMongoCollection<Document>,
                      session: SyncClientSession?) throws {
        var result: TestOperationResult?
        var seenError: Error?
        do {
            result = try self.operation.op.execute(
                    client: client,
                    database: db,
                    collection: collection,
                    session: session)
        } catch {
            if case let ServerError.bulkWriteError(_, _, _, bulkResult, _) = error {
                result = TestOperationResult(from: bulkResult)
            }
            seenError = error
        }

        if self.outcome.error ?? false {
            expect(seenError).toNot(beNil(), description: self.description)
        } else {
            expect(seenError).to(beNil(), description: self.description)
        }

        if let expectedResult = self.outcome.result {
            expect(result).toNot(beNil())
            expect(result).to(equal(expectedResult))
        }
        let verifyColl = db.collection(self.outcome.collection.name ?? collection.name)
        let foundDocs = try Array(verifyColl.find())
        expect(foundDocs.count).to(equal(self.outcome.collection.data.count))
        zip(foundDocs, self.outcome.collection.data).forEach {
            expect($0).to(sortedEqual($1), description: self.description)
        }
    }
}
