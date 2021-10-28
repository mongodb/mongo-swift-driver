import Foundation

/// Represents a MongoDB connection string.
/// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
public struct MongoConnectionString: Codable, LosslessStringConvertible {
    private static let forbiddenDBCharacters = ["/", "\\", " ", "\"", "$"]
    /// Forbidden characters per RFC 3986.
    /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc3986#section-2.2
    fileprivate static let forbiddenUserInfoCharacters = [":", "/", "?", "#", "[", "]", "@"]

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
            // TODO: SWIFT-1407: support IPv4 address parsing.
            if hostAndPort.first == "[" {
                let ipLiteralRegex = try NSRegularExpression(pattern: #"^\[(.*)\](?::([0-9]+))?$"#)
                guard
                    let match = ipLiteralRegex.firstMatch(
                        in: hostAndPort,
                        range: NSRange(hostAndPort.startIndex..<hostAndPort.endIndex, in: hostAndPort)
                    ),
                    let hostRange = Range(match.range(at: 1), in: hostAndPort)
                else {
                    throw MongoError.InvalidArgumentError(message: "couldn't parse address from \(hostAndPort)")
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
                        message: "expected only a single port delimiter ':' in \(hostAndPort)"
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

    private struct Options {
        fileprivate var authSource: String?
        fileprivate var authMechanism: MongoCredential.Mechanism?
        fileprivate var authMechanismProperties: BSONDocument?

        fileprivate init(_ uriOptions: String) throws {
            let options = uriOptions.components(separatedBy: "&")
            for option in options {
                let nameAndValue = option.components(separatedBy: "=")
                guard nameAndValue.count == 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "Option name and value must be of the form <name>=<value> not containing unescaped"
                            + " equals signs"
                    )
                }
                let name = nameAndValue[0].lowercased()
                let value = try nameAndValue[1].getPercentDecoded(forKey: name)
                switch name {
                case "authsource":
                    if value.isEmpty {
                        throw MongoError.InvalidArgumentError(
                            message: "Connection string authSource option must not be empty"
                        )
                    }
                    self.authSource = value
                case "authmechanism":
                    self.authMechanism = try MongoCredential.Mechanism(value)
                case "authmechanismproperties":
                    self.authMechanismProperties = try self.parseAuthMechanismProperties(properties: value)
                default:
                    // TODO: SWIFT-1163: error on unknown options
                    break
                }
            }
        }

        private func parseAuthMechanismProperties(properties: String) throws -> BSONDocument {
            var propertiesDoc = BSONDocument()
            for property in properties.components(separatedBy: ",") {
                let kv = property.components(separatedBy: ":")
                guard kv.count == 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "authMechanismProperties must be a comma-separated list of colon-separated"
                            + " key-value pairs"
                    )
                }
                switch kv[0].lowercased() {
                case "service_name", "service_realm":
                    propertiesDoc[kv[0]] = .string(kv[1])
                case "canonicalize_host_name":
                    switch kv[1] {
                    case "true":
                        propertiesDoc[kv[0]] = .bool(true)
                    case "false":
                        propertiesDoc[kv[0]] = .bool(false)
                    default:
                        throw MongoError.InvalidArgumentError(
                            message: "Value for CANONICALIZE_HOST_NAME in authMechanismProperties must be true or false"
                        )
                    }
                case let other:
                    throw MongoError.InvalidArgumentError(message: "Unknown key for authMechanismProperties: \(other)")
                }
            }
            return propertiesDoc
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
            throw MongoError.InvalidArgumentError(message: "Connection string contains an unescaped @ symbol")
        }

