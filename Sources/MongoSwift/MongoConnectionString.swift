import Foundation
import SwiftBSON

/// Represents a MongoDB connection string.
/// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/
public struct MongoConnectionString: Codable, LosslessStringConvertible {
    private static let forbiddenDBCharacters = ["/", "\\", " ", "\"", "$"]
    /// Forbidden characters per RFC 3986.
    /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc3986#section-2.2
    fileprivate static let forbiddenUserInfoCharacters = [":", "/", "?", "#", "[", "]", "@"]

    fileprivate enum OptionName: String {
        case appName = "appname"
        case authSource = "authsource"
        case authMechanism = "authmechanism"
        case authMechanismProperties = "authmechanismproperties"
        case compressors
        case connectTimeoutMS = "connecttimeooutms"
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
        fileprivate var zlibCompressionLevel: Int32?

        fileprivate init(_ uriOptions: String) throws {
            let options = uriOptions.components(separatedBy: "&")
            // tracks options that have already been set to error on duplicates
            var setOptions: [String] = []
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
                guard !setOptions.contains(name.rawValue) || name == .readPreferenceTags else {
                    throw MongoError.InvalidArgumentError(
                        message: "Connection string contains duplicate option: \(name)"
                    )
                }
                setOptions.append(name.rawValue)
                let value = try nameAndValue[1].getPercentDecoded(forKey: name.rawValue)
                let prefix: () -> String = { "Value for \(name) in the connection string must " }
                switch name {
                case .appName:
                    self.appName = value
                case .authSource:
                    if value.isEmpty {
                        throw MongoError.InvalidArgumentError(message: prefix() + "not be empty")
                    }
                    self.authSource = value
                case .authMechanism:
                    self.authMechanism = try MongoCredential.Mechanism(value)
                case .authMechanismProperties:
                    self.authMechanismProperties = try Self.parseAuthMechanismProperties(properties: value)
                case .compressors:
                    if value.isEmpty {
                        throw MongoError.InvalidArgumentError(message: prefix() + "not be empty")
                    }
                    self.compressors = value.components(separatedBy: ",")
                case .connectTimeoutMS:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n >= 0 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be nonnegative")
                    }
                    self.connectTimeoutMS = n
                case .directConnection:
                    self.directConnection = try value.getBool(forKey: name.rawValue)
                case .heartbeatFrequencyMS:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n >= 500 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be >= 500")
                    }
                    self.heartbeatFrequencyMS = n
                case .journal:
                    self.journal = try value.getBool(forKey: name.rawValue)
                case .loadBalanced:
                    self.loadBalanced = try value.getBool(forKey: name.rawValue)
                case .localThresholdMS:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n >= 0 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be nonnegative")
                    }
                    self.localThresholdMS = n
                case .maxPoolSize:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n > 0 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be positive")
                    }
                    self.maxPoolSize = n
                case .maxStalenessSeconds:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n == -1 || n >= 90 else {
                        throw MongoError.InvalidArgumentError(
                            message: prefix() + "be -1 (for no max staleness check) or >= 90"
                        )
                    }
                    self.maxStalenessSeconds = n
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
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n > 0 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be positive")
                    }
                case .socketTimeoutMS:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n >= 0 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be nonnegative")
                    }
                    self.socketTimeoutMS = n
                case .srvMaxHosts:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n >= 0 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be nonnegative")
                    }
                    self.srvMaxHosts = n
                case .srvServiceName:
                    try value.validateSRVServiceName()
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
                    self.tlsDisableCertificateRevocationCheck =
                        try value.getBool(forKey: name.rawValue)
                case .tlsDisableOCSPEndpointCheck:
                    self.tlsDisableOCSPEndpointCheck = try value.getBool(forKey: name.rawValue)
                case .tlsInsecure:
                    self.tlsInsecure = try value.getBool(forKey: name.rawValue)
                case .w:
                    self.w = try WriteConcern.W(value)
                case .wTimeoutMS:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard n >= 0 else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be nonnegative")
                    }
                    self.wTimeoutMS = n
                case .zlibCompressionLevel:
                    let n = try value.getInt(forKey: name.rawValue)
                    guard (-1...9).contains(n) else {
                        throw MongoError.InvalidArgumentError(message: prefix() + "be between -1 and 9 (inclusive)")
                    }
                    // This cast will always work because we've validated that n is between -1 and 9.
                    self.zlibCompressionLevel = Int32(n)
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

        // Validate and set compressors
        try self.validateAndSetCompressors(options)

        // Parse authentication options into a MongoCredential
        try self.validateAndUpdateCredential(options)

        // Validate and set directConnection
        try self.validateAndSetDirectConnection(options)

        // Validate and set loadBalanced
        try self.validateAndSetLoadBalanced(options)

        // Validate and set read preference
        try self.validateAndSetReadPreference(options)

        // Validate and set SRV options
        try self.validateAndSetSRVOptions(options)

        // Validate and set TLS options
        try self.validateAndSetTLSOptions(options)

        // Validate and set write concern
        try self.validateAndSetWriteConcern(options)

        // Set rest of options
        self.appName = options.appName
        self.connectTimeoutMS = options.connectTimeoutMS
        self.heartbeatFrequencyMS = options.heartbeatFrequencyMS
        self.localThresholdMS = options.localThresholdMS
        self.maxPoolSize = options.maxPoolSize
        self.readConcern = options.readConcern
        self.replicaSet = options.replicaSet
        self.retryReads = options.retryReads
        self.retryWrites = options.retryWrites
        self.serverSelectionTimeoutMS = options.serverSelectionTimeoutMS
        self.socketTimeoutMS = options.socketTimeoutMS
    }

    private mutating func validateAndSetCompressors(_ options: Options) throws {
        if let compressorStrings = options.compressors {
            self.compressors = try compressorStrings.map {
                try Compressor(name: $0, level: options.zlibCompressionLevel)
            }
        }
    }

    private mutating func validateAndUpdateCredential(_ options: Options) throws {
        if let mechanism = options.authMechanism {
            var credential = self.credential ?? MongoCredential()
            credential.source = options.authSource ?? mechanism.getDefaultSource(defaultAuthDB: self.defaultAuthDB)
            credential.mechanismProperties = options.authMechanismProperties
            try mechanism.validateAndUpdateCredential(credential: &credential)
            credential.mechanism = mechanism
            self.credential = credential
        } else if options.authMechanismProperties != nil {
            throw MongoError.InvalidArgumentError(
                message: "Connection string specified \(OptionName.authMechanismProperties) but no"
                    + " \(OptionName.authMechanism) was specified"
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
                    message: "No username provided for authentication in the connection string but an authentication"
                        + " source was provided. To use an authentication mechanism that does not require a username,"
                        + " specify an \(OptionName.authMechanism) in the connection string."
                )
            }
        }
    }

    private mutating func validateAndSetDirectConnection(_ options: Options) throws {
        guard !(options.directConnection == true && self.hosts.count > 1) else {
            throw MongoError.InvalidArgumentError(
                message: "Multiple hosts cannot be specified in the connection string if"
                    + " \(OptionName.directConnection) is set to true"
            )
        }
        self.directConnection = options.directConnection
    }

    private mutating func validateAndSetLoadBalanced(_ options: Options) throws {
        if options.loadBalanced == true {
            if self.hosts.count > 1 {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.loadBalanced) cannot be set to true if multiple hosts are specified in the"
                        + " connection string"
                )
            }
            if options.replicaSet != nil {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.loadBalanced) cannot be set to true if \(OptionName.replicaSet) is"
                        + " specified in the connection string"
                )
            }
            if options.directConnection == true {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.loadBalanced) and \(OptionName.directConnection) cannot both be set to true"
                        + " in the connection string"
                )
            }
        }
        self.loadBalanced = options.loadBalanced
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
        }
    }

    private mutating func validateAndSetSRVOptions(_ options: Options) throws {
        guard self.scheme == .srv || (options.srvMaxHosts == nil && options.srvServiceName == nil) else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.srvMaxHosts) and \(OptionName.srvServiceName) must not be specified if the"
                    + " connection string scheme is not SRV"
            )
        }
        if let srvMaxHosts = options.srvMaxHosts {
            guard !(srvMaxHosts > 0 && options.replicaSet != nil) else {
                throw MongoError.InvalidArgumentError(
                    message: "\(OptionName.replicaSet) must not be specified in the connection string if the value for"
                        + " \(OptionName.srvMaxHosts) is greater than zero"
                )
            }
            guard !(srvMaxHosts > 0 && options.loadBalanced == true) else {
                throw MongoError.InvalidArgumentError(
                    message: "The value for \(OptionName.loadBalanced) in the connection string must not be true if"
                        + " the value for \(OptionName.srvMaxHosts) is greater than zero"
                )
            }
        }
        self.srvMaxHosts = options.srvMaxHosts
        self.srvServiceName = options.srvServiceName
    }

    private mutating func validateAndSetTLSOptions(_ options: Options) throws {
        guard options.tlsInsecure == nil
            || (options.tlsAllowInvalidCertificates == nil
                && options.tlsAllowInvalidHostnames == nil
                && options.tlsDisableCertificateRevocationCheck == nil
                && options.tlsDisableOCSPEndpointCheck == nil)
        else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsAllowInvalidCertificates), \(OptionName.tlsAllowInvalidHostnames),"
                    + " \(OptionName.tlsDisableCertificateRevocationCheck), and"
                    + " \(OptionName.tlsDisableOCSPEndpointCheck) cannot be specified if \(OptionName.tlsInsecure)"
                    + " is specified in the connection string"
            )
        }
        guard !(options.tlsAllowInvalidCertificates != nil && options.tlsDisableOCSPEndpointCheck != nil) else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsAllowInvalidCertificates) and \(OptionName.tlsDisableOCSPEndpointCheck)"
                    + " cannot both be specified in the connection string"
            )
        }
        guard !(options.tlsAllowInvalidCertificates != nil && options.tlsDisableCertificateRevocationCheck != nil)
        else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsAllowInvalidCertificates) and"
                    + " \(OptionName.tlsDisableCertificateRevocationCheck) cannot both be specified in the connection"
                    + " string"
            )
        }
        guard !(options.tlsDisableOCSPEndpointCheck != nil
            && options.tlsDisableCertificateRevocationCheck != nil)
        else {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tlsDisableOCSPEndpointCheck) and"
                    + " \(OptionName.tlsDisableCertificateRevocationCheck) cannot both be specified in the connection"
                    + " string"
            )
        }
        if let tls = options.tls, let ssl = options.ssl, tls != ssl {
            throw MongoError.InvalidArgumentError(
                message: "\(OptionName.tls) and \(OptionName.ssl) must have the same value if both are specified in"
                    + " the connection string"
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

        if let appName = self.appName {
            options[.appName] = .string(appName)
        }
        if let authSource = self.credential?.source {
            options[.authSource] = .string(authSource)
        }
        if let authMechanism = self.credential?.mechanism {
            options[.authMechanism] = .string(authMechanism.description)
        }
        if let authMechanismProperties = self.credential?.mechanismProperties {
            options[.authMechanismProperties] = .document(authMechanismProperties)
        }
        if let compressors = self.compressors {
            var compressorNames: [BSON] = []
            options[.compressors] = .array([])
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
    /// - Note: This option only applies to application operations, not SDAM.
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

extension Compressor {
    fileprivate init(name: String, level: Int32?) throws {
        switch name {
        case "zlib":
            self._compressor = .zlib(level: level)
        case let other:
            throw MongoError.InvalidArgumentError(message: "\(other) compression is not supported")
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

    fileprivate func getValidatedUserInfo(forKey key: String) throws -> String {
        for character in MongoConnectionString.forbiddenUserInfoCharacters {
            if self.contains(character) {
                throw MongoError.InvalidArgumentError(
                    message: "\(key) in the connection string contains invalid character that must be percent-encoded:"
                        + character
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
