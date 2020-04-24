/// Represents an authentication credential.
public struct Credential: Decodable, Equatable {
    /// A string containing the username. For auth mechanisms that do not utilize a password, this may be the entire
    /// `userinfo` token from the connection string.
    internal let username: String?
    /// A string containing the password.
    internal let password: String?
    /// A string containing the authentication database.
    internal let source: String?
    /// The authentication mechanism. A nil value for this property indicates that a mechanism wasn't specified and
    /// that mechanism negotiation is required.
    internal let mechanism: AuthMechanism?
    /// A document containing mechanism-specific properties.
    internal let mechanismProperties: Document?

    private enum CodingKeys: String, CodingKey {
        case username, password, source, mechanism, mechanismProperties = "mechanism_properties"
    }
}

/// Possible authentication mechanisms.
public enum AuthMechanism: String, Decodable {
    case scramSHA1 = "SCRAM-SHA-1"
    case scramSHA256 = "SCRAM-SHA-256"
    case gssAPI = "GSSAPI"
    case mongodbCR = "MONGODB-CR"
    case mongodbX509 = "MONGODB-X509"
    case plain = "PLAIN"
}
