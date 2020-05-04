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
    public struct Mechanism: Codable, Equatable {
        /// See https://docs.mongodb.com/manual/core/kerberos/
        public static let gssAPI = Mechanism(name: "GSSAPI")
        /// Deprecated: see https://docs.mongodb.com/manual/release-notes/3.0-scram/
        public static let mongodbCR = Mechanism(name: "MONGODB-CR")
        /// See https://docs.mongodb.com/manual/core/security-x.509/#security-auth-x509
        public static let mongodbX509 = Mechanism(name: "MONGODB-X509")
        /// See https://docs.mongodb.com/manual/core/security-ldap/
        public static let plain = Mechanism(name: "PLAIN")
        /// See https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        public static let scramSHA1 = Mechanism(name: "SCRAM-SHA-1")
        /// See https://docs.mongodb.com/manual/core/security-scram/#authentication-scram
        public static let scramSHA256 = Mechanism(name: "SCRAM-SHA-256")

        /// Name of the authentication mechanism.
        public var name: String

        public init(name: String) {
            self.name = name
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            self.name = string
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.name)
        }
    }
}