        // do not omit empty subsequences to include an empty password
        let userInfo = userAndHost.count == 2 ?
            userAndHost[0].split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false) : nil
        if let userInfo = userInfo {
            var credential = MongoCredential()
            credential.username = try userInfo[0].getValidatedUserInfo(forKey: "username")
            if userInfo.count == 2 {
                credential.password = try userInfo[1].getValidatedUserInfo(forKey: "password")
            }
            // If no other authentication options or defaultAuthDB were provided, we should use "admin" as the
            // credential source. This will be overwritten later if a defaultAuthDB or an authSource is provided.
            credential.source = "admin"
            self.credential = credential
        }

        let hostString = userInfo != nil ? userAndHost[1] : userAndHost[0]
        let hosts = try hostString.components(separatedBy: ",").map(HostIdentifier.init)
        if case .srv = scheme {
            guard hosts.count == 1 else {
                throw MongoError.InvalidArgumentError(
                    message: "Only a single host identifier may be specified in a mongodb+srv connection string"
                )
            }
            guard hosts[0].port == nil else {
                throw MongoError.InvalidArgumentError(
                    message: "A port cannot be specified in a mongodb+srv connection string"
                )
            }
        }
        self.scheme = scheme
        self.hosts = hosts

        guard identifiersAndOptions.count == 2 else {
            // No auth DB or options were specified
            return
        }

        let authDatabaseAndOptions = identifiersAndOptions[1].components(separatedBy: "?")
        guard authDatabaseAndOptions.count <= 2 else {
            throw MongoError.InvalidArgumentError(message: "Connection string contains an unescaped question mark")
        }
        if !authDatabaseAndOptions[0].isEmpty {
            let decoded = try authDatabaseAndOptions[0].getPercentDecoded(forKey: "defaultAuthDB")
            for character in Self.forbiddenDBCharacters {
                if decoded.contains(character) {
                    throw MongoError.InvalidArgumentError(
                        message: "defaultAuthDB contains invalid character: \(character)"
                    )
                }
            }
            self.defaultAuthDB = decoded
            // If no other authentication options were provided, we should use the defaultAuthDB as the credential
            // source. This will be overwritten later if an authSource is provided.
            self.credential?.source = decoded
        }

        guard authDatabaseAndOptions.count == 2 else {
            // No options were specified
            return
        }

        let options = try Options(authDatabaseAndOptions[1])

        // Parse authentication options into a MongoCredential
        if let mechanism = options.authMechanism {
            var credential = self.credential ?? MongoCredential()
            credential.source = options.authSource ?? mechanism.getDefaultSource(defaultAuthDB: self.defaultAuthDB)
            credential.mechanismProperties = options.authMechanismProperties
            try mechanism.validateAndUpdateCredential(credential: &credential)
            credential.mechanism = mechanism
            self.credential = credential
        } else if options.authMechanismProperties != nil {
            throw MongoError.InvalidArgumentError(
                message: "Connection string specified authMechanismProperties but no authMechanism was specified"
            )
        } else if let authSource = options.authSource {
            // If no mechanism was provided but authentication was requested and an authSource was provided, populate
            // the source field with the authSource. Otherwise, source will fall back to the defaultAuthDB if provided,
            // or "admin" if not.
            if self.credential != nil {
                self.credential?.source = authSource
            } else {
                // The authentication mechanism defaults to SCRAM if an authMechanism is not provided, and SCRAM
                // requires a username
                throw MongoError.InvalidArgumentError(
                    message: "No username provided for authentication in the connection string but an authSource was"
                        + " provided. To use an authentication mechanism that does not require a username, specify an"
                        + " authMechanism in the connection string."
                )
            }
        }
    }

    /// `Codable` conformance
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        do {
            try self.init(throwsIfInvalid: stringValue)
        } catch let error as MongoError.InvalidArgumentError {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: error.message
            )
        }
    }

    /// `LosslessStringConvertible` protocol requirements
    public init?(_ description: String) {
        try? self.init(throwsIfInvalid: description)
    }

    // TODO: SWIFT-1405: add options to description
    public var description: String {
        var des = ""
        des += "\(self.scheme)://"
        des += self.hosts.map { $0.description }.joined(separator: ",")
        return des
    }

    /// Specifies the format this connection string is in.
    public var scheme: Scheme

    /// Specifies one or more host/ports to connect to.
    public var hosts: [HostIdentifier]

    /// The default database to use for authentication if an `authSource` is unspecified in the connection string.
    /// Defaults to "admin" if unspecified.
    public var defaultAuthDB: String?

    /// Specifies the authentication credentials.
    public var credential: MongoCredential?
}

extension StringProtocol {
    fileprivate func getPercentDecoded(forKey key: String) throws -> String {
        guard let decoded = self.removingPercentEncoding else {
            throw MongoError.InvalidArgumentError(
                message: "\(key) contains invalid percent encoding: \(self)"
            )
        }
        return decoded
    }

    fileprivate func getValidatedUserInfo(forKey key: String) throws -> String {
        for character in MongoConnectionString.forbiddenUserInfoCharacters {
            if self.contains(character) {
                throw MongoError.InvalidArgumentError(
                    message: "\(key) contains invalid character that must be percent-encoded: \(character)"
                )
            }
        }
        return try self.getPercentDecoded(forKey: key)
    }
}
