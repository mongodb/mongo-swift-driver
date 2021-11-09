import Foundation
import SwiftBSON

/// Represents a MongoDB connection string.
/// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
public struct MongoConnectionString: Codable, LosslessStringConvertible {
    private static let forbiddenDBCharacters = ["/", "\\", " ", "\"", "$"]
    /// Forbidden characters per RFC 3986.
    /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc3986#section-2.2
    fileprivate static let forbiddenUserInfoCharacters = [":", "/", "?", "#", "[", "]", "@"]

    private struct Names {
        fileprivate static let authSource = "authsource"
        fileprivate static let authMechanism = "authmechanism"
        fileprivate static let authMechanismProperties = "authmechanismproperties"
        fileprivate static let ssl = "ssl"
        fileprivate static let tls = "tls"
        fileprivate static let tlsAllowInvalidCertificates = "tlsallowinvalidcertificates"
        fileprivate static let tlsAllowInvalidHostnames = "tlsallowinvalidhostnames"
        fileprivate static let tlsCAFile = "tlscafile"
        fileprivate static let tlsCertificateKeyFile = "tlscertificatekeyfile"
        fileprivate static let tlsCertificateKeyFilePassword = "tlscertificatekeyfilepassword"
        fileprivate static let tlsDisableCertificateRevocationCheck = "tlsdisablecertificaterevocationcheck"
        fileprivate static let tlsDisableOCSPEndpointCheck = "tlsdisableocspendpointcheck"
        fileprivate static let tlsInsecure = "tlsinsecure"
    }

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
        // Authentication options
        fileprivate var authSource: String?
        fileprivate var authMechanism: MongoCredential.Mechanism?
        fileprivate var authMechanismProperties: BSONDocument?

        // TLS options
        fileprivate var ssl: Bool?
        fileprivate var tls: Bool?
        fileprivate var tlsAllowInvalidCertificates: Bool?
        fileprivate var tlsAllowInvalidHostnames: Bool?
        fileprivate var tlsCAFile: URL?
        fileprivate var tlsCertificateKeyFile: URL?
        fileprivate var tlsCertificateKeyFilePassword: String?
        fileprivate var tlsDisableCertificateRevocationCheck: Bool?
        fileprivate var tlsDisableOCSPEndpointCheck: Bool?
        fileprivate var tlsInsecure: Bool?

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
                case Names.authSource:
                    if value.isEmpty {
                        throw MongoError.InvalidArgumentError(
                            message: "Connection string \(Names.authSource) option must not be empty"
                        )
                    }
                    self.authSource = value
                case Names.authMechanism:
                    self.authMechanism = try MongoCredential.Mechanism(value)
                case Names.authMechanismProperties:
                    self.authMechanismProperties = try self.parseAuthMechanismProperties(properties: value)
                case Names.ssl:
                    self.ssl = try value.getBool(forKey: Names.ssl)
                case Names.tls:
                    self.tls = try value.getBool(forKey: Names.tls)
                case Names.tlsAllowInvalidCertificates:
                    self.tlsAllowInvalidCertificates = try value.getBool(forKey: Names.tlsAllowInvalidCertificates)
                case Names.tlsAllowInvalidHostnames:
                    self.tlsAllowInvalidHostnames = try value.getBool(forKey: Names.tlsAllowInvalidHostnames)
                case Names.tlsCAFile:
                    self.tlsCAFile = URL(string: value)
                case Names.tlsCertificateKeyFile:
                    self.tlsCertificateKeyFile = URL(string: value)
                case Names.tlsCertificateKeyFilePassword:
                    self.tlsCertificateKeyFilePassword = value
                case Names.tlsDisableCertificateRevocationCheck:
                    self.tlsDisableCertificateRevocationCheck =
                        try value.getBool(forKey: Names.tlsDisableCertificateRevocationCheck)
                case Names.tlsDisableOCSPEndpointCheck:
                    self.tlsDisableOCSPEndpointCheck = try value.getBool(forKey: Names.tlsDisableOCSPEndpointCheck)
                case Names.tlsInsecure:
                    self.tlsInsecure = try value.getBool(forKey: Names.tlsInsecure)
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
                    propertiesDoc[kv[0]] = .bool(try kv[1].getBool(forKey: "CANONICALIZE_HOST_NAME"))
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
        try self.validateAndUpdateCredential(options: options)

