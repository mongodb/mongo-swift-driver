import Foundation

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

    /// A struct representing a host identifier, consisting of a host and an optional port.
    /// In standard connection strings, this describes the address of a mongod or mongos to connect to.
    /// In mongodb+srv connection strings, this describes a DNS name to be queried for SRV and TXT records.
    public struct HostIdentifier: Equatable, CustomStringConvertible {
        private static func parsePort(from: String) throws -> UInt16 {
            guard let port = UInt16(from), port > 0 else {
                throw MongoError.InvalidArgumentError(
                    message: "port must be a valid, positive unsigned 16 bit integer"
                )
            }
            return port
        }

        private enum HostType: String {
            case ipv4
            case ipLiteral = "ip_literal"
            case hostname
            case unixDomainSocket
        }

        /// The hostname or IP address.
        public let host: String

        /// The port number.
        public let port: UInt16?

        private let type: HostType

        /// Initializes a ServerAddress, using the default localhost:27017 if a host/port is not provided.
        internal init(_ hostAndPort: String = "localhost:27017") throws {
            guard !hostAndPort.contains("?") else {
                throw MongoError.InvalidArgumentError(message: "\(hostAndPort) contains invalid characters")
            }

            // Check if host is an IPv6 literal.
            if hostAndPort.first == "[" {
                let ipLiteralRegex = try NSRegularExpression(pattern: #"^\[(.*)\](?::([0-9]+))?$"#)
                guard
                    let match = ipLiteralRegex.firstMatch(
                        in: hostAndPort,
                        range: NSRange(hostAndPort.startIndex..<hostAndPort.endIndex, in: hostAndPort)
                    ),
                    let hostRange = Range(match.range(at: 1), in: hostAndPort)
                else {
                    throw MongoError.InvalidArgumentError(message: "Couldn't parse address from \(hostAndPort)")
                }
                self.host = String(hostAndPort[hostRange])
                if let portRange = Range(match.range(at: 2), in: hostAndPort) {
                    self.port = try HostIdentifier.parsePort(from: String(hostAndPort[portRange]))
                } else {
                    self.port = nil
                }
                self.type = .ipLiteral
            } else {
                let parts = hostAndPort.components(separatedBy: ":")
                self.host = String(parts[0])
                guard parts.count <= 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "Expected only a single port delimiter ':' in \(hostAndPort)"
                    )
                }
                if parts.count > 1 {
                    self.port = try HostIdentifier.parsePort(from: parts[1])
                } else {
                    self.port = nil
                }
                self.type = .hostname
            }
        }

        public var description: String {
            var ret = ""
            switch self.type {
            case .ipLiteral:
                ret += "[\(self.host)]"
            default:
                ret += "\(self.host)"
            }
            if let port = self.port {
                ret += ":\(port)"
            }
            return ret
        }
    }

    private static func percentDecode(from: String?) throws -> String? {
        guard let from = from else {
            return nil
        }
        guard let decoded = from.removingPercentEncoding else {
            throw MongoError.InvalidArgumentError(
                message: "Connection string contains an unescaped percent sign"
            )
        }
        return decoded
    }

    private mutating func applyAndValidateAuthOptions(authOptions: [String: String]) throws {
        for (key, value) in authOptions {
            switch key {
            case "authSource":
                guard self.credential != nil else {
                    throw MongoError.InvalidArgumentError(
                        message: "Authentication mechanism requires username"
                    )
                }
                self.credential?.source = value
            case "authMechanism":
                if self.credential == nil, value == "MONGODB-X509" {
                    self.credential = MongoCredential(mechanism: .mongodbX509)
                } else {
                    guard self.credential != nil else {
                        throw MongoError.InvalidArgumentError(
                            message: "Authentication mechanism requires username"
                        )
                    }
                    self.credential?.mechanism = MongoCredential.Mechanism(value)
                }
            case "authMechanismProperties":
                guard self.credential != nil else {
                    throw MongoError.InvalidArgumentError(
                        message: "Authentication mechanism requires username"
                    )
                }
                var authMechanismProperties = BSONDocument()
                for property in value.components(separatedBy: ",") {
                    let propertyKeyValue = property.components(separatedBy: ":")
                    guard propertyKeyValue.count == 2 else {
                        throw MongoError.InvalidArgumentError(
                            message: "Invalid key value pair for authMechanismProperties \(propertyKeyValue)"
                        )
                    }
                    let propertyKey = propertyKeyValue[0]
                    let propertyValue = propertyKeyValue[1]
                    switch propertyKey {
                    case "SERVICE_NAME", "SERVICE_REALM":
                        authMechanismProperties[propertyKey] = .string(propertyValue)
                    case "CANONICALIZE_HOST_NAME":
                        guard let canonicalize = Bool(propertyValue) else {
                            throw MongoError.InvalidArgumentError(
                                message: "CANONICALIZE_HOST_NAME must be 'true' or 'false' \(propertyKeyValue)"
                            )
                        }
                        authMechanismProperties[propertyKey] = .bool(canonicalize)
                    default:
                        throw MongoError.InvalidArgumentError(
                            message: "Unknown authMechanismProperties option \(propertyKey)"
                        )
                    }
                }
                self.credential?.mechanismProperties = authMechanismProperties
            default:
                throw MongoError.InternalError(
                    message: "Unreachable case statement"
                )
            }
        }

        switch self.credential?.mechanism {
        case MongoCredential.Mechanism.gssAPI:
            guard
                self.credential?.username != nil,
                self.credential?.source ?? "$external" == "$external"
            else {
                throw MongoError.InvalidArgumentError(
                    message: "Invalid options for GSSAPI mechanism"
                )
            }
        case MongoCredential.Mechanism.mongodbX509:
            guard
                self.credential?.password == nil,
                self.credential?.mechanismProperties == nil
            else {
                throw MongoError.InvalidArgumentError(
                    message: "Invalid options for MONGODB-X509 mechanism"
                )
            }
        case MongoCredential.Mechanism.plain,
             MongoCredential.Mechanism.scramSHA1,
             MongoCredential.Mechanism.scramSHA256:
            guard
                self.credential?.username != nil,
                self.credential?.password != nil,
                self.credential?.mechanismProperties == nil
            else {
                throw MongoError.InvalidArgumentError(
                    message: "Invalid options for \(String(describing: self.credential?.mechanism)) mechanism"
                )
            }
            if self.credential?.source == nil {
                self.credential?.source = self.defaultAuthDB
            }
        default:
            if self.credential?.source == nil {
                self.credential?.source = self.defaultAuthDB
            }
        }
    }

    /// Parses a new `MongoConnectionString` instance from the provided string.
    /// - Throws:
    ///   - `MongoError.InvalidArgumentError` if the input is invalid.
    public init(throwsIfInvalid input: String) throws {
        let schemeAndRest = input.components(separatedBy: "://")
        guard schemeAndRest.count == 2, let scheme = Scheme(schemeAndRest[0]) else {
            throw MongoError.InvalidArgumentError(
                message: "Invalid connection string scheme, expecting \'mongodb\' or \'mongodb+srv\'"
            )
        }
        self.scheme = scheme
        guard !schemeAndRest[1].isEmpty else {
            throw MongoError.InvalidArgumentError(message: "Invalid connection string")
        }
        let identifiersAndOptions = schemeAndRest[1].components(separatedBy: "/")
        // TODO: SWIFT-1174: handle unescaped slashes in unix domain sockets.
        guard identifiersAndOptions.count <= 2 else {
            throw MongoError.InvalidArgumentError(
                message: "Connection string contains an unescaped slash"
            )
        }
        let userAndHost = identifiersAndOptions[0].components(separatedBy: "@")
        guard userAndHost.count <= 2 else {
            throw MongoError.InvalidArgumentError(message: "Invalid user information")
        }
        let userInfo = userAndHost.count == 2 ? userAndHost[0].components(separatedBy: ":") : nil
        let hostString = userInfo != nil ? userAndHost[1] : userAndHost[0]
        let hosts = try hostString.components(separatedBy: ",").map(HostIdentifier.init)
        self.hosts = hosts
        if case .srv = scheme {
            guard hosts.count == 1 else {
                throw MongoError.InvalidArgumentError(
                    message: "Only a single host identifier may be specified in a mongodb+srv connection string")
            }
            guard hosts[0].port == nil else {
                throw MongoError.InvalidArgumentError(
                    message: "A port cannot be specified in a mongodb+srv connection string")
            }
        }
        if let userInfoExists = userInfo {
            guard userInfoExists.count <= 2 else {
                throw MongoError.InvalidArgumentError(
                    message: "Expected only a single auth info delimiter ':'"
                )
            }
            self.credential = MongoCredential(
                username: try MongoConnectionString.percentDecode(from: userInfoExists[0]),
                password: userInfoExists.count == 2 ?
                    try MongoConnectionString.percentDecode(from: userInfoExists[1]) : nil
            )
        }
        guard let authDBAndOptions = identifiersAndOptions.count == 2 ?
            identifiersAndOptions[1].components(separatedBy: "?") : nil
        else {
            return
        }
        guard authDBAndOptions.count <= 2 else {
            throw MongoError.InvalidArgumentError(
                message: "Connection string contains an unexpected '?'"
            )
        }
        var defaultAuthDB = try MongoConnectionString.percentDecode(from: authDBAndOptions[0])
        if (defaultAuthDB ?? "").isEmpty {
            defaultAuthDB = nil
        }
        var authOptions: [String: String] = [:]
        let optionString = authDBAndOptions.count == 2 ? authDBAndOptions[1] : nil
        if let options = optionString?.components(separatedBy: "&") {
            for option in options {
                let keyValue = option.components(separatedBy: "=")
                guard keyValue.count == 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "Invalid key value pair for option \(keyValue)"
                    )
                }
                let key = keyValue[0]
                let value = keyValue[1]
                switch key {
                // authentication options.
                case "authSource", "authMechanism", "authMechanismProperties":
                    authOptions[key] = value
                default:
                    // Ignore unrecognized options.
                    break
                }
            }
        }
        self.defaultAuthDB = defaultAuthDB
        try self.applyAndValidateAuthOptions(authOptions: authOptions)
    }

    /// `Codable` conformance
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
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
        if let username = self.credential?.username {
            des += username
            if let password = self.credential?.password {
                des += ":\(password)"
            }
            des += "@"
        }
        des += self.hosts.map { $0.description }.joined(separator: ",")
        var options: [String] = []
        if let mechanism = self.credential?.mechanism {
            options.append("authMechanism=\(mechanism)")
        }
        if (self.defaultAuthDB ?? "").isEmpty, let authSource = self.credential?.source {
            options.append("authSource=\(authSource)")
        }
        if let mechanismProperty = self.credential?.mechanismProperties,
           !mechanismProperty.isEmpty
        {
            var properties: [String] = []
            // TODO: SWIFT-1177 Remove after BSON conforms to CustomStringConvertible
            for (k, v) in mechanismProperty {
                if let value = v.stringValue {
                    properties.append("\(k):\(value)")
                } else if let value = v.boolValue {
                    properties.append("\(k):\(String(value))")
                }
            }
            options.append("authMechanismProperties=\(properties.joined(separator: ","))")
        }
        if !options.isEmpty {
            if let defaultAuthDB = self.defaultAuthDB {
                des += "/\(defaultAuthDB)"
            } else {
                des += "/"
            }
            des += "?\(options.joined(separator: "&"))"
        } else {
            if let defaultAuthDB = self.defaultAuthDB {
                des += "/\(defaultAuthDB)"
            }
        }
        return des
    }

    /// Specifies the format this connection string is in.
    public var scheme: Scheme

    /// Specifies one or more host/ports to connect to.
    public var hosts: [HostIdentifier]

    /// Returns the credential configured on this URI. Will be nil if no options are set.
    public var credential: MongoCredential?

    /// Specifies the authentication database to use when username and password are specified but
    /// authSource is unspecified.
    /// Will be `admin` if both `defaultAuthDB` and `authSource` are unspecified.
    public var defaultAuthDB: String?
}
