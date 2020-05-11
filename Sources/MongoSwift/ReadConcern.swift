import CLibMongoC

/// A struct to represent a MongoDB read concern.
public struct ReadConcern: Codable {
    /// Local ReadConcern.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/read-concern-local/
    public static let local = ReadConcern("local")

    /// Available ReadConcern.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/read-concern-available/
    public static let available = ReadConcern("available")

    /// Linearizable ReadConcern.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/read-concern-majority/
    public static let linearizable = ReadConcern("linearizable")

    /// Majority ReadConcern.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/read-concern-linearizable/
    public static let majority = ReadConcern("majority")

    /// Snapshot ReadConcern.
    /// - SeeAlso: https://docs.mongodb.com/master/reference/read-concern-snapshot/
    public static let snapshot = ReadConcern("snapshot")

    /// Server default ReadConcern.
    public static let serverDefault = ReadConcern(nil)

    /// For an unknown ReadConcern.
    /// For forwards compatibility, no error will be thrown when an unknown value is provided.
    public static func other(_ level: String) -> ReadConcern {
        ReadConcern(level)
    }

    /// The level of this `ReadConcern`, or `nil` if the level is not set.
    internal var level: String?

    /// Indicates whether this `ReadConcern` is the server default.
    public var isDefault: Bool {
        self.level == nil
    }

    // Initializes a new `ReadConcern` with the same level as the provided `mongoc_read_concern_t`.
    // The caller is responsible for freeing the original `mongoc_read_concern_t`.
    internal init(copying readConcern: OpaquePointer) {
        if let level = mongoc_read_concern_get_level(readConcern) {
            self.level = String(cString: level)
        }
    }

    /// Initialize a new `ReadConcern` with a `String`.
    fileprivate init(_ level: String?) {
        self.level = level
    }

    /**
     * Creates a new `mongoc_read_concern_t` based on this `ReadConcern` and passes it to the provided closure.
     * The pointer is only valid within the body of the closure and will be freed after the body completes.
     */
    internal func withMongocReadConcern<T>(_ body: (OpaquePointer) throws -> T) rethrows -> T {
        let readConcern: OpaquePointer = mongoc_read_concern_new()
        defer { mongoc_read_concern_destroy(readConcern) }
        if let level = self.level {
            mongoc_read_concern_set_level(readConcern, level)
        }
        return try body(readConcern)
    }
}

/// An extension of `ReadConcern` to make it `CustomStringConvertible`.
extension ReadConcern: CustomStringConvertible {
    /// Returns the relaxed extended JSON representation of this `ReadConcern`.
    /// On error, an empty string will be returned.
    public var description: String {
        guard let description = try? BSONEncoder().encode(self).description else {
            return ""
        }
        return description
    }
}

/// An extension of `ReadConcern` to make it `Equatable`.
extension ReadConcern: Equatable {
    public static func == (lhs: ReadConcern, rhs: ReadConcern) -> Bool {
        lhs.level == rhs.level
    }
}