        // Validate and set TLS options
        try self.validateAndSetTLSOptions(options: options)
    }

    private mutating func validateAndUpdateCredential(options: Options) throws {
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

    private mutating func validateAndSetTLSOptions(options: Options) throws {
        guard options.tlsInsecure == nil
            || (options.tlsAllowInvalidCertificates == nil
                && options.tlsAllowInvalidHostnames == nil
                && options.tlsDisableCertificateRevocationCheck == nil
                && options.tlsDisableOCSPEndpointCheck == nil)
        else {
            throw MongoError.InvalidArgumentError(
                message: "tlsAllowInvalidCertificates, tlsAllowInvalidHostnames, tlsDisableCertificateRevocationCheck,"
                    + " and tlsDisableOCSPEndpointCheck cannot be specified if tlsInsecure is specified in the"
                    + " connection string"
            )
        }
        guard !(options.tlsAllowInvalidCertificates != nil && options.tlsDisableOCSPEndpointCheck != nil) else {
            throw MongoError.InvalidArgumentError(
                message: "tlsAllowInvalidCertificates and tlsDisableOCSPEndpointCheck cannot both be specified in the"
                    + " connection string"
            )
        }
        guard !(options.tlsAllowInvalidCertificates != nil && options.tlsDisableCertificateRevocationCheck != nil)
        else {
            throw MongoError.InvalidArgumentError(
                message: "tlsAllowInvalidCertificates and tlsDisableCertificateRevocationCheck cannot both be"
                    + " specified in the connection string"
            )
        }
        guard !(options.tlsDisableOCSPEndpointCheck != nil
            && options.tlsDisableCertificateRevocationCheck != nil)
        else {
            throw MongoError.InvalidArgumentError(
                message: "tlsDisableOCSPEndpointCheck and tlsDisableCertificateRevocationCheck cannot both be"
                    + " specified in the connection string"
            )
        }
        if let tls = options.tls, let ssl = options.ssl, tls != ssl {
            throw MongoError.InvalidArgumentError(
                message: "tls and ssl must have the same value if both are specified in the connection string"
            )
        }
        // if either tls or ssl is specified, the value should be stored in the tls field
        self.tls = options.tls ?? options.ssl
        self.tlsAllowInvalidCertificates = options.tlsAllowInvalidCertificates
        self.tlsAllowInvalidHostnames = options.tlsAllowInvalidHostnames
        self.tlsCAFile = options.tlsCAFile
        self.tlsCertificateKeyFile = options.tlsCertificateKeyFile
        self.tlsCertificateKeyFilePassword = options.tlsCertificateKeyFilePassword
        self.tlsDisableCertificateRevocationCheck = options.tlsDisableCertificateRevocationCheck
        self.tlsDisableOCSPEndpointCheck = options.tlsDisableOCSPEndpointCheck
        self.tlsInsecure = options.tlsInsecure
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

    /// Returns a document containing all of the options provided after the ? of the URI.
    internal var options: BSONDocument {
        var options = BSONDocument()

        if let source = self.credential?.source {
            options[Names.authSource] = .string(source)
        }
        if let mechanism = self.credential?.mechanism {
            options[Names.authMechanism] = .string(mechanism.description)
        }
        if let properties = self.credential?.mechanismProperties {
            options[Names.authMechanismProperties.lowercased()] = .document(properties)
        }
        if let tls = self.tls {
            options[Names.tls] = .bool(tls)
        }
        if let tlsAllowInvalidCertificates = self.tlsAllowInvalidCertificates {
            options[Names.tlsAllowInvalidCertificates] = .bool(tlsAllowInvalidCertificates)
        }
        if let tlsAllowInvalidHostnames = self.tlsAllowInvalidHostnames {
            options[Names.tlsAllowInvalidHostnames] = .bool(tlsAllowInvalidHostnames)
        }
        if let tlsCAFile = self.tlsCAFile {
            options[Names.tlsCAFile] = .string(tlsCAFile.description)
        }
        if let tlsCertificateKeyFile = self.tlsCertificateKeyFile {
            options[Names.tlsCertificateKeyFile] = .string(tlsCertificateKeyFile.description)
        }
        if let tlsCertificateKeyFilePassword = self.tlsCertificateKeyFilePassword {
            options[Names.tlsCertificateKeyFilePassword] = .string(tlsCertificateKeyFilePassword)
        }
        if let tlsDisableCertificateRevocationCheck = self.tlsDisableCertificateRevocationCheck {
            options[Names.tlsDisableCertificateRevocationCheck] = .bool(tlsDisableCertificateRevocationCheck)
        }
        if let tlsDisableOCSPEndpointCheck = self.tlsDisableOCSPEndpointCheck {
            options[Names.tlsDisableOCSPEndpointCheck] = .bool(tlsDisableOCSPEndpointCheck)
        }
        if let tlsInsecure = self.tlsInsecure {
            options[Names.tlsInsecure] = .bool(tlsInsecure)
        }

        return options
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

    /// Specifies whether or not to require TLS for connections to the server. By default this is set to false.
    ///
    /// - Note: Specifying any other "tls"-prefixed option will require TLS for connections to the server.
    public var tls: Bool?

    /// Specifies whether to bypass validation of the certificate presented by the mongod/mongos instance. By default
    /// this is set to false.
    public var tlsAllowInvalidCertificates: Bool?

    /// Specifies whether to disable hostname validation for the certificate presented by the mongod/mongos instance.
    /// By default this is set to false.
    public var tlsAllowInvalidHostnames: Bool?

    /// Specifies the location of a local .pem file that contains the root certificate chain from the Certificate
    /// Authority. This file is used to validate the certificate presented by the mongod/mongos instance.
    public var tlsCAFile: URL?

    /// Specifies the location of a local .pem file that contains either the client's TLS certificate or the client's
    /// TLS certificate and key. The client presents this file to the mongod/mongos instance.
    public var tlsCertificateKeyFile: URL?

    /// Specifies the password to de-crypt the `tlsCertificateKeyFile`.
    public var tlsCertificateKeyFilePassword: String?

    /// Specifies whether revocation checking (CRL / OCSP) should be disabled.
    /// On macOS, this setting has no effect.
    /// By default this is set to false.
    /// It is an error to specify both this option and `tlsDisableOCSPEndpointCheck`.
    public var tlsDisableCertificateRevocationCheck: Bool?

    /// Indicates if OCSP responder endpoints should not be requested when an OCSP response is not stapled.
    /// On macOS, this setting has no effect.
    /// By default this is set to false.
    public var tlsDisableOCSPEndpointCheck: Bool?

    /// When specified, TLS constraints will be relaxed as much as possible. Currently, setting this option to `true`
    /// is equivalent to setting `tlsAllowInvalidCertificates`, `tlsAllowInvalidHostnames`, and
    /// `tlsDisableCertificateRevocationCheck` to `true`.
    /// It is an error to specify both this option and any of the options enabled by it.
    public var tlsInsecure: Bool?
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

    fileprivate func getBool(forKey key: String) throws -> Bool {
        switch self {
        case "true":
            return true
        case "false":
            return false
        default:
            throw MongoError.InvalidArgumentError(
                message: "Value for \(key) in connection string must be true or false"
            )
        }
    }
}
