/// Represents a MongoDB connection string.
/// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
public struct MongoConnectionString: Codable, LosslessStringConvertible {
    /// Represents a connection string scheme.
    public struct Scheme: LosslessStringConvertible, Equatable {
        /// Indicates that this connection string uses the scheme `mongodb`.
        public static let mongodb = Scheme(.mongodb)

        /// Indicates that this connection string uses the scheme `mongodb+srv`.
        public static let srv = Scheme(.srv)

        /// Internal representation of a scheme.
        private enum _Scheme: String {
            case mongodb
            case srv = "mongodb+srv"
        }

        private let _scheme: _Scheme

        private init(_ value: _Scheme) {
            self._scheme = value
        }

        /// LosslessStringConvertible` protocol requirements
        public init?(_ description: String) {
            guard let _scheme = _Scheme(rawValue: description) else {
                return nil
            }
            self.init(_scheme)
        }

        public var description: String { self._scheme.rawValue }
    }

    /// Parses `input` into its constituent parts.
    /// - Throws:
    ///   - `MongoError.InvalidArgumentError` if the input is invalid.
    public init(throwsIfInvalid input: String) throws {
        let getScheme = input.components(separatedBy: "://")
        guard getScheme.count > 1, let scheme = Scheme(getScheme[0]) else {
            throw MongoError.InvalidArgumentError(
                message: "Invalid connection string scheme, expecting \'mongodb\' or \'mongodb+srv\'"
            )
        }
        let getUser = getScheme[1].components(separatedBy: "@")
        let userInfo = getUser.count > 1 ? getUser[0].components(separatedBy: ":") : nil
        let getHost = getUser.count > 1 ? getUser[1].components(separatedBy: "/") :
            getUser[0].components(separatedBy: "/")
        guard let hosts = try? getHost[0].components(separatedBy: ",").map(ServerAddress.init) else {
            throw MongoError.InvalidArgumentError(message: "Invalid URI Host")
        }
        let getAuth = getHost.count > 1 ? getHost[1].components(separatedBy: "?") : nil
        let source = (getAuth?[0] ?? "").isEmpty ? nil : getAuth?[0]
        let cred = userInfo != nil || getAuth != nil ?
            MongoCredential(username: userInfo?[0], password: userInfo?[1], source: source) : nil
        let getOptions = getAuth != nil ? getAuth?[1] : nil
        if let options = getOptions?.components(separatedBy: "&") {
            self.temporaryOptions = options
        }
        self.scheme = scheme
        self.hosts = hosts
        self.credential = cred
    }

    /// `Codable` conformance
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        try self.init(throwsIfInvalid: stringValue)
    }

    /// `LosslessStringConvertible` protocol requirements
    public init?(_ description: String) {
        try? self.init(throwsIfInvalid: description)
    }

    public var description: String {
        var des = ""
        des += "\(self.scheme)://"
        if let username = credential?.username, let password = credential?.password {
            des += "\(username):\(password)@"
        }
        des += self.hosts.map { $0.description }.joined(separator: ",")
        if let source = credential?.source {
            des += "/\(source)"
        } else {
            des += "/"
        }
        return des
    }

    /// Specifies the format this connection string is in.
    public var scheme: Scheme

    /// Specifies one or more host/ports to connect to.
    public var hosts: [ServerAddress]

    /// Authentication credentials for the `MongoClient`.
    public var credential: MongoCredential?

    public var temporaryOptions: [String]?
}
