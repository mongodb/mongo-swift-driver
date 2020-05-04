import CLibMongoC

/// A struct to represent a MongoDB read concern.
public struct ReadConcern: Codable {
    /// Local ReadConcern, see https://docs.mongodb.com/manual/reference/read-concern-local/.
    public static let local = ReadConcern(.local)

    /// Available ReadConcern, see https://docs.mongodb.com/manual/reference/read-concern-available/.
    public static let available = ReadConcern(.available)

    /// Linearizable ReadConcern, see https://docs.mongodb.com/manual/reference/read-concern-majority/.
    public static let linearizable = ReadConcern(.linearizable)

    /// Majority ReadConcern, see https://docs.mongodb.com/manual/reference/read-concern-linearizable/.
    public static let majority = ReadConcern(.majority)

    /// Snapshot ReadConcern, see https://docs.mongodb.com/master/reference/read-concern-snapshot/.
    public static let snapshot = ReadConcern(.snapshot)

    /// Server default ReadConcern.
    public static let serverDefault = ReadConcern(nil)

    public static func other(_ level: Level) -> ReadConcern {
        ReadConcern(level)
    }

    public static func other(_ level: String) -> ReadConcern {
        ReadConcern(Level(level))
    }

    /// An enumeration of possible ReadConcern levels.
    public struct Level: Codable, Equatable, LosslessStringConvertible {
        /// See https://docs.mongodb.com/manual/reference/read-concern-local/
        public static let local = Level("local")

        /// See https://docs.mongodb.com/manual/reference/read-concern-available/
        public static let available = Level("available")

        /// See https://docs.mongodb.com/manual/reference/read-concern-majority/
        public static let majority = Level("majority")

        /// See https://docs.mongodb.com/manual/reference/read-concern-linearizable/
        public static let linearizable = Level("linearizable")

        /// See https://docs.mongodb.com/master/reference/read-concern-snapshot/
        public static let snapshot = Level("snapshot")

        private var name: String

        /// Returns the string value of the Level for convenient conversion.
        public var description: String { "\(self.name)" }

        /// Initialize a new `Level` from `String`
        /// This initializer allows any `String` for forward compatabilty.
        public init(_ name: String) {
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

    /// The level of this `ReadConcern`, or `nil` if the level is not set.
    public var level: Level?

    /// Indicates whether this `ReadConcern` is the server default.
    public var isDefault: Bool {
        self.level == nil
    }

    // Initializes a new `ReadConcern` with the same level as the provided `mongoc_read_concern_t`.
    // The caller is responsible for freeing the original `mongoc_read_concern_t`.
    internal init(copying readConcern: OpaquePointer) {
        if let level = mongoc_read_concern_get_level(readConcern) {
            self.level = Level(String(cString: level))
        }
    }

    /// Initialize a new `ReadConcern` with a `Level`.
    fileprivate init(_ level: Level?) {
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
            mongoc_read_concern_set_level(readConcern, String(level))
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
