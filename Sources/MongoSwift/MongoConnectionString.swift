import CLibMongoC
import Foundation
import SwiftBSON

/// Represents a MongoDB connection string.
/// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
public struct MongoConnectionString: Codable, LosslessStringConvertible {
    /// Characters that must not be present in a database name.
    private static let forbiddenDBCharacters = ["/", "\\", " ", "\"", "$"]

    /// General delimiters as defined by RFC 3986. These characters must be percent-encoded when present in the hosts,
    /// default authentication database, and user info.
    /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc3986#section-2.2
    fileprivate static let genDelims = ":/?#[]@"

    /// Characters that do not need to be percent-encoded when reconstructing the hosts, default authentication
    /// database, and user info.
    fileprivate static let allowedForNonOptionEncoding = CharacterSet(charactersIn: genDelims).inverted

    /// Characters that do not need to be percent-encoded when reconstructing URI options.
    fileprivate static let allowedForOptionEncoding = CharacterSet(charactersIn: "=&,:").inverted

    fileprivate enum OptionName: String {
        case appName = "appname"
        case authSource = "authsource"
        case authMechanism = "authmechanism"
        case authMechanismProperties = "authmechanismproperties"
        case compressors
        case connectTimeoutMS = "connecttimeoutms"
        case directConnection = "directconnection"
        case heartbeatFrequencyMS = "heartbeatfrequencyms"
        case journal
        case loadBalanced = "loadbalanced"
        case localThresholdMS = "localthresholdms"
        case maxPoolSize = "maxpoolsize"
        case maxStalenessSeconds = "maxstalenessseconds"
        case readConcernLevel = "readconcernlevel"
        case readPreference = "readpreference"
        case readPreferenceTags = "readpreferencetags"
        case replicaSet = "replicaset"
        case retryReads = "retryreads"
        case retryWrites = "retrywrites"
        case serverSelectionTimeoutMS = "serverselectiontimeoutms"
        case socketTimeoutMS = "sockettimeoutms"
        case srvMaxHosts = "srvmaxhosts"
        case srvServiceName = "srvservicename"
        case ssl
        case tls
        case tlsAllowInvalidCertificates = "tlsallowinvalidcertificates"
        case tlsAllowInvalidHostnames = "tlsallowinvalidhostnames"
        case tlsCAFile = "tlscafile"
        case tlsCertificateKeyFile = "tlscertificatekeyfile"
        case tlsCertificateKeyFilePassword = "tlscertificatekeyfilepassword"
        case tlsDisableCertificateRevocationCheck = "tlsdisablecertificaterevocationcheck"
        case tlsDisableOCSPEndpointCheck = "tlsdisableocspendpointcheck"
        case tlsInsecure = "tlsinsecure"
        case w
        case wTimeoutMS = "wtimeoutms"
        case zlibCompressionLevel = "zlibcompressionlevel"
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

        internal enum HostType: String {
            case ipv4
            case ipLiteral = "ip_literal"
            case hostname
            case unixDomainSocket
        }

        /// The hostname or IP address.
        public let host: String

        /// The port number.
        public let port: UInt16?

        internal let type: HostType

        /// Initializes a ServerAddress, using the default localhost:27017 if a host/port is not provided.
        internal init(_ hostAndPort: String = "localhost:27017") throws {
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
                guard parts.count <= 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "expected only a single port delimiter ':' in \(hostAndPort)"
                    )
                }

                let host = parts[0]
                if host.hasSuffix(".sock") {
                    self.host = try host.getPercentDecoded(forKey: "UNIX domain socket")
                    self.type = .unixDomainSocket
                } else if host.isIPv4() {
                    self.host = host
                    self.type = .ipv4
                } else {
                    self.host = try host.getPercentDecoded(forKey: "hostname")
                    self.type = .hostname
                }

