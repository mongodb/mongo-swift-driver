import mongoc

/// A struct to represent a MongoDB read concern.
public struct ReadConcern: Codable {
    /// An enumeration of possible ReadConcern levels.
    public enum Level: String, Encodable {
        /// See https://docs.mongodb.com/manual/reference/read-concern-local/
        case local
        /// See https://docs.mongodb.com/manual/reference/read-concern-available/
        case available
        /// See https://docs.mongodb.com/manual/reference/read-concern-majority/
        case majority
        /// See https://docs.mongodb.com/manual/reference/read-concern-linearizable/
        case linearizable
        /// See https://docs.mongodb.com/master/reference/read-concern-snapshot/
        case snapshot
    }

    /// The level of this `ReadConcern`, or `nil` if the level is not set.
    public var level: Level?

    /// Indicates whether this `ReadConcern` is the server default.
    public var isDefault: Bool {
       if level == nil {
           return true
       }
       return false
    }

    /// A pointer to a `mongoc_read_concern_t`.
    internal var _readConcern: OpaquePointer?

    /// Initializes a new `ReadConcern` by copying a `mongoc_read_concern_t`.
    /// The caller is responsible for freeing the original `mongoc_read_concern_t`.
    public init(from readConcern: OpaquePointer) {
        if let level = mongoc_read_concern_get_level(self._readConcern) {
            self.level = Level(rawValue: String(cString: level))
        }
    }

    /// Initializes a new `ReadConcern` by copying an existing `ReadConcern`.
    public init(from readConcern: ReadConcern) {
        self.level = readConcern.level
    }

    /// Initialize a new `ReadConcern` with a `Level`.
    public init(_ level: Level) {
        self.level = level
    }

    /// Initialize a new `ReadConcern` from a `String` corresponding to a read concern level.
    public init(_ level: String) {
        self.level = Level(rawValue: level)
    }

    /// Initialize a new empty `ReadConcern`.
    public init() {
        self.level = nil
    }

    /// Initializes a new `ReadConcern` from a `Document`.
    public init(_ doc: Document) {
        if let level = doc["level"] as? String {
            self.init(level)
        } else {
            self.init()
        }
    }

    private enum CodingKeys: String, CodingKey {
        case level
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let level = try container.decodeIfPresent(String.self, forKey: .level) {
            self.init(level)
        } else {
            self.init()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.level, forKey: .level)
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
        return lhs.level == rhs.level
    }
}
