import MongoSwift
/// Protocol that test cases which configure fail points during their execution conform to.
public protocol FailPointConfigured {
    /// The fail point currently set, if one exists.
    var activeFailPoint: FailPoint? { get set }

    /// The address of the host in which this failpoint was set on, if applicable.
    var targetedHost: ServerAddress? { get set }
}

/// Struct modeling a MongoDB fail point.
///
/// - Note: if a fail point results in a connection being closed / interrupted, libmongoc built in debug mode will print
///         a warning.
public struct FailPoint: Decodable {
    public var failPoint: BSONDocument

    /// The fail point being configured.
    public var name: String {
        self.failPoint["configureFailPoint"]?.stringValue ?? ""
    }

    private init(_ document: BSONDocument) {
        self.failPoint = document
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let unordered = try container.decode(BSONDocument.self)
        guard let command = unordered["configureFailPoint"] else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "fail point \(unordered) did not contain \"configureFailPoint\" command"
            )
        }
        var ordered: BSONDocument = ["configureFailPoint": command]
        for (k, v) in unordered {
            guard k != "configureFailPoint" else {
                continue
            }
            ordered[k] = v
        }
        self.failPoint = ordered
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
        blockTimeMS: Int? = nil,
        closeConnection: Bool? = nil,
        errorCode: Int? = nil,
        errorLabels: [String]? = nil,
        writeConcernError: BSONDocument? = nil
    ) -> FailPoint {
        var data: BSONDocument = [
            "failCommands": .array(failCommands.map { .string($0) })
        ]
        if let blockTime = blockTimeMS {
            data["blockTimeMS"] = BSON(blockTime)
            data["blockConnection"] = true
        }
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