                if parts.count > 1 {
                    self.port = try HostIdentifier.parsePort(from: parts[1])
                } else {
                    self.port = nil
                }
            }
        }

        public var description: String {
            var hostDescription = ""
            switch self.type {
            case .ipLiteral:
                hostDescription += "[\(self.host)]"
            case .ipv4:
                hostDescription += self.host
            case .unixDomainSocket, .hostname:
                hostDescription += self.host.getPercentEncoded(
                    withAllowedCharacters: MongoConnectionString.allowedForNonOptionEncoding
                )
            }
            if let port = self.port {
                hostDescription += ":\(port)"
            }
            return hostDescription
        }
    }

    private struct Options {
        fileprivate var appName: String?
        fileprivate var authSource: String?
        fileprivate var authMechanism: MongoCredential.Mechanism?
        fileprivate var authMechanismProperties: BSONDocument?
        fileprivate var compressors: [String]?
        fileprivate var connectTimeoutMS: Int?
        fileprivate var directConnection: Bool?
        fileprivate var heartbeatFrequencyMS: Int?
        fileprivate var journal: Bool?
        fileprivate var loadBalanced: Bool?
        fileprivate var localThresholdMS: Int?
        fileprivate var maxPoolSize: Int?
        fileprivate var maxStalenessSeconds: Int?
        fileprivate var readConcern: ReadConcern?
        fileprivate var readPreference: String?
        fileprivate var readPreferenceTags: [BSONDocument]?
        fileprivate var replicaSet: String?
        fileprivate var retryReads: Bool?
        fileprivate var retryWrites: Bool?
        fileprivate var serverSelectionTimeoutMS: Int?
        fileprivate var socketTimeoutMS: Int?
        fileprivate var srvMaxHosts: Int?
        fileprivate var srvServiceName: String?
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
        fileprivate var w: WriteConcern.W?
        fileprivate var wTimeoutMS: Int?
        fileprivate var zlibCompressionLevel: Int?

        fileprivate init(_ uriOptions: Substring) throws {
            let options = uriOptions.components(separatedBy: "&")
            // tracks options that have already been set to error on duplicates
            var setOptions: Set<String> = []
            for option in options {
                let nameAndValue = option.components(separatedBy: "=")
                guard nameAndValue.count == 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "Option name and value must be of the form <name>=<value> not containing unescaped"
                            + " equals signs"
                    )
                }
                guard let name = OptionName(rawValue: nameAndValue[0].lowercased()) else {
                    throw MongoError.InvalidArgumentError(
                        message: "Connection string contains unsupported option: \(nameAndValue[0])"
                    )
                }
                // read preference tags can be specified multiple times
                guard setOptions.insert(name.rawValue).inserted || name == .readPreferenceTags else {
                    throw MongoError.InvalidArgumentError(
                        message: "Connection string contains duplicate option: \(name)"
                    )
                }
                let value = try nameAndValue[1].getPercentDecoded(forKey: name.rawValue)
                switch name {
                case .appName:
                    self.appName = value
                case .authSource:
                    self.authSource = value
                case .authMechanism:
                    self.authMechanism = try MongoCredential.Mechanism(value)
                case .authMechanismProperties:
                    self.authMechanismProperties = try Self.parseAuthMechanismProperties(properties: value)
                case .compressors:
                    self.compressors = value.components(separatedBy: ",")
                case .connectTimeoutMS:
                    self.connectTimeoutMS = try value.getInt(forKey: name.rawValue)
                case .directConnection:
                    self.directConnection = try value.getBool(forKey: name.rawValue)
                case .heartbeatFrequencyMS:
                    self.heartbeatFrequencyMS = try value.getInt(forKey: name.rawValue)
                case .journal:
                    self.journal = try value.getBool(forKey: name.rawValue)
                case .loadBalanced:
                    self.loadBalanced = try value.getBool(forKey: name.rawValue)
                case .localThresholdMS:
                    self.localThresholdMS = try value.getInt(forKey: name.rawValue)
                case .maxPoolSize:
                    self.maxPoolSize = try value.getInt(forKey: name.rawValue)
                case .maxStalenessSeconds:
                    self.maxStalenessSeconds = try value.getInt(forKey: name.rawValue)
                case .readConcernLevel:
                    self.readConcern = ReadConcern(value)
                case .readPreference:
                    self.readPreference = value
                case .readPreferenceTags:
                    let tags = try Self.parseReadPreferenceTags(tags: value)
                    if self.readPreferenceTags == nil {
                        self.readPreferenceTags = []
                    }
                    self.readPreferenceTags?.append(tags)
                case .replicaSet:
                    self.replicaSet = value
                case .retryReads:
                    self.retryReads = try value.getBool(forKey: name.rawValue)
                case .retryWrites:
                    self.retryWrites = try value.getBool(forKey: name.rawValue)
                case .serverSelectionTimeoutMS:
                    self.serverSelectionTimeoutMS = try value.getInt(forKey: name.rawValue)
                case .socketTimeoutMS:
                    self.socketTimeoutMS = try value.getInt(forKey: name.rawValue)
                case .srvMaxHosts:
                    self.srvMaxHosts = try value.getInt(forKey: name.rawValue)
                case .srvServiceName:
                    self.srvServiceName = value
                case .ssl:
                    self.ssl = try value.getBool(forKey: name.rawValue)
                case .tls:
                    self.tls = try value.getBool(forKey: name.rawValue)
                case .tlsAllowInvalidCertificates:
                    self.tlsAllowInvalidCertificates = try value.getBool(forKey: name.rawValue)
                case .tlsAllowInvalidHostnames:
                    self.tlsAllowInvalidHostnames = try value.getBool(forKey: name.rawValue)
                case .tlsCAFile:
                    self.tlsCAFile = URL(string: value)
                case .tlsCertificateKeyFile:
                    self.tlsCertificateKeyFile = URL(string: value)
                case .tlsCertificateKeyFilePassword:
                    self.tlsCertificateKeyFilePassword = value
                case .tlsDisableCertificateRevocationCheck:
                    self.tlsDisableCertificateRevocationCheck = try value.getBool(forKey: name.rawValue)
                case .tlsDisableOCSPEndpointCheck:
                    self.tlsDisableOCSPEndpointCheck = try value.getBool(forKey: name.rawValue)
                case .tlsInsecure:
                    self.tlsInsecure = try value.getBool(forKey: name.rawValue)
                case .w:
                    self.w = try WriteConcern.W(value)
                case .wTimeoutMS:
                    self.wTimeoutMS = try value.getInt(forKey: name.rawValue)
                case .zlibCompressionLevel:
                    self.zlibCompressionLevel = try value.getInt(forKey: name.rawValue)
                }
            }
        }

        private static func parseAuthMechanismProperties(properties: String) throws -> BSONDocument {
            enum PropertyName: String {
                case serviceName = "service_name"
                case serviceRealm = "service_realm"
                case canonicalizeHostName = "canonicalize_host_name"
            }

            var propertiesDoc = BSONDocument()
            for property in properties.components(separatedBy: ",") {
                let kv = property.components(separatedBy: ":")
                guard kv.count == 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "\(OptionName.authMechanismProperties) must be a comma-separated list of"
                            + " colon-separated key-value pairs"
                    )
                }
                guard let name = PropertyName(rawValue: kv[0].lowercased()) else {
                    throw MongoError.InvalidArgumentError(
                        message: "Unknown key for \(OptionName.authMechanismProperties): \(kv[0])"
                    )
                }
                switch name {
                case .serviceName, .serviceRealm:
                    propertiesDoc[kv[0]] = .string(kv[1])
                case .canonicalizeHostName:
                    propertiesDoc[kv[0]] = .bool(try kv[1].getBool(forKey: name.rawValue))
                }
            }
            return propertiesDoc
        }

        private static func parseReadPreferenceTags(tags: String) throws -> BSONDocument {
            var tagsDoc = BSONDocument()
            for tag in tags.components(separatedBy: ",") {
                let kv = tag.components(separatedBy: ":")
                guard kv.count == 2 else {
                    throw MongoError.InvalidArgumentError(
                        message: "\(OptionName.readPreferenceTags) must be a comma-separated list of colon-separated"
                            + " key-value pairs"
                    )
                }
                tagsDoc[kv[0]] = .string(kv[1])
            }
            return tagsDoc
        }
    }

    /// Parses a new `MongoConnectionString` instance from the provided string.
    /// - Throws:
    ///   - `MongoError.InvalidArgumentError` if the input is invalid.
    public init(string input: String) throws {
        // Parse the connection string's scheme.
        let schemeAndRest = input.components(separatedBy: "://")
        guard schemeAndRest.count == 2, let scheme = Scheme(schemeAndRest[0]) else {
            throw MongoError.InvalidArgumentError(
                message: "Invalid connection string scheme, expecting \'mongodb\' or \'mongodb+srv\'"
            )
        }
        guard !schemeAndRest[1].isEmpty else {
            throw MongoError.InvalidArgumentError(message: "The connection string must contain host information")
        }

        // Split the rest of the connection string into its components.
        let infoAndOptions = schemeAndRest[1].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        if infoAndOptions[0].isEmpty {
            throw MongoError.InvalidArgumentError(message: "The connection string must contain host information")
        }
        let userHostsAndAuthDB = infoAndOptions[0].split(separator: "/", omittingEmptySubsequences: false)
        if userHostsAndAuthDB.count > 2 {
            throw MongoError.InvalidArgumentError(
                message: "The user information, host information, and defaultAuthDB in the connection string must not"
                    + " contain unescaped slashes"
            )
        } else if userHostsAndAuthDB.count == 1 && infoAndOptions.count == 2 {
            throw MongoError.InvalidArgumentError(
                message: "The connection string must contain a delimiting slash between the host information and"
                    + " options"
            )
        }
        let userInfoAndHosts = userHostsAndAuthDB[0].split(separator: "@", omittingEmptySubsequences: false)
        if userInfoAndHosts.count > 2 {
            throw MongoError.InvalidArgumentError(
                message: "The user information and host information in the connection string must not contain"
                    + " unescaped @ symbols"
            )
        }

        // Parse user information if present and set the hosts string.
        let hostsString: Substring
        if userInfoAndHosts.count == 2 {
            let userInfo = userInfoAndHosts[0].split(separator: ":", omittingEmptySubsequences: false)
            if userInfo.count > 2 {
                throw MongoError.InvalidArgumentError(
                    message: "Username and password in the connection string must not contain unescaped colons"
                )
            }
            var credential = MongoCredential()
            credential.username = try userInfo[0].getValidatedUserInfo(forKey: "username")
            if userInfo.count == 2 {
                credential.password = try userInfo[1].getValidatedUserInfo(forKey: "password")
            }
            // If no other authentication options or defaultAuthDB were provided, we should use "admin" as the
            // credential source. This will be overwritten later if a defaultAuthDB or an authSource is provided.
            credential.source = "admin"
            // Overwrite the sourceFromAuthSource field to false as the source is a default.
            credential.sourceFromAuthSource = false
            self.credential = credential
            hostsString = userInfoAndHosts[1]
        } else {
            hostsString = userInfoAndHosts[0]
        }

        // Parse host information.
        let hosts = try hostsString.components(separatedBy: ",").map(HostIdentifier.init)
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
            guard hosts[0].host.filter({ $0 == "." }).count >= 2 else {
                throw MongoError.InvalidArgumentError(
                    message: "The host specified in a mongodb+srv connection string must contain a host name, a domain"
                        + " name, and a top-level domain"
                )
            }
        }
        self.scheme = scheme
        self.hosts = hosts

        // Parse the defaultAuthDB if present.
        if userHostsAndAuthDB.count == 2 && !userHostsAndAuthDB[1].isEmpty {
            let defaultAuthDB = try userHostsAndAuthDB[1].getPercentDecoded(forKey: "defaultAuthDB")
            for character in Self.forbiddenDBCharacters {
                if defaultAuthDB.contains(character) {
                    throw MongoError.InvalidArgumentError(
                        message: "defaultAuthDB contains invalid character: \(character)"
                    )
                }
            }
            self.defaultAuthDB = defaultAuthDB
            // If no other authentication options were provided, we should use the defaultAuthDB as the credential
            // source. This will be overwritten later if an authSource is provided.
            if self.credential == nil {
                self.credential = MongoCredential()
            }
            self.credential?.source = defaultAuthDB
            // Overwrite the sourceFromAuthSource field to false as the source is a default.
            self.credential?.sourceFromAuthSource = false
        }

        // Return early if no options were specified.
        guard infoAndOptions.count == 2 else {
            try self.validate()
            return
        }

        let options = try Options(infoAndOptions[1])

        // Validate and set compressors. This validation is only necessary for compressors provided in the URI string
        // and therefore is not included in the general validate method.
        try self.validateAndSetCompressors(options)

        // Parse authentication options into a MongoCredential.
        var credential = self.credential ?? MongoCredential()
        credential.mechanism = options.authMechanism
        credential.mechanismProperties = options.authMechanismProperties
        credential.source = options.authSource
        self.credential = credential != MongoCredential() ? credential : nil

        // Validate and set the read preference. This validation is only necessary for a read preference provided in
        // the URI string and therefore is not included in the general validate method.
        try self.validateAndSetReadPreference(options)

        // Validate and set the write concern. This validation is only necessary for a write concern provided in the
        // URI string and therefore is not included in the general validate method.
        try self.validateAndSetWriteConcern(options)

        // ssl can only be provided in a URI string, so this validation is not included in the general validate method.
        if let tls = options.tls, let ssl = options.ssl, tls != ssl {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tls) and \(OptionName.ssl) must have the same value if both are specified in"
                    + " the connection string"
            )
        }
        // If either tls or ssl is specified, the value should be stored in the tls field.
        self.tls = options.tls ?? options.ssl

        // Set rest of options.
        self.appName = options.appName
        self.connectTimeoutMS = options.connectTimeoutMS
        self.directConnection = options.directConnection
        self.heartbeatFrequencyMS = options.heartbeatFrequencyMS
        self.loadBalanced = options.loadBalanced
        self.localThresholdMS = options.localThresholdMS
        self.maxPoolSize = options.maxPoolSize
        self.readConcern = options.readConcern
        self.replicaSet = options.replicaSet
        self.retryReads = options.retryReads
        self.retryWrites = options.retryWrites
        self.serverSelectionTimeoutMS = options.serverSelectionTimeoutMS
        self.socketTimeoutMS = options.socketTimeoutMS
        self.srvMaxHosts = options.srvMaxHosts
        self.srvServiceName = options.srvServiceName
        self.tlsAllowInvalidCertificates = options.tlsAllowInvalidCertificates
        self.tlsAllowInvalidHostnames = options.tlsAllowInvalidHostnames
        self.tlsCAFile = options.tlsCAFile
        self.tlsCertificateKeyFile = options.tlsCertificateKeyFile
        self.tlsCertificateKeyFilePassword = options.tlsCertificateKeyFilePassword
        self.tlsDisableCertificateRevocationCheck = options.tlsDisableCertificateRevocationCheck
        self.tlsDisableOCSPEndpointCheck = options.tlsDisableOCSPEndpointCheck
        self.tlsInsecure = options.tlsInsecure

        try self.validate()
    }

    /// Updates this `MongoConnectionString` to incorporate options specified in the provided `MongoClientOptions`. If
    /// the same option is specified in both, the option in the `MongoClientOptions` takes precedence.
    /// - Throws:
    ///     - `MongoError.InvalidArgumentError` if the provided `MongoClientOptions` contains any invalid options, or
    ///       applying the options leads to an invalid combination of options.
    public mutating func applyOptions(_ options: MongoClientOptions) throws {
        if let appName = options.appName {
            self.appName = appName
        }
        if let compressors = options.compressors {
            self.compressors = compressors
        }
        if let connectTimeoutMS = options.connectTimeoutMS {
            self.connectTimeoutMS = connectTimeoutMS
        }
        if let credential = options.credential {
            self.credential = credential
        }
        if let directConnection = options.directConnection {
            self.directConnection = directConnection
        }
        if let heartbeatFrequencyMS = options.heartbeatFrequencyMS {
            self.heartbeatFrequencyMS = heartbeatFrequencyMS
        }
        if let loadBalanced = options.loadBalanced {
            self.loadBalanced = loadBalanced
        }
        if let localThresholdMS = options.localThresholdMS {
            self.localThresholdMS = localThresholdMS
        }
        if let maxPoolSize = options.maxPoolSize {
            self.maxPoolSize = maxPoolSize
        }
        if let minHeartbeatFrequencyMS = options.minHeartbeatFrequencyMS {
            self.minHeartbeatFrequencyMS = minHeartbeatFrequencyMS
        }
        if let readConcern = options.readConcern {
            self.readConcern = readConcern
        }
        if let readPreference = options.readPreference {
            self.readPreference = readPreference
        }
        if let replicaSet = options.replicaSet {
            self.replicaSet = replicaSet
        }
        if let retryReads = options.retryReads {
            self.retryReads = retryReads
        }
        if let retryWrites = options.retryWrites {
            self.retryWrites = retryWrites
        }
        if let serverSelectionTimeoutMS = options.serverSelectionTimeoutMS {
            self.serverSelectionTimeoutMS = serverSelectionTimeoutMS
        }
        if let tls = options.tls {
            self.tls = tls
        }
        if let tlsAllowInvalidCertificates = options.tlsAllowInvalidCertificates {
            self.tlsAllowInvalidCertificates = tlsAllowInvalidCertificates
        }
        if let tlsAllowInvalidHostnames = options.tlsAllowInvalidHostnames {
            self.tlsAllowInvalidHostnames = tlsAllowInvalidHostnames
        }
        if let tlsCAFile = options.tlsCAFile {
            self.tlsCAFile = tlsCAFile
        }
        if let tlsCertificateKeyFile = options.tlsCertificateKeyFile {
            self.tlsCertificateKeyFile = tlsCertificateKeyFile
        }
        if let tlsCertificateKeyFilePassword = options.tlsCertificateKeyFilePassword {
            self.tlsCertificateKeyFilePassword = tlsCertificateKeyFilePassword
        }
        if let tlsDisableCertificateRevocationCheck = options.tlsDisableCertificateRevocationCheck {
            self.tlsDisableCertificateRevocationCheck = tlsDisableCertificateRevocationCheck
        }
        if let tlsDisableOCSPEndpointCheck = options.tlsDisableOCSPEndpointCheck {
            self.tlsDisableOCSPEndpointCheck = tlsDisableOCSPEndpointCheck
        }
        if let tlsInsecure = options.tlsInsecure {
            self.tlsInsecure = tlsInsecure
        }
        if let writeConcern = options.writeConcern {
            self.writeConcern = writeConcern
        }

        try self.validate()
    }

    internal mutating func validate() throws {
        func optionError(name: OptionName, violation: String) -> MongoError.InvalidArgumentError {
            MongoError.InvalidArgumentError(
                message: "Value for \(name) in the connection string must " + violation
            )
        }

        // Validate option values.
        if let source = self.credential?.source, source.isEmpty {
            throw optionError(name: .authSource, violation: "not be empty")
        }
        if let connectTimeoutMS = self.connectTimeoutMS {
            if connectTimeoutMS <= 0 {
                throw optionError(name: .connectTimeoutMS, violation: "be positive")
            }
            if connectTimeoutMS > Int32.max {
                throw optionError(
                    name: .connectTimeoutMS,
                    violation: "be <= \(Int32.max) (maximum 32-bit integer value)"
                )
            }
        }
        if let heartbeatFrequencyMS = self.heartbeatFrequencyMS {
            if heartbeatFrequencyMS < self.minHeartbeatFrequencyMS {
                throw optionError(name: .heartbeatFrequencyMS, violation: "be >= \(self.minHeartbeatFrequencyMS)")
            }
            if heartbeatFrequencyMS > Int32.max {
                throw optionError(
                    name: .heartbeatFrequencyMS,
                    violation: "be <= \(Int32.max) (maximum 32-bit integer value)"
                )
            }
        }
        if let localThresholdMS = self.localThresholdMS {
            if localThresholdMS < 0 {
                throw optionError(name: .localThresholdMS, violation: "be nonnegative")
            }
            if localThresholdMS > Int32.max {
                throw optionError(
                    name: .localThresholdMS,
                    violation: "be <= \(Int32.max) (maximum 32-bit integer value)"
                )
            }
        }
        if let maxPoolSize = self.maxPoolSize {
            if maxPoolSize <= 0 {
                throw optionError(name: .maxPoolSize, violation: "be positive")
            }
            if maxPoolSize > Int32.max {
                throw optionError(name: .maxPoolSize, violation: "be <= \(Int32.max) (maximum 32-bit integer value)")
            }
        }
        if let maxStalenessSeconds = self.readPreference?.maxStalenessSeconds,
           !(maxStalenessSeconds == -1 || maxStalenessSeconds >= 90)
        {
            throw optionError(name: .maxStalenessSeconds, violation: "be -1 (for no max staleness check) or >= 90")
        }
        if let serverSelectionTimeoutMS = self.serverSelectionTimeoutMS {
            if serverSelectionTimeoutMS <= 0 {
                throw optionError(name: .serverSelectionTimeoutMS, violation: "be positive")
            }
            if serverSelectionTimeoutMS > Int32.max {
                throw optionError(
                    name: .serverSelectionTimeoutMS,
                    violation: "be <= \(Int32.max) (maximum 32-bit integer value)"
                )
            }
        }
        if let socketTimeoutMS = self.socketTimeoutMS, socketTimeoutMS < 0 {
            throw optionError(name: .socketTimeoutMS, violation: "be nonnegative")
        }
        if let srvMaxHosts = self.srvMaxHosts, srvMaxHosts < 0 {
            throw optionError(name: .srvMaxHosts, violation: "be nonnegative")
        }
        if let srvServiceName = self.srvServiceName {
            try srvServiceName.validateSRVServiceName()
        }
        if let wTimeoutMS = self.writeConcern?.wtimeoutMS, wTimeoutMS < 0 {
            throw optionError(name: .wTimeoutMS, violation: "be nonnegative")
        }

        // Validate the compressors do not contain any duplicates. Currently this is equivalent to checking that the
        // size of the compressors list does not exceed one as we only support one compressor.
        if let compressors = self.compressors, compressors.count > 1 {
            throw MongoError.InvalidArgumentError(
                message: "The \(OptionName.compressors) list in the connection string must not contain duplicates"
            )
        }

        // Validate the credential and set defaults as necessary.
        if self.credential != nil {
            // If no source was specified, fall back to:
            // 1) the mechanism's default if one was provided
            // 2) the defaultAuthDB if one was provided
            // 3) "admin"
            if self.credential?.source == nil {
                let defaultSource = self.credential?.mechanism?.getDefaultSource(defaultAuthDB: self.defaultAuthDB)
                    ?? self.defaultAuthDB
                    ?? "admin"
                self.credential?.source = defaultSource
                // Overwrite the sourceFromAuthSource field to false as the source is a default.
                self.credential?.sourceFromAuthSource = false
            }
            if self.credential?.mechanism != nil {
                // credential cannot be nil within the external conditional
                // swiftlint:disable:next force_unwrapping
                try self.credential?.mechanism?.validateAndUpdateCredential(credential: &self.credential!)
            } else if self.credential?.mechanismProperties != nil {
                throw MongoError.InvalidArgumentError(
                    message: "Connection string specified \(OptionName.authMechanismProperties) but no"
                        + " \(OptionName.authMechanism) was specified"
                )
            }
        }

        // Validate that directConnection is not set with incompatible options.
        if self.directConnection == true {
            guard self.scheme != .srv else {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.directConnection) cannot be set to true if the connection string scheme is"
                        + " SRV"
                )
            }
            guard self.hosts.count == 1 else {
                throw MongoError.InvalidArgumentError(
                    message: "Multiple hosts cannot be specified in the connection string if"
                        + " \(OptionName.directConnection) is set to true"
                )
            }
        }

        // Validate that loadBalanced is not set with incompatible options.
        if self.loadBalanced == true {
            if self.hosts.count > 1 {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.loadBalanced) cannot be set to true if multiple hosts are specified in the"
                        + " connection string"
                )
            }
            if self.replicaSet != nil {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.loadBalanced) cannot be set to true if \(OptionName.replicaSet) is"
                        + " specified in the connection string"
                )
            }
            if self.directConnection == true {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.loadBalanced) and \(OptionName.directConnection) cannot both be set to true"
                        + " in the connection string"
                )
            }
        }

        // Validate that SRV options are not set with incompatible options.
        guard self.scheme == .srv || (self.srvMaxHosts == nil && self.srvServiceName == nil) else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.srvMaxHosts) and \(OptionName.srvServiceName) must not be specified if the"
                    + " connection string scheme is not SRV"
            )
        }
        if let srvMaxHosts = self.srvMaxHosts {
            guard !(srvMaxHosts > 0 && self.replicaSet != nil) else {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.replicaSet) must not be specified in the connection string if the value for"
                        + " \(OptionName.srvMaxHosts) is greater than zero"
                )
            }
            guard !(srvMaxHosts > 0 && self.loadBalanced == true) else {
                throw MongoError.InvalidArgumentError(
                    message: "The value for \(OptionName.loadBalanced) in the connection string must not be true if"
                        + " the value for \(OptionName.srvMaxHosts) is greater than zero"
                )
            }
        }

        // Validate that TLS options are not set with incompatible options.
        guard self.tlsInsecure == nil
            || (self.tlsAllowInvalidCertificates == nil
                && self.tlsAllowInvalidHostnames == nil
                && self.tlsDisableCertificateRevocationCheck == nil
                && self.tlsDisableOCSPEndpointCheck == nil)
        else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsAllowInvalidCertificates), \(OptionName.tlsAllowInvalidHostnames),"
                    + " \(OptionName.tlsDisableCertificateRevocationCheck), and"
                    + " \(OptionName.tlsDisableOCSPEndpointCheck) cannot be specified if \(OptionName.tlsInsecure)"
                    + " is specified in the connection string"
            )
        }
        guard !(self.tlsAllowInvalidCertificates != nil && self.tlsDisableOCSPEndpointCheck != nil) else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsAllowInvalidCertificates) and \(OptionName.tlsDisableOCSPEndpointCheck)"
                    + " cannot both be specified in the connection string"
            )
        }
        guard !(self.tlsAllowInvalidCertificates != nil && self.tlsDisableCertificateRevocationCheck != nil) else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsAllowInvalidCertificates) and"
                    + " \(OptionName.tlsDisableCertificateRevocationCheck) cannot both be specified in the connection"
                    + " string"
            )
        }
        guard !(self.tlsDisableOCSPEndpointCheck != nil && self.tlsDisableCertificateRevocationCheck != nil) else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsDisableOCSPEndpointCheck) and"
                    + " \(OptionName.tlsDisableCertificateRevocationCheck) cannot both be specified in the connection"
                    + " string"
            )
        }
    }

    private mutating func validateAndSetCompressors(_ options: Options) throws {
        if let compressorStrings = options.compressors {
            self.compressors = try compressorStrings.map {
                switch $0 {
                case "zlib":
                    if let zlibCompressionLevel = options.zlibCompressionLevel {
                        return try Compressor.zlib(level: zlibCompressionLevel)
                    } else {
                        return Compressor.zlib
                    }
                case let other:
                    throw MongoError.InvalidArgumentError(
                        message: "Unrecognized compressor specified in the connection string: \(other)"
                    )
                }
            }
        }
    }

    private mutating func validateAndSetReadPreference(_ options: Options) throws {
        if let modeString = options.readPreference {
            guard let mode = ReadPreference.Mode(rawValue: modeString) else {
                throw MongoError.InvalidArgumentError(
                    message: "Unknown \(OptionName.readPreference) specified in the connection string: \(modeString)"
                )
            }
            self.readPreference = try ReadPreference(
                mode,
                tagSets: options.readPreferenceTags,
                maxStalenessSeconds: options.maxStalenessSeconds
            )
        } else if options.readPreferenceTags != nil || options.maxStalenessSeconds != nil {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.readPreferenceTags) and \(OptionName.maxStalenessSeconds) should not be"
                    + " specified in the connection string if \(OptionName.readPreference) is not specified"
            )
        }
    }

    private mutating func validateAndSetWriteConcern(_ options: Options) throws {
        if options.journal != nil || options.w != nil || options.wTimeoutMS != nil {
            self.writeConcern = try WriteConcern(
                journal: options.journal,
                w: options.w,
                wtimeoutMS: options.wTimeoutMS
            )
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
            try self.init(string: stringValue)
        } catch let error as MongoError.InvalidArgumentError {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: error.message
            )
        }
    }

    /// `LosslessStringConvertible` protocol requirements
    public init?(_ description: String) {
        try? self.init(string: description)
    }

    public var description: String {
        var uri = ""
        uri += "\(self.scheme)://"
        if let username = self.credential?.username {
            uri += username.getPercentEncoded(withAllowedCharacters: Self.allowedForNonOptionEncoding)
            if let password = self.credential?.password {
                uri += ":" + password.getPercentEncoded(withAllowedCharacters: Self.allowedForNonOptionEncoding)
            }
            uri += "@"
        }
        uri += self.hosts.map { $0.description }.joined(separator: ",")
        // A trailing slash in the connection string is valid so we can append this unconditionally.
        uri += "/"
        if let defaultAuthDB = self.defaultAuthDB {
            uri += defaultAuthDB.getPercentEncoded(withAllowedCharacters: Self.allowedForNonOptionEncoding)
        }
        uri += "?"
        uri.appendOption(name: .appName, option: self.appName)
        uri.appendOption(name: .authMechanism, option: self.credential?.mechanism?.description)
        uri.appendOption(name: .authMechanismProperties, option: self.credential?.mechanismProperties?.map {
            var property = $0.key + ":"
            switch $0.value {
            case let .string(s):
                property += s
            case let .bool(b):
                property += String(b)
            // the possible values for authMechanismProperties are only strings and booleans
            default:
                property += ""
            }
            return property
        }.joined(separator: ","))
        if self.credential?.sourceFromAuthSource == true {
            uri.appendOption(name: .authSource, option: self.credential?.source)
        }
        uri.appendOption(name: .compressors, option: self.compressors?.map {
            switch $0._compressor {
            case let .zlib(level):
                uri.appendOption(name: .zlibCompressionLevel, option: level)
                return "zlib"
            }
        }.joined(separator: ","))
        uri.appendOption(name: .connectTimeoutMS, option: self.connectTimeoutMS)
        uri.appendOption(name: .directConnection, option: self.directConnection)
        uri.appendOption(name: .heartbeatFrequencyMS, option: self.heartbeatFrequencyMS)
        uri.appendOption(name: .journal, option: self.writeConcern?.journal)
        uri.appendOption(name: .loadBalanced, option: self.loadBalanced)
        uri.appendOption(name: .localThresholdMS, option: self.localThresholdMS)
        uri.appendOption(name: .maxPoolSize, option: self.maxPoolSize)
        uri.appendOption(name: .maxStalenessSeconds, option: self.readPreference?.maxStalenessSeconds)
        uri.appendOption(name: .readConcernLevel, option: self.readConcern?.level)
        uri.appendOption(name: .readPreference, option: self.readPreference?.mode.rawValue)
        if let tagSets = self.readPreference?.tagSets {
            for tags in tagSets {
                uri.appendOption(name: .readPreferenceTags, option: tags.map {
                    var tag = $0.key + ":"
                    switch $0.value {
                    case let .string(s):
                        tag += s
                    // tags are always parsed as strings
                    default:
                        tag += ""
                    }
                    return tag
                }.joined(separator: ","))
            }
        }
        uri.appendOption(name: .replicaSet, option: self.replicaSet)
        uri.appendOption(name: .retryReads, option: self.retryReads)
        uri.appendOption(name: .retryWrites, option: self.retryWrites)
        uri.appendOption(name: .serverSelectionTimeoutMS, option: self.serverSelectionTimeoutMS)
        uri.appendOption(name: .socketTimeoutMS, option: self.socketTimeoutMS)
        uri.appendOption(name: .srvMaxHosts, option: self.srvMaxHosts)
        uri.appendOption(name: .srvServiceName, option: self.srvServiceName)
        uri.appendOption(name: .tls, option: self.tls)
        uri.appendOption(name: .tlsAllowInvalidCertificates, option: self.tlsAllowInvalidCertificates)
        uri.appendOption(name: .tlsAllowInvalidHostnames, option: self.tlsAllowInvalidHostnames)
        uri.appendOption(name: .tlsCAFile, option: self.tlsCAFile)
        uri.appendOption(name: .tlsCertificateKeyFile, option: self.tlsCertificateKeyFile)
        uri.appendOption(name: .tlsCertificateKeyFilePassword, option: self.tlsCertificateKeyFilePassword)
        uri.appendOption(
            name: .tlsDisableCertificateRevocationCheck,
            option: self.tlsDisableCertificateRevocationCheck
        )
        uri.appendOption(name: .tlsDisableOCSPEndpointCheck, option: self.tlsDisableOCSPEndpointCheck)
        uri.appendOption(name: .tlsInsecure, option: self.tlsInsecure)
        uri.appendOption(name: .w, option: self.writeConcern?.w.map {
            switch $0 {
            case let .number(n):
                return String(n)
            case .majority:
                return "majority"
            case let .custom(other):
                return other
            }
        })
        uri.appendOption(name: .wTimeoutMS, option: self.writeConcern?.wtimeoutMS)
        // Pop either the trailing "&" or the trailing "?" if no options were present.
        _ = uri.popLast()
        return uri
    }

    /// Returns a document containing all of the options provided after the ? of the URI.
    internal var options: BSONDocument {
        var options = BSONDocument()

        if let appName = self.appName {
            options[.appName] = .string(appName)
        }
        if let authMechanism = self.credential?.mechanism {
            options[.authMechanism] = .string(authMechanism.description)
        }
        if let authMechanismProperties = self.credential?.mechanismProperties {
            options[.authMechanismProperties] = .document(authMechanismProperties)
        }
        if let authSource = self.credential?.source {
            options[.authSource] = .string(authSource)
        }
        if let compressors = self.compressors {
            var compressorNames: [BSON] = []
            for compressor in compressors {
                switch compressor._compressor {
                case let .zlib(level):
                    compressorNames.append(.string("zlib"))
                    if let level = level {
                        options[.zlibCompressionLevel] = .int32(level)
                    }
                }
            }
            options[.compressors] = .array(compressorNames)
        }
        if let connectTimeoutMS = self.connectTimeoutMS {
            options[.connectTimeoutMS] = .int32(Int32(connectTimeoutMS))
        }
        if let directConnection = self.directConnection {
            options[.directConnection] = .bool(directConnection)
        }
        if let heartbeatFrequencyMS = self.heartbeatFrequencyMS {
            options[.heartbeatFrequencyMS] = .int32(Int32(heartbeatFrequencyMS))
        }
        if let journal = self.writeConcern?.journal {
            options[.journal] = .bool(journal)
        }
        if let loadBalanced = self.loadBalanced {
            options[.loadBalanced] = .bool(loadBalanced)
        }
        if let localThresholdMS = self.localThresholdMS {
            options[.localThresholdMS] = .int32(Int32(localThresholdMS))
        }
        if let maxPoolSize = self.maxPoolSize {
            options[.maxPoolSize] = .int32(Int32(maxPoolSize))
        }
        if let maxStalenessSeconds = self.readPreference?.maxStalenessSeconds {
            options[.maxStalenessSeconds] = .int32(Int32(maxStalenessSeconds))
        }
        if let readConcern = self.readConcern {
            options[.readConcernLevel] = .string(readConcern.level ?? "")
        }
        if let readPreference = self.readPreference?.mode {
            options[.readPreference] = .string(readPreference.rawValue)
        }
        if let readPreferenceTags = self.readPreference?.tagSets {
            options[.readPreferenceTags] = .array(readPreferenceTags.map { .document($0) })
        }
        if let replicaSet = self.replicaSet {
            options[.replicaSet] = .string(replicaSet)
        }
        if let retryReads = self.retryReads {
            options[.retryReads] = .bool(retryReads)
        }
        if let retryWrites = self.retryWrites {
            options[.retryWrites] = .bool(retryWrites)
        }
        if let serverSelectionTimeoutMS = self.serverSelectionTimeoutMS {
            options[.serverSelectionTimeoutMS] = .int32(Int32(serverSelectionTimeoutMS))
        }
        if let socketTimeoutMS = self.socketTimeoutMS {
            options[.socketTimeoutMS] = .int32(Int32(socketTimeoutMS))
        }
        if let srvMaxHosts = self.srvMaxHosts {
            options[.srvMaxHosts] = .int32(Int32(srvMaxHosts))
        }
        if let srvServiceName = self.srvServiceName {
            options[.srvServiceName] = .string(srvServiceName)
        }
        if let tls = self.tls {
            options[OptionName.tls] = .bool(tls)
        }
        if let tlsAllowInvalidCertificates = self.tlsAllowInvalidCertificates {
            options[OptionName.tlsAllowInvalidCertificates] = .bool(tlsAllowInvalidCertificates)
        }
        if let tlsAllowInvalidHostnames = self.tlsAllowInvalidHostnames {
            options[OptionName.tlsAllowInvalidHostnames] = .bool(tlsAllowInvalidHostnames)
        }
        if let tlsCAFile = self.tlsCAFile {
            options[OptionName.tlsCAFile] = .string(tlsCAFile.description)
        }
        if let tlsCertificateKeyFile = self.tlsCertificateKeyFile {
            options[OptionName.tlsCertificateKeyFile] = .string(tlsCertificateKeyFile.description)
        }
        if let tlsCertificateKeyFilePassword = self.tlsCertificateKeyFilePassword {
            options[OptionName.tlsCertificateKeyFilePassword] = .string(tlsCertificateKeyFilePassword)
        }
        if let tlsDisableCertificateRevocationCheck = self.tlsDisableCertificateRevocationCheck {
            options[OptionName.tlsDisableCertificateRevocationCheck] = .bool(tlsDisableCertificateRevocationCheck)
        }
        if let tlsDisableOCSPEndpointCheck = self.tlsDisableOCSPEndpointCheck {
            options[OptionName.tlsDisableOCSPEndpointCheck] = .bool(tlsDisableOCSPEndpointCheck)
        }
        if let tlsInsecure = self.tlsInsecure {
            options[OptionName.tlsInsecure] = .bool(tlsInsecure)
        }
        if let w = self.writeConcern?.w {
            switch w {
            case let .number(n):
                options[OptionName.w] = .int32(Int32(n))
            case .majority:
                options[OptionName.w] = .string("majority")
            case let .custom(other):
                options[OptionName.w] = .string(other)
            }
        }
        if let wTimeoutMS = self.writeConcern?.wtimeoutMS {
            options[OptionName.wTimeoutMS] = .int32(Int32(wTimeoutMS))
        }
        return options
    }

    internal func withMongocURI<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        var uri = self
        if uri.directConnection == nil {
            uri.directConnection = false
        }
        var error = bson_error_t()
        guard let mongocURI = mongoc_uri_new_with_error(uri.description, &error) else {
            throw extractMongoError(error: error)
        }
        defer { mongoc_uri_destroy(mongocURI) }
        return try body(mongocURI)
    }

    /// Specifies the format this connection string is in.
    public var scheme: Scheme

    /// Specifies one or more host/ports to connect to.
    public var hosts: [HostIdentifier]

    /// The default database to use for authentication if an `authSource` is unspecified in the connection string.
    /// Defaults to "admin" if unspecified.
    public var defaultAuthDB: String?

    /// Specifies a custom app name. This value is used in MongoDB logs and profiling data.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/#urioption.appName
    public var appName: String?

    /// Specifies one or more compressors to use for network compression for communication between this client and
    /// mongod/mongos instances. Currently, the driver only supports compression via zlib.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/#urioption.compressors
    public var compressors: [Compressor]?

    /// Specifies the maximum time, in milliseconds, for an individual connection to establish a TCP
    /// connection to a MongoDB server before timing out.
    public var connectTimeoutMS: Int?

    /// Specifies the authentication credentials.
    public var credential: MongoCredential?

    /// Specifies whether the client should connect directly to a single host. When false, the client will attempt to
    /// automatically discover all replica set members if a replica set name is provided. Defaults to false.
    /// It is an error to set this option to `true` when used with a mongodb+srv connection string or when multiple
    /// hosts are specified in the connection string.
    public var directConnection: Bool?

    /// Specifies how often the driver checks the state of the MongoDB deployment. Specifies the interval (in
    /// milliseconds) between checks, counted from the end of the previous check until the beginning of the next one.
    /// Defaults to 10 seconds (10,000 ms). Must be at least 500ms.
    public var heartbeatFrequencyMS: Int?

    /// Specifies whether the driver is connecting to a load balancer.
    public var loadBalanced: Bool?

    /// The size (in milliseconds) of the permitted latency window beyond the fastest round-trip time amongst all
    /// servers. By default, only servers within 15ms of the fastest round-trip time receive queries.
    public var localThresholdMS: Int?

    /// The maximum number of connections that may be associated with a connection pool created by this client at a
    /// given time. This includes in-use and available connections. Defaults to 100.
    public var maxPoolSize: Int?

    /// An alternative lower bound for heartbeatFrequencyMS, used for speeding up tests (default 500ms).
    internal var minHeartbeatFrequencyMS: Int = 500

    /// Specifies a ReadConcern to use for the client.
    public var readConcern: ReadConcern?

    /// Specifies a ReadPreference to use for the client.
    public var readPreference: ReadPreference?

    /// Specifies the name of the replica set the driver should connect to.
    public var replicaSet: String?

    /// Specifies whether the client should retry supported read operations (on by default).
    public var retryReads: Bool?

    /// Specifies whether the client should retry supported write operations (on by default).
    public var retryWrites: Bool?

    /// Specifies how long the driver should attempt to select a server for before throwing an error. Defaults to 30
    /// seconds (30000 ms).
    public var serverSelectionTimeoutMS: Int?

    /// Specifies how long the driver to attempt to send or receive on a socket before timing out.
    ///
    /// - Note: This option only applies to application operations, not server monitoring checks.
    public var socketTimeoutMS: Int?

    /// Specifies the maximum number of SRV results to select randomly when initially populating the seedlist, or,
    /// during SRV polling, adding new hosts to the topology.
    public var srvMaxHosts: Int?

    /// Specifies the service name to use for SRV lookup during initial DNS seedlist discovery and SRV polling.
    public var srvServiceName: String?

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

    /// Specifies whether OCSP responder endpoints should not be requested when an OCSP response is not stapled.
    /// On macOS, this setting has no effect.
    /// By default this is set to false.
    public var tlsDisableOCSPEndpointCheck: Bool?

    /// Specifies whether TLS constraints will be relaxed as much as possible. Currently, setting this option to `true`
    /// is equivalent to setting `tlsAllowInvalidCertificates`, `tlsAllowInvalidHostnames`, and
    /// `tlsDisableCertificateRevocationCheck` to `true`.
    /// It is an error to specify both this option and any of the options enabled by it.
    public var tlsInsecure: Bool?

    /// Specifies a WriteConcern to use for the client.
    public var writeConcern: WriteConcern?
}

