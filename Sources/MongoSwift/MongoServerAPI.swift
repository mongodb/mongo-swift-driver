import CLibMongoC

// TODO: SWIFT-1159: add versioned API docs link.
/// A type containing options for specifying a MongoDB server API version and related behavior.
public struct MongoServerAPI: Codable {
    /// Represents a server API version.
    public struct Version: Codable, Equatable, LosslessStringConvertible {
        /// MongoDB API version 1.
        public static let v1 = Version(.v1)

        private enum _Version: String {
            case v1 = "1"
        }

        private let _version: _Version

        private init(_ version: _Version) {
            self._version = version
        }

        /// `LosslessStringConvertible` conformance

        public init?(_ description: String) {
            guard let _version = _Version(rawValue: description) else {
                return nil
            }
            self.init(_version)
        }

        public var description: String {
            self._version.rawValue
        }

        /// `Codable` conformance

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self._version.rawValue)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let stringValue = try container.decode(String.self)

            guard let version = _Version(rawValue: stringValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid API version string \(stringValue)"
                )
            }
            self = Version(version)
        }

        fileprivate var mongocAPIVersion: mongoc_server_api_version_t {
            switch self {
            case .v1:
                return MONGOC_SERVER_API_V1
            default:
                // we would only ever get a value besides v1 if we upgraded to a
                // version of libmongoc that supported a new API version.
                fatalError("Encountered unexpected API version \(self)")
            }
        }
    }

    /// Specifies the API version to use.
    public var version: Version

    /// Specifies whether the server should return errors for features that are not part of the API version.
    public var strict: Bool?

    /// Specifies whether the server should return errors for deprecated features.
    public var deprecationErrors: Bool?

    /// Convenience initializer allowing optional parameters to be optional or omitted.
    public init(version: Version, strict: Bool? = nil, deprecationErrors: Bool? = nil) {
        self.version = version
        self.strict = strict
        self.deprecationErrors = deprecationErrors
    }

    /// Creates an equivalent `mongoc_server_api_t` and uses a pointer to it to execute the provided closure, cleaning
    /// it up afterward. The pointer must not escape the closure.
    internal func withMongocServerAPI<T>(_ body: (OpaquePointer) throws -> T) rethrows -> T {
        // this never returns nil
        guard let api = mongoc_server_api_new(self.version.mongocAPIVersion) else {
            fatalError("Failed to initialize mongoc_server_api_t")
        }
        defer { mongoc_server_api_destroy(api) }

        if let strict = self.strict {
            mongoc_server_api_strict(api, strict)
        }
        if let deprecationErrors = self.deprecationErrors {
            mongoc_server_api_deprecation_errors(api, deprecationErrors)
        }
        return try body(api)
    }
}
