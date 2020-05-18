import MongoSwiftSync
import TestsCommon

/// Protocol that test cases which configure fail points during their execution conform to.
internal protocol FailPointConfigured {
    /// The fail point currently set, if one exists.
    var activeFailPoint: FailPoint? { get set }
}

extension FailPointConfigured {
    /// Sets the active fail point to the provided fail point and enables it.
    internal mutating func activateFailPoint(_ failPoint: FailPoint, on serverAddress: Address? = nil) throws {
        self.activeFailPoint = failPoint
        try self.activeFailPoint?.enable(on: serverAddress)
    }

    /// If a fail point is active, it is disabled and cleared.
    internal mutating func disableActiveFailPoint() {
        guard let failPoint = self.activeFailPoint else {
            return
        }
        failPoint.disable()
        self.activeFailPoint = nil
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
        self.failPoint["configureFailPoint"]?.stringValue ?? ""
    }

    private init(_ document: Document) {
        self.failPoint = document
    }

    public init(from decoder: Decoder) throws {
        self.failPoint = try Document(from: decoder)
    }

    internal func enable(on serverAddress: Address? = nil) throws {
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
        if let serverAddress = serverAddress {
            let connectionString = MongoSwiftTestCase.getConnectionString(forHost: serverAddress)
            let client = try MongoClient.makeTestClient(connectionString)
            try client.db("admin").runCommand(commandDoc)
        } else {
            let client = try MongoClient.makeTestClient()
            try client.db("admin").runCommand(commandDoc)
        }
    }

    internal func disable() {
        do {
            let client = try MongoClient.makeTestClient()
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
    public static func failCommand(
        failCommands: [String],
        mode: Mode,
        closeConnection: Bool? = nil,
        errorCode: Int? = nil,
        errorLabels: [String]? = nil,
        writeConcernError: Document? = nil
    ) -> FailPoint {
        var data: Document = [
            "failCommands": .array(failCommands.map { .string($0) })
        ]
        if let close = closeConnection {
            data["closeConnection"] = .bool(close)
        }
        if let code = errorCode {
            data["errorCode"] = BSON(code)
        }
        if let labels = errorLabels {
            data["errorLabels"] = .array(labels.map { .string($0) })
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