/// Helper extension to set a document field with a `MongoConnectionString.OptionName`.
extension BSONDocument {
    fileprivate subscript(name: MongoConnectionString.OptionName) -> BSON? {
        get {
            self[name.rawValue]
        }
        set {
            self[name.rawValue] = newValue
        }
    }
}

extension String {
    fileprivate mutating func appendOption(name: MongoConnectionString.OptionName, option: CustomStringConvertible?) {
        if let option = option {
            let optionString = option.description.getPercentEncoded(
                withAllowedCharacters: MongoConnectionString.allowedForOptionEncoding
            )
            self += name.rawValue + "=" + optionString + "&"
        }
    }
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

    fileprivate func isIPv4() -> Bool {
        let numbers = self.components(separatedBy: ".")
        guard numbers.count == 4 else {
            return false
        }
        for number in numbers {
            guard let n = Int(number), (0...255).contains(n) else {
                return false
            }
        }
        return true
    }

    fileprivate func getPercentEncoded(withAllowedCharacters allowed: CharacterSet) -> String {
        self.addingPercentEncoding(withAllowedCharacters: allowed) ?? String(self)
    }

    fileprivate func getValidatedUserInfo(forKey key: String) throws -> String {
        for character in MongoConnectionString.genDelims {
            if self.contains(character) {
                throw MongoError.InvalidArgumentError(
                    message: "\(key) in the connection string contains invalid character that must be percent-encoded:"
                        + " \(character)"
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

    fileprivate func getInt(forKey key: String) throws -> Int {
        guard let n = Int(self) else {
            throw MongoError.InvalidArgumentError(
                message: "Value for \(key) in connection string must be an integer"
            )
        }
        return n
    }

    /// Validates that an SRV service name is well-formed.
    /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc6335#section-5.1
    fileprivate func validateSRVServiceName() throws {
        let prefix: () -> String = {
            "Value for \(MongoConnectionString.OptionName.srvServiceName) in the connection string must "
        }
        guard self.count >= 1 && self.count <= 15 else {
            throw MongoError.InvalidArgumentError(
                message: prefix() + "be at least 1 character and no more than 15 characters long"
            )
        }
        guard !self.hasPrefix("-") && !self.hasSuffix("-") else {
            throw MongoError.InvalidArgumentError(message: prefix() + "not start or end with a hyphen")
        }
        var containsLetter = false
        var lastWasHyphen = false
        for character in self {
            guard character.isNumber || character.isLetter || character == "-" else {
                throw MongoError.InvalidArgumentError(
                    message: prefix() + "only contain numbers, letters, and hyphens"
                )
            }
            if character.isLetter {
                containsLetter = true
            }
            if character == "-" {
                if lastWasHyphen {
                    throw MongoError.InvalidArgumentError(message: prefix() + "not contain consecutive hyphens")
                }
            }
            lastWasHyphen = character == "-"
        }
        if !containsLetter {
            throw MongoError.InvalidArgumentError(message: prefix() + "contain at least one letter")
        }
    }
}
