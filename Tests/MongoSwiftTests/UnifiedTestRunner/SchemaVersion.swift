/// Represents a schemaVersion.
struct SchemaVersion: RawRepresentable, Comparable, Decodable {
    /// Major version.
    let major: Int

    /// Minor version.
    let minor: Int

    /// Patch version.
    let patch: Int

    public init?(rawValue: String) {
        var components = rawValue.split(separator: ".")
        // invalid number of components.
        guard (1...3).contains(components.count) else {
            return nil
        }

        guard let major = Int(components.removeFirst()) else {
            return nil
        }
        self.major = major

        guard !components.isEmpty else {
            self.minor = 0
            self.patch = 0
            return
        }

        guard let minor = Int(components.removeFirst()) else {
            return nil
        }
        self.minor = minor

        guard !components.isEmpty else {
            self.patch = 0
            return
        }

        guard let patch = Int(components.removeFirst()) else {
            return nil
        }
        self.patch = patch
    }

    public var rawValue: String {
        "\(self.major).\(self.minor).\(self.patch)"
    }

    public static func < (lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        } else if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        } else {
            return lhs.patch < rhs.patch
        }
    }
}
