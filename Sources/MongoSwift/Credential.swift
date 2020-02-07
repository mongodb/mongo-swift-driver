/// Represents an authentication credential.
internal struct Credential: Decodable, Equatable {
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

    // TODO: SWIFT-636: remove this initializer and the one below it.
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.password = try container.decodeIfPresent(String.self, forKey: .password)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.mechanism = try container.decodeIfPresent(AuthMechanism.self, forKey: .mechanism)

        // libmongoc does not return the service name if it's the default, but it is contained in the spec test files,
        // so filter it out here if it's present.
        let properties = try container.decodeIfPresent(Document.self, forKey: .mechanismProperties)
        let filteredProperties = properties?.filter { !($0.0 == "SERVICE_NAME" && $0.1 == "mongodb") }
        // if SERVICE_NAME was the only key then don't return an empty document.
        if filteredProperties?.isEmpty == true {
            self.mechanismProperties = nil
        } else {
            self.mechanismProperties = filteredProperties
        }
    }

    internal init(
        username: String?,
        password: String?,
        source: String?,
        mechanism: AuthMechanism?,
        mechanismProperties: Document?
    ) {
        self.mechanism = mechanism
        self.mechanismProperties = mechanismProperties
        self.password = password
        self.source = source
        self.username = username
    }
}

/// Possible authentication mechanisms.
internal enum AuthMechanism: String, Decodable {
    case scramSHA1 = "SCRAM-SHA-1"
    case scramSHA256 = "SCRAM-SHA-256"
    case gssAPI = "GSSAPI"
    case mongodbCR = "MONGODB-CR"
    case mongodbX509 = "MONGODB-X509"
    case plain = "PLAIN"
}
