import SwiftBSON
/// Represents an authentication credential.
public struct MongoCredential: Decodable, Equatable {
    /// A string containing the username. For auth mechanisms that do not utilize a password, this may be the entire
    /// `userinfo` token from the connection string.
    public var username: String?

    /// A string containing the password.
    public var password: String?

    /// A string containing the authentication database.
    public var source: String? {
        didSet {
            self.sourceFromAuthSource = self.source != nil
        }
    }

    /// Tracks whether the `source` was set manually (i.e. via an `authSource` or by setting the field's value) or by
    /// a default (i.e. via the `defaultAuthDB`, the `mechanism`'s default, or the default of "admin"). This
    /// information is necessary to determine whether the `authSource` field should be set when reconstructing a
    /// `MongoConnectionString`.
    internal var sourceFromAuthSource: Bool

    /// The authentication mechanism. A nil value for this property indicates that a mechanism wasn't specified and
    /// that mechanism negotiation is required.
    public var mechanism: Mechanism?

    /// A document containing mechanism-specific properties.
    public var mechanismProperties: BSONDocument?

    private enum CodingKeys: String, CodingKey {
        case username, password, source, mechanism, mechanismProperties = "mechanism_properties"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.password = try container.decodeIfPresent(String.self, forKey: .password)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.sourceFromAuthSource = self.source != nil
        self.mechanism = try container.decodeIfPresent(Mechanism.self, forKey: .mechanism)
        self.mechanismProperties = try container.decodeIfPresent(BSONDocument.self, forKey: .mechanismProperties)
    }

    public init(
        username: String? = nil,
        password: String? = nil,
        source: String? = nil,
        mechanism: Mechanism? = nil,
        mechanismProperties: BSONDocument? = nil
    ) {
        self.username = username
        self.password = password
        self.source = source
        self.sourceFromAuthSource = self.source != nil
        self.mechanism = mechanism
        self.mechanismProperties = mechanismProperties
    }

    /// Possible authentication mechanisms.
    public struct Mechanism: Decodable, Equatable, CustomStringConvertible {
        /// GSSAPI authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/kerberos/
        public static let gssAPI = Mechanism(.gssAPI)

        /// X509 authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-x.509/#security-auth-x509
        public static let mongodbX509 = Mechanism(.mongodbX509)

        /// PLAIN authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-ldap/
        public static let plain = Mechanism(.plain)

        /// SCRAM-SHA-1 authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        public static let scramSHA1 = Mechanism(.scramSHA1)

        /// SCRAM-SHA-256 authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        public static let scramSHA256 = Mechanism(.scramSHA256)

        private enum _Mechanism: String {
            case gssAPI = "GSSAPI"
            case mongodbX509 = "MONGODB-X509"
            case plain = "PLAIN"
            case scramSHA1 = "SCRAM-SHA-1"
            case scramSHA256 = "SCRAM-SHA-256"
        }

        private init(_ mechanism: _Mechanism) {
            self._mechanism = mechanism
        }

        private let _mechanism: _Mechanism

        public var description: String { self._mechanism.rawValue }

        internal init(_ name: String) throws {
            guard let _mechanism = _Mechanism(rawValue: name) else {
                throw MongoError.InvalidArgumentError(message: "Unsupported authentication mechanism: \(name)")
            }
            self.init(_mechanism)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            try self.init(string)
        }

        internal func getDefaultSource(defaultAuthDB: String?) -> String {
            switch self._mechanism {
            case .gssAPI, .mongodbX509:
                return "$external"
            case .plain:
                return defaultAuthDB ?? "$external"
            case .scramSHA1, .scramSHA256:
                return defaultAuthDB ?? "admin"
            }
        }

        internal func validateAndUpdateCredential(credential: inout MongoCredential) throws {
            switch self._mechanism {
            case .gssAPI:
                if credential.username == nil {
                    throw MongoError.InvalidArgumentError(
                        message: "Username must be provided for GSSAPI authentication"
                    )
                }
                if let source = credential.source, source != "$external" {
                    throw MongoError.InvalidArgumentError(
                        message: "Only $external may be specified as an auth source for GSSAPI authentication"
                    )
                }
                // If no SERVICE_NAME is provided, default to "mongodb"
                if credential.mechanismProperties == nil {
                    credential.mechanismProperties = BSONDocument()
                }
                if credential.mechanismProperties?["SERVICE_NAME"] == nil {
                    credential.mechanismProperties?["SERVICE_NAME"] = .string("mongodb")
                }
            case .mongodbX509:
                if credential.password != nil {
                    throw MongoError.InvalidArgumentError(
                        message: "A password cannot be specified for MONGODB-X509 authentication"
                    )
                }
                if let source = credential.source, source != "$external" {
                    throw MongoError.InvalidArgumentError(
                        message: "Only $external may be specified as an auth source for MONGODB-X509 authentication"
                    )
                }
            case .plain:
                if let username = credential.username, username.isEmpty {
                    throw MongoError.InvalidArgumentError(
                        message: "Username for PLAIN authentication must be non-empty"
                    )
                }
                if credential.username == nil {
                    throw MongoError.InvalidArgumentError(message: "No username provided for PLAIN authentication")
                }
                if credential.password == nil {
                    throw MongoError.InvalidArgumentError(message: "No password provided for PLAIN authentication")
                }
            case .scramSHA1, .scramSHA256:
                if credential.username == nil {
                    throw MongoError.InvalidArgumentError(message: "No username provided for SCRAM authentication")
                }
            }
        }
    }
}
