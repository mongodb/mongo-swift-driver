import CLibMongoC
import Foundation

/// A class to represent a MongoDB write concern.
public struct WriteConcern: Codable {
    /// Majority WriteConcern with journal and wtimeoutMS unset.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/write-concern/#writeconcern._dq_majority_dq_
    public static let majority = try! WriteConcern(w: .majority)
    // swiftlint:disable:previous force_try
    // lint disabled since the force try will throw during testing given its static

    /**
     * Returns a customized Majority WriteConcern.
     *
     * - Parameters:
     *   - wtimeoutMS: The maximum amount of time, in milliseconds, that the primary will wait for the write concern
     *   to be satisfied before returning a WriteConcernError.
     *   - journal: requests acknowledgment that the mongod instances have written to the on-disk journal.
     *
     * - SeeAlso: https://docs.mongodb.com/manual/reference/write-concern/#writeconcern._dq_majority_dq_
     */
    public static func majority(wtimeoutMS: Int? = nil, journal: Bool? = nil) throws -> WriteConcern {
        try WriteConcern(journal: journal, w: .majority, wtimeoutMS: wtimeoutMS)
    }

    /// Server default WriteConcern.
    public static let serverDefault = WriteConcern()

    /// An option to request acknowledgement that the write operation has propagated to specified mongod instances.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/write-concern/#w-option
    public enum W: Codable, Equatable {
        /// Requests acknowledgment that the write operation has propagated to the specified number of mongod
        ///  instances. MUST be greater than or equal to 0.
        case number(Int)
        /// Requests acknowledgment that write operations have propagated to the majority of the data-bearing voting
        /// members.
        case majority
        // swiftlint:disable line_length
        /// Requests acknowledgement that the write operation has propagated to tagged members that satisfy the custom
        /// write concern with the specified name.
        /// - SeeAlso: https://docs.mongodb.com/manual/reference/write-concern/#writeconcern.%3Ccustom-write-concern-name%3E
        case custom(String)
        // swiftlint:enable line_length

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = string == "majority" ? .majority : .custom(string)
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
                    throw MongoError.InvalidArgumentError(
                        message: "Invalid WriteConcern.w \(wNumber): must be between 0 and \(Int32.max)"
                    )
                }
            case let .custom(name):
                try container.encode(name)
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
    ///   - `MongoError.InvalidArgumentError` if the options form an invalid combination.
    public init(journal: Bool? = nil, w: W? = nil, wtimeoutMS: Int? = nil) throws {
        self.journal = journal

        if let wtimeoutMS = wtimeoutMS {
            if wtimeoutMS < 0 {
                throw MongoError.InvalidArgumentError(
                    message: "Invalid value: wtimeoutMS=\(wtimeoutMS) cannot be negative."
                )
            }
        }
        self.wtimeoutMS = wtimeoutMS

        if let w = w, case let .number(wNumber) = w {
            if wNumber < 0 {
                throw MongoError.InvalidArgumentError(message: "Invalid value: w=\(w) cannot be negative.")
            }
        }
        self.w = w

        guard self.isValid else {
            let journalStr = String(describing: journal)
            let wStr = String(describing: w)
            let timeoutStr = String(describing: wtimeoutMS)
            throw MongoError.InvalidArgumentError(
                message:
                "Invalid combination of options: journal=\(journalStr), w=\(wStr), wtimeoutMS=\(timeoutStr)"
            )
        }
    }

    /// Initializes a new `WriteConcern` with the same values as the provided `mongoc_write_concern_t`.
    /// The caller is responsible for freeing the original `mongoc_write_concern_t`.
    internal init(copying writeConcern: OpaquePointer) {
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
            if let name = mongoc_write_concern_get_wtag(writeConcern) {
                self.w = .custom(String(cString: name))
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
            case let .custom(name):
                mongoc_write_concern_set_wtag(writeConcern, name)
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
