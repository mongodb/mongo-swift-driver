import Foundation
import libmongoc

/// A class to represent a MongoDB write concern.
public class WriteConcern: Codable {

    /// A pointer to a mongoc_write_concern_t
    internal var _writeConcern: OpaquePointer?

    /// An option to request acknowledgement that the write operation has propagated to specified mongod instances.
    public enum W: Codable, Equatable {
        /// Specifies the number of nodes that should acknowledge the write. MUST be greater than or equal to 0.
        case number(Int32)
        /// Indicates a tag for nodes that should acknowledge the write. 
        case tag(String)
        /// Specifies that a majority of nodes should acknowledge the write.
        case majority

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = string == "majority" ? .majority : .tag(string)
            } else {
                let wNumber = try container.decode(Int32.self)
                self = .number(wNumber)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .number(wNumber):
                try container.encode(wNumber)
            case let .tag(wTag):
                try container.encode(wTag)
            case .majority:
                try container.encode("majority")
            }
        }

        public static func == (lhs: W, rhs: W) -> Bool {
            switch (lhs, rhs) {
            case let (.number(lNum), .number(rNum)):
                return lNum == rNum
            case let (.tag(lTag), .tag(rTag)):
                return lTag == rTag
            case (.majority, .majority):
                return true
            default:
                return false
            }
        }
    }

    /// Indicates the `W` value for this `WriteConcern`.
    public var w: W? {
        let number = mongoc_write_concern_get_w(self._writeConcern)
        switch number {
        case MONGOC_WRITE_CONCERN_W_DEFAULT:
            return nil
        case MONGOC_WRITE_CONCERN_W_MAJORITY:
            return .majority
        case MONGOC_WRITE_CONCERN_W_TAG:
            if let wTag = mongoc_write_concern_get_wtag(self._writeConcern) {
                return .tag(String(cString: wTag))
            }
        default:
            break
        }

        return .number(number)
    }

    /// Indicates whether to wait for the write operation to get committed to the journal.
    public var journal: Bool? {
        if mongoc_write_concern_journal_is_set(self._writeConcern) {
            return mongoc_write_concern_get_journal(self._writeConcern)
        }
        return nil
    }

    /// If the write concern is not satisfied within this timeout (in milliseconds),
    /// the operation will return an error. The value MUST be greater than or equal to 0.
    public var wtimeoutMS: Int32? {
        let timeout = mongoc_write_concern_get_wtimeout(self._writeConcern)
        if timeout == 0 { return nil }
        return timeout
    }

    /// Indicates whether this is an acknowledged write concern.
    public var isAcknowledged: Bool {
        return mongoc_write_concern_is_acknowledged(self._writeConcern)
    }

    /// Indicates whether this is the default write concern.
    public var isDefault: Bool {
        return mongoc_write_concern_is_default(self._writeConcern)
    }

    /// Indicates whether the combination of values set on this `WriteConcern` is valid.
    private var isValid: Bool {
        return mongoc_write_concern_is_valid(self._writeConcern)
    }

    /// Initializes a new, empty `WriteConcern`.
    public init() {
        self._writeConcern = mongoc_write_concern_new()
    }

    /// Initializes a new `WriteConcern`.
    public init(journal: Bool? = nil, w: W? = nil, wtimeoutMS: Int32? = nil) throws {
        self._writeConcern = mongoc_write_concern_new()
        if let journal = journal { mongoc_write_concern_set_journal(self._writeConcern, journal) }
        if let wtimeoutMS = wtimeoutMS { mongoc_write_concern_set_wtimeout(self._writeConcern, wtimeoutMS) }

        if let w = w {
            switch w {
            case let .number(wNumber):
                mongoc_write_concern_set_w(self._writeConcern, wNumber)
            case let .tag(wTag):
                mongoc_write_concern_set_wtag(self._writeConcern, wTag)
            case .majority:
                mongoc_write_concern_set_w(self._writeConcern, MONGOC_WRITE_CONCERN_W_MAJORITY)
            }
        }

        // we don't need to destroy the `mongoc_write_concern_t` here - `deinit` will be called anyway
        if !self.isValid {
            let journalStr = String(describing: journal)
            let wStr = String(describing: w)
            let timeoutStr = String(describing: wtimeoutMS)
            throw MongoError.invalidArgument(message:
                "Invalid combination of options: journal=\(journalStr), w=\(wStr), wtimeoutMS=\(timeoutStr)")
        }
    }

    /// Initializes a new `WriteConcern` by copying a `mongoc_write_concern_t`.
    /// The caller is responsible for freeing the original `mongoc_write_concern_t`.
    internal init(_ writeConcern: OpaquePointer?) {
        self._writeConcern = mongoc_write_concern_copy(writeConcern)
    }

    private enum CodingKeys: String, CodingKey {
        case w, j, wtimeout
    }

    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let w = try container.decodeIfPresent(W.self, forKey: .w)
        let journal = try container.decodeIfPresent(Bool.self, forKey: .j)
        let wtimeoutMS = try container.decodeIfPresent(Int32.self, forKey: .wtimeout)
        try self.init(journal: journal, w: w, wtimeoutMS: wtimeoutMS)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.w, forKey: .w)
        try container.encodeIfPresent(self.wtimeoutMS, forKey: .wtimeout)
        try container.encodeIfPresent(self.journal, forKey: .j)
    }

    deinit {
        guard let writeConcern = self._writeConcern else { return }
        mongoc_write_concern_destroy(writeConcern)
        self._writeConcern = nil
    }
}

/// An extension of `WriteConcern` to make it `CustomStringConvertible`.
extension WriteConcern: CustomStringConvertible {
    /// Returns the relaxed extended JSON representation of this `WriteConcern`.
    /// On error, an empty string will be returned.
    public var description: String {
        guard let description = try? BsonEncoder().encode(self).description else {
            return ""
        }
        return description
    }
}

/// An extension of `WriteConcern` to make it `Equatable`.
extension WriteConcern: Equatable {
    public static func == (lhs: WriteConcern, rhs: WriteConcern) -> Bool {
        return lhs.description == rhs.description
    }
}
