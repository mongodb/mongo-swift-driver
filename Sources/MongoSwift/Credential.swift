/// Represents an authentication credential.
public struct Credential: Decodable, Equatable {
    /// A string containing the username. For auth mechanisms that do not utilize a password, this may be the entire
    /// `userinfo` token from the connection string.
    public var username: String?
    /// A string containing the password.
    public var password: String?
    /// A string containing the authentication database.
    public var source: String?
    /// The authentication mechanism. A nil value for this property indicates that a mechanism wasn't specified and
    /// that mechanism negotiation is required.
    public var mechanism: Mechanism?
    /// A document containing mechanism-specific properties.
    public var mechanismProperties: Document?

    private enum CodingKeys: String, CodingKey {
        case username, password, source, mechanism, mechanismProperties = "mechanism_properties"
    }

    public init(
        username: String? = nil,
        password: String? = nil,
        source: String? = nil,
        mechanism: Mechanism? = nil,
        mechanismProperties: Document? = nil
    ) {
        self.username = username
        self.password = password
        self.source = source
        self.mechanism = mechanism
        self.mechanismProperties = mechanismProperties
    }

    /// Possible authentication mechanisms.
    public enum Mechanism: RawRepresentable, Decodable, Equatable {
        /// See https://docs.mongodb.com/manual/core/kerberos/
        case gssAPI
        /// See https://docs.mongodb.com/v3.0/core/security-mongodb-cr/#authentication-mongodb-cr
        case mongodbCR
        /// See https://docs.mongodb.com/manual/core/security-x.509/#security-auth-x509
        case mongodbX509
        /// See https://docs.mongodb.com/manual/core/security-ldap/
        case plain
        /// See https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        case scramSHA1
        /// See https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        case scramSHA256
        /// Any other authentication mechanism not covered by the other cases.
        /// This case is present to provide forwards compatibility with any
        /// future authentication mechanism which may be added to new versions of MongoDB.
        case other(mechanism: String)

        public var rawValue: String {
            switch self {
            case .gssAPI:
                return "GSSAPI"
            case .mongodbCR:
                return "MONGODB-CR"
            case .mongodbX509:
                return "MONGODB-X509"
            case .plain:
                return "PLAIN"
            case .scramSHA1:
                return "SCRAM-SHA-1"
            case .scramSHA256:
                return "SCRAM-SHA-256"
            case let .other(mechanism: mechanism):
                return mechanism
            }
        }

        public init?(rawValue: String) {
            switch rawValue {
            case "GSSAPI":
                self = .gssAPI
            case "MONGODB-CR":
                self = .mongodbCR
            case "MONGODB-X509":
                self = .mongodbX509
            case "PLAIN":
                self = .plain
            case "SCRAM-SHA-1":
                self = .scramSHA1
            case "SCRAM-SHA-256":
                self = .scramSHA256
            default:
                self = .other(mechanism: rawValue)
            }
        }
    }
}
