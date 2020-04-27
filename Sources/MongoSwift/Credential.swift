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
    public enum Mechanism: String, Decodable {
        case scramSHA1 = "SCRAM-SHA-1"
        case scramSHA256 = "SCRAM-SHA-256"
        case gssAPI = "GSSAPI"
        case mongodbCR = "MONGODB-CR"
        case mongodbX509 = "MONGODB-X509"
        case plain = "PLAIN"
    }
}
