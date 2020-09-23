import MongoSwiftSync
import TestsCommon

/// Protocol that test cases which configure fail points during their execution conform to.
internal protocol FailPointConfigured {
    /// The fail point currently set, if one exists.
    var activeFailPoint: FailPoint? { get set }

    /// The address of the host in which this failpoint was set on, if applicable.
    var targetedHost: ServerAddress? { get set }
}

extension FailPointConfigured {
    /// Sets the active fail point to the provided fail point and enables it.
    internal mutating func activateFailPoint(
        _ failPoint: FailPoint,
        using client: MongoClient,
        on serverAddress: ServerAddress? = nil
    ) throws {
        self.activeFailPoint = failPoint
        try self.activeFailPoint?.enable(using: client, on: serverAddress)
        self.targetedHost = serverAddress
    }

    /// If a fail point is active, it is disabled and cleared.
    internal mutating func disableActiveFailPoint(using client: MongoClient) {
        guard let failPoint = self.activeFailPoint else {
            return
        }
        failPoint.disable(using: client, on: self.targetedHost)
        self.activeFailPoint = nil
        self.targetedHost = nil
    }
}

/// Struct modeling a MongoDB fail point.
///
/// - Note: if a fail point results in a connection being closed / interrupted, libmongoc built in debug mode will print
///         a warning.
internal struct FailPoint: Decodable {
    private var failPoint: BSONDocument

    /// The fail point being configured.
    internal var name: String {
        self.failPoint["configureFailPoint"]?.stringValue ?? ""
    }

    private init(_ document: BSONDocument) {
        self.failPoint = document
    }

    public init(from decoder: Decoder) throws {
        self.failPoint = try BSONDocument(from: decoder)
    }

    internal func enable(using client: MongoClient, on serverAddress: ServerAddress? = nil) throws {
        var commandDoc = ["configureFailPoint": self.failPoint["configureFailPoint"]!] as BSONDocument
        for (k, v) in self.failPoint {
            guard k != "configureFailPoint" else {
                continue
            }

            // Need to convert error codes to int32's due to c driver bug (CDRIVER-3121)
            if k == "data",
                var data = v.documentValue,
                var wcErr = data["writeConcernError"]?.documentValue,
                let code = wcErr["code"] {
                wcErr["code"] = .int32(code.toInt32()!)
                data["writeConcernError"] = .document(wcErr)
                commandDoc["data"] = .document(data)
            } else {
                commandDoc[k] = v
            }
        }
        if let address = serverAddress {
            try client.db("admin").runCommand(commandDoc, on: address)
        } else {
            try client.db("admin").runCommand(commandDoc)
        }
    }

    internal func enable() throws {
        let client = try MongoClient.makeTestClient()
        try self.enable(using: client)
    }

    internal func disable(using client: MongoClient? = nil, on address: ServerAddress? = nil) {
        do {
            let clientToUse: MongoClient
            if let client = client {
                clientToUse = client
            } else {
                clientToUse = try MongoClient.makeTestClient()
            }

            let command: BSONDocument = ["configureFailPoint": .string(self.name), "mode": "off"]

            if let addr = address {
                try clientToUse.db("admin").runCommand(command, on: addr)
            } else {
                try clientToUse.db("admin").runCommand(command)
            }
        } catch _ as MongoError.ServerSelectionError {
            // this often means the server that the failpoint was set against was marked as unknown
            // due to the failpoint firing, so we just ignore
        } catch {
            print("Failed to disable failpoint: \(error)")
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
        writeConcernError: BSONDocument? = nil
    ) -> FailPoint {
        var data: BSONDocument = [
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

        let command: BSONDocument = [
            "configureFailPoint": "failCommand",
            "mode": mode.toBSON(),
            "data": .document(data)
        ]
        return FailPoint(command)
    }
}
