import CLibMongoC
import Foundation

/// A class to represent a MongoDB write concern.
public struct WriteConcern: Codable {
    /// An option to request acknowledgement that the write operation has propagated to specified mongod instances.
    public enum W: Codable, Equatable {
        /// Specifies the number of nodes that should acknowledge the write. MUST be greater than or equal to 0.
        case number(Int)
        /// Indicates a tag for nodes that should acknowledge the write.
        case tag(String)
        /// Specifies that a majority of nodes should acknowledge the write.
        case majority

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = string == "majority" ? .majority : .tag(string)
            } else {
                let wNumber = try container.decode(Int.self)
                self = .number(wNumber)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .number(wNumber):
                if let wNumber = Int32(exactly: wNumber) {
                    // Int size check is required by libmongoc
                    try container.encode(wNumber)
                } else {
                    throw InvalidArgumentError(
                        message: "Invalid WriteConcern.w \(wNumber): must be between \(Int32.min) and \(Int32.max)"
                    )
                }
            case let .tag(wTag):
                try container.encode(wTag)
            case .majority:
                try container.encode("majority")
            }
        }
    }

    /// Indicates the `W` value for this `WriteConcern`.
    public let w: W?

    /// Indicates whether to wait for the write operation to get committed to the journal.
    public let journal: Bool?

    /// If the write concern is not satisfied within this timeout (in milliseconds),
    /// the operation will return an error. The value MUST be greater than or equal to 0.
    public let wtimeoutMS: Int?

    /// Indicates whether this is an acknowledged write concern.
    public var isAcknowledged: Bool {
        // An Unacknowledged WriteConcern is when (w equals 0) AND (journal is not set or is false).
        if let w = self.w, case let .number(wNumber) = w {
            return !((self.journal == nil || self.journal == false) && wNumber == 0)
        }
        return true
    }

    /// Indicates whether this is the default write concern.
    public var isDefault: Bool {
        self.w == nil && self.journal == nil && self.wtimeoutMS == nil
    }

    /// Indicates whether the combination of values set on this `WriteConcern` is valid.
    private var isValid: Bool {
        if let w = self.w, case let .number(wNumber) = w {
            // A WriteConcern is invalid if journal is set to true and w is equal to zero.
            return self.journal == nil || self.journal == false || wNumber != 0
        }
        return true
    }

    /// Initializes a new, empty `WriteConcern`.
    public init() {
        self.journal = nil
        self.w = nil
        self.wtimeoutMS = nil
    }

    /// Initializes a new `WriteConcern`.
    /// - Throws:
    ///   - `InvalidArgumentError` if the options form an invalid combination.
    public init(journal: Bool? = nil, w: W? = nil, wtimeoutMS: Int? = nil) throws {
        self.journal = journal

        if let wtimeoutMS = wtimeoutMS {
            if wtimeoutMS < 0 {
                throw InvalidArgumentError(message: "Invalid value: wtimeoutMS=\(wtimeoutMS) cannot be negative.")
            }
        }
        self.wtimeoutMS = wtimeoutMS

        if let w = w, case let .number(wNumber) = w {
            if wNumber < 0 {
                throw InvalidArgumentError(message: "Invalid value: w=\(w) cannot be negative.")
            }
        }
        self.w = w

        guard self.isValid else {
            let journalStr = String(describing: journal)
            let wStr = String(describing: w)
            let timeoutStr = String(describing: wtimeoutMS)
            throw InvalidArgumentError(
                message:
                "Invalid combination of options: journal=\(journalStr), w=\(wStr), wtimeoutMS=\(timeoutStr)"
            )
        }
    }

    /// Initializes a new `WriteConcern` with the same values as the provided `mongoc_write_concern_t`.
    /// The caller is responsible for freeing the original `mongoc_write_concern_t`.
    internal init(from writeConcern: OpaquePointer?) {
        if mongoc_write_concern_journal_is_set(writeConcern) {
            self.journal = mongoc_write_concern_get_journal(writeConcern)
        } else {
            self.journal = nil
        }

        let number = mongoc_write_concern_get_w(writeConcern)
        switch number {
        case MONGOC_WRITE_CONCERN_W_DEFAULT:
            self.w = nil
        case MONGOC_WRITE_CONCERN_W_MAJORITY:
            self.w = .majority
        case MONGOC_WRITE_CONCERN_W_TAG:
            if let wTag = mongoc_write_concern_get_wtag(writeConcern) {
                self.w = .tag(String(cString: wTag))
            } else {
                self.w = nil
            }
        default:
            self.w = .number(Int(number))
        }

        let wtimeout = Int(mongoc_write_concern_get_wtimeout_int64(writeConcern))
        if wtimeout != 0 {
            self.wtimeoutMS = wtimeout
        } else {
            self.wtimeoutMS = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case w, journal = "j", wtimeoutMS = "wtimeout"
    }

    /**
     *  Creates a new `mongoc_write_concern_t` based on this `WriteConcern` and passes it to the provided closure.
     *  The pointer is only valid within the body of the closure and will be freed after the body completes.
     */
    internal func withMongocWriteConcern<T>(_ body: (OpaquePointer) throws -> T) rethrows -> T {
        let writeConcern: OpaquePointer = mongoc_write_concern_new()
        defer { mongoc_write_concern_destroy(writeConcern) }
        if let journal = self.journal {
            mongoc_write_concern_set_journal(writeConcern, journal)
        }
        if let w = self.w {
            switch w {
            case let .number(wNumber):
                mongoc_write_concern_set_w(writeConcern, Int32(wNumber))
            case let .tag(wTag):
                mongoc_write_concern_set_wtag(writeConcern, wTag)
            case .majority:
                mongoc_write_concern_set_w(writeConcern, MONGOC_WRITE_CONCERN_W_MAJORITY)
            }
        }
        if let wtimeoutMS = self.wtimeoutMS {
            mongoc_write_concern_set_wtimeout_int64(writeConcern, Int64(wtimeoutMS))
        }
        return try body(writeConcern)
    }
}

/// An extension of `WriteConcern` to make it `CustomStringConvertible`.
extension WriteConcern: CustomStringConvertible {
    /// Returns the relaxed extended JSON representation of this `WriteConcern`.
    /// On error, an empty string will be returned.
    public var description: String {
        guard let description = try? BSONEncoder().encode(self).description else {
            return ""
        }
        return description
    }
}

/// An extension of `WriteConcern` to make it `Equatable`.
extension WriteConcern: Equatable {
    public static func == (lhs: WriteConcern, rhs: WriteConcern) -> Bool {
        lhs.description == rhs.description
    }
}
