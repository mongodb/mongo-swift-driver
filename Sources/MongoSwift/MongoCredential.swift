/// Represents an authentication credential.
public struct MongoCredential: Decodable, Equatable {
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
    public var mechanismProperties: BSONDocument?

    private enum CodingKeys: String, CodingKey {
        case username, password, source, mechanism, mechanismProperties = "mechanism_properties"
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
        self.mechanism = mechanism
        self.mechanismProperties = mechanismProperties
    }

    /// Possible authentication mechanisms.
    public struct Mechanism: Decodable, Equatable, CustomStringConvertible {
        /// GSSAPI authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/kerberos/
        public static let gssAPI = Mechanism("GSSAPI")

        /// X509 authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-x.509/#security-auth-x509
        public static let mongodbX509 = Mechanism("MONGODB-X509")

        /// PLAIN authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-ldap/
        public static let plain = Mechanism("PLAIN")

        /// SCRAM-SHA-1 authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        public static let scramSHA1 = Mechanism("SCRAM-SHA-1")

        /// SCRAM-SHA-256 authentication.
        /// - SeeAlso: https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        public static let scramSHA256 = Mechanism("SCRAM-SHA-256")

        /// Name of the authentication mechanism.
        internal var name: String

        public var description: String { self.name }

        internal init(_ name: String) {
            self.name = name
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            self.name = string
        }
    }
}
