import Foundation

/// A struct representing a server version.
public struct ServerVersion: Comparable, Decodable, CustomStringConvertible {
    public static let mongodFailCommandSupport = ServerVersion(major: 4, minor: 0)
    public static let mongosFailCommandSupport = ServerVersion(major: 4, minor: 1, patch: 5)

    let major: Int
    let minor: Int
    let patch: Int

    /// initialize a server version from a string
    public init(_ str: String) throws {
        let versionComponents = str.split(separator: ".").prefix(3)
        guard versionComponents.count >= 2 else {
            throw TestError(message: "Expected version string \(str) to have at least two .-separated components")
        }

        guard let major = Int(versionComponents[0]) else {
            throw TestError(message: "Error parsing major version from \(str)")
        }
        guard let minor = Int(versionComponents[1]) else {
            throw TestError(message: "Error parsing minor version from \(str)")
        }

        var patch = 0
        if versionComponents.count == 3 {
            // in case there is text at the end, for ex "3.6.0-rc1", stop first time
            /// we encounter a non-numeric character.
            let numbersOnly = versionComponents[2].prefix { "0123456789".contains($0) }
            guard let patchValue = Int(numbersOnly) else {
                throw TestError(message: "Error parsing patch version from \(str)")
            }
            patch = patchValue
        }

        self.init(major: major, minor: minor, patch: patch)
    }

    public init(from decoder: Decoder) throws {
        let str = try decoder.singleValueContainer().decode(String.self)
        try self.init(str)
    }

    // initialize given major, minor, and optional patch
    public init(major: Int, minor: Int, patch: Int? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch ?? 0
    }

    public var description: String {
        "\(self.major).\(self.minor).\(self.patch)"
    }

    public static func < (lhs: ServerVersion, rhs: ServerVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        } else if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        } else {
            return lhs.patch < rhs.patch
        }
    }
}
