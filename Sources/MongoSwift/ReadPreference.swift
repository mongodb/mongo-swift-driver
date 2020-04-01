import CLibMongoC

/// Represents a MongoDB read preference, indicating which member(s) of a replica set read operations should be
/// directed to.
/// - SeeAlso: https://docs.mongodb.com/manual/reference/read-preference/
public struct ReadPreference {
    /// An enumeration of possible read preference modes.
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-preference/#read-preference-modes
    public enum Mode: String {
        /// Default mode. All operations read from the current replica set primary.
        case primary
        /// In most situations, operations read from the primary but if it is unavailable, operations read from
        /// secondary members.
        case primaryPreferred
        /// All operations read from the secondary members of the replica set.
        case secondary
        /// In most situations, operations read from secondary members but if no secondary members are available,
        /// operations read from the primary.
        case secondaryPreferred
        /// Operations read from the member of the replica set with the least network latency, irrespective of the
        /// member's type.
        case nearest

        fileprivate var mongocMode: mongoc_read_mode_t {
            switch self {
            case .primary:
                return MONGOC_READ_PRIMARY
            case .primaryPreferred:
                return MONGOC_READ_PRIMARY_PREFERRED
            case .secondary:
                return MONGOC_READ_SECONDARY
            case .secondaryPreferred:
                return MONGOC_READ_SECONDARY_PREFERRED
            case .nearest:
                return MONGOC_READ_NEAREST
            }
        }

        fileprivate init(mongocMode: mongoc_read_mode_t) {
            switch mongocMode {
            case MONGOC_READ_PRIMARY:
                self = .primary
            case MONGOC_READ_PRIMARY_PREFERRED:
                self = .primaryPreferred
            case MONGOC_READ_SECONDARY:
                self = .secondary
            case MONGOC_READ_SECONDARY_PREFERRED:
                self = .secondaryPreferred
            case MONGOC_READ_NEAREST:
                self = .nearest
            default:
                fatalError("Unexpected read preference mode: \(mongocMode)")
            }
        }
    }

    /// The mode specified for this read preference.
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-preference/#read-preference-modes
    public var mode: Mode {
        self.mongocReadPreference.mode
    }

    /// Optionally specified tag sets, indicating a member or members of a replica set to target.
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-preference-tags/#replica-set-read-preference-tag-sets
    public var tagSets: [Document]? {
        self.mongocReadPreference.tagSets
    }

    // swiftlint:disable line_length
    /// An optionally specified value indicating a maximum replication lag, or "staleness", for reads from secondaries.
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-preference-staleness/#replica-set-read-preference-max-staleness
    public var maxStalenessSeconds: Int? {
        self.mongocReadPreference.maxStalenessSeconds
    }
    // swiftlint:enable line_length

    /// A `ReadPreference` with mode `primary`. This is the default mode. With this mode, all operations read from the
    /// current replica set primary.
    public static let primary = ReadPreference(.primary)
    /// A `ReadPreference` with mode `primaryPreferred`. With this mode, in most situations, operations read from the
    /// primary but if it is unavailable, operations read from secondary members.
    public static let primaryPreferred = ReadPreference(.primaryPreferred)
    /// A `ReadPreference` with mode `secondary`. With this mode, all operations read from secondary members of the
    /// replica set.
    public static let secondary = ReadPreference(.secondary)
    /// A `ReadPreference` with mode `secondaryPreferred`. With this mode, in most situations, operations read from
    /// secondary members, but if no secondary members are available, operations read from the primary.
    public static let secondaryPreferred = ReadPreference(.secondaryPreferred)
    /// A `ReadPreference` with mode `nearest`. With this mode, operations read from the member of the replica set with
    /// the least network latency, irrespective of the member’s type.
    public static let nearest = ReadPreference(.nearest)

    /**
     * Initializes a new `ReadPreference` with the mode `primaryPreferred`. With this mode, in most situations,
     * operations read from the primary but if it is unavailable, operations read from secondary members.
     *
     * - Parameters:
     *   - tagSets: an optional `[Document]`, indicating a member or members of a replica set to target.
     *   - maxStalenessSeconds: an optional `Int`, indicating a maximum replication lag, or "staleness", for reads from
     *     secondaries.
     *
     * - Throws:
     *   - `InvalidArgumentError` if `maxStalenessSeconds` is non-nil and < 90.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/read-preference/#primaryPreferred
     *   - https://docs.mongodb.com/manual/core/read-preference-tags/#replica-set-read-preference-tag-sets
     *   - https://docs.mongodb.com/manual/core/read-preference-staleness/#replica-set-read-preference-max-staleness
     */
    public static func primaryPreferred(
        tagSets: [Document]? = nil,
        maxStalenessSeconds: Int? = nil
    ) throws -> ReadPreference {
        try ReadPreference(.primaryPreferred, tagSets: tagSets, maxStalenessSeconds: maxStalenessSeconds)
    }

    /**
     * Initializes a new `ReadPreference` with the mode `secondary`. With this mode, all operations read from the
     * secondary members of the replica set.
     *
     * - Parameters:
     *   - tagSets: an optional `[Document]`, indicating a member or members of a replica set to target.
     *   - maxStalenessSeconds: an optional `Int`, indicating a maximum replication lag, or "staleness", for reads from
     *     secondaries.
     *
     * - Throws:
     *   - `InvalidArgumentError` if `maxStalenessSeconds` is non-nil and < 90.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/read-preference/#secondary
     *   - https://docs.mongodb.com/manual/core/read-preference-tags/#replica-set-read-preference-tag-sets
     *   - https://docs.mongodb.com/manual/core/read-preference-staleness/#replica-set-read-preference-max-staleness
     */
    public static func secondary(
        tagSets: [Document]? = nil,
        maxStalenessSeconds: Int? = nil
    ) throws -> ReadPreference {
        try ReadPreference(.secondary, tagSets: tagSets, maxStalenessSeconds: maxStalenessSeconds)
    }

    /**
     * Initializes a new `ReadPreference` with the mode `secondaryPreferred`. With this mode, in most situations,
     * operations read from secondary members but if no secondary members are available, operations read from the
     * primary.
     *
     * - Parameters:
     *   - tagSets: an optional `[Document]`, indicating a member or members of a replica set to target.
     *   - maxStalenessSeconds: an optional `Int`, indicating a maximum replication lag, or "staleness", for reads from
     *     secondaries.
     *
     * - Throws:
     *   - `InvalidArgumentError` if `maxStalenessSeconds` is non-nil and < 90.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/read-preference/#secondaryPreferred
     *   - https://docs.mongodb.com/manual/core/read-preference-tags/#replica-set-read-preference-tag-sets
     *   - https://docs.mongodb.com/manual/core/read-preference-staleness/#replica-set-read-preference-max-staleness
     */
    public static func secondaryPreferred(
        tagSets: [Document]? = nil,
        maxStalenessSeconds: Int? = nil
    ) throws -> ReadPreference {
        try ReadPreference(.secondaryPreferred, tagSets: tagSets, maxStalenessSeconds: maxStalenessSeconds)
    }

    /**
     * Initializes a new `ReadPreference` with the mode `nearest`. With this mode, operations read from the member of
     * the replica set with the least network latency, irrespective of the member’s type.
     *
     * - Parameters:
     *   - tagSets: an optional `[Document]`, indicating a member or members of a replica set to target.
     *   - maxStalenessSeconds: an optional `Int`, indicating a maximum replication lag, or "staleness", for reads from
     *     secondaries.
     *
     * - Throws:
     *   - `InvalidArgumentError` if `maxStalenessSeconds` is non-nil and < 90.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/read-preference/#nearest
     *   - https://docs.mongodb.com/manual/core/read-preference-tags/#replica-set-read-preference-tag-sets
     *   - https://docs.mongodb.com/manual/core/read-preference-staleness/#replica-set-read-preference-max-staleness
     */
    public static func nearest(
        tagSets: [Document]? = nil,
        maxStalenessSeconds: Int? = nil
    ) throws -> ReadPreference {
        try ReadPreference(.nearest, tagSets: tagSets, maxStalenessSeconds: maxStalenessSeconds)
    }

    /// An equivalent libmongoc read preference used for libmongoc interop. NOTE: If we were ever to allow mutating the
    /// properties of `ReadPreference` after initialization, we would need to implement copy-on-write semantics for
    /// this type to prevent multiple `ReadPreference`s from being backed by the same `MongocReadPreference`. Since
    /// this type is currently immutable it's ok that copies may share the same libmongoc type.
    private let mongocReadPreference: MongocReadPreference

    /// Provides internal access to the underlying libmongoc object.
    internal var pointer: OpaquePointer {
        self.mongocReadPreference.readPref
    }

    /// Initializes a `ReadPreference` from a `Mode`.
    internal init(_ mode: Mode) {
        self.mongocReadPreference = MongocReadPreference(mode)
    }

    internal init(_ mode: Mode, tagSets: [Document]?, maxStalenessSeconds: Int?) throws {
        self.mongocReadPreference = try MongocReadPreference(
            mode: mode,
            tagSets: tagSets,
            maxStalenessSeconds: maxStalenessSeconds
        )
    }

    /// Initializes a new `ReadPreference` by copying a `mongoc_read_prefs_t`. Does not free the original.
    internal init(copying pointer: OpaquePointer) {
        self.mongocReadPreference = MongocReadPreference(copying: pointer)
    }
}

/// An extension of `ReadPreference` to make it `Equatable`.
extension ReadPreference: Equatable {
    public static func == (lhs: ReadPreference, rhs: ReadPreference) -> Bool {
        lhs.mode == rhs.mode &&
        lhs.tagSets == rhs.tagSets &&
        lhs.maxStalenessSeconds == rhs.maxStalenessSeconds
    }
}

/// A class wrapping a `mongoc_read_prefs_t`.
private class MongocReadPreference {
    /// Pointer to underlying `mongoc_read_prefs_t`.
    fileprivate let readPref: OpaquePointer

    fileprivate init(_ mode: ReadPreference.Mode) {
        self.readPref = mongoc_read_prefs_new(mode.mongocMode)
    }

    fileprivate init(copying pointer: OpaquePointer) {
        self.readPref = mongoc_read_prefs_copy(pointer)
    }

    fileprivate convenience init(mode: ReadPreference.Mode, tagSets: [Document]?, maxStalenessSeconds: Int?) throws {
        self.init(mode)

        if let tagSets = tagSets, !tagSets.isEmpty {
            let tags = Document(tagSets.map { .document($0) })
            mongoc_read_prefs_set_tags(self.readPref, tags._bson)
        }

        if let maxStalenessSeconds = maxStalenessSeconds {
            guard maxStalenessSeconds >= MONGOC_SMALLEST_MAX_STALENESS_SECONDS else {
                throw InvalidArgumentError(
                    message: "Expected maxStalenessSeconds to be >= " +
                        " \(MONGOC_SMALLEST_MAX_STALENESS_SECONDS), \(maxStalenessSeconds) given"
                )
            }
            mongoc_read_prefs_set_max_staleness_seconds(self.readPref, Int64(maxStalenessSeconds))
        }
    }

    fileprivate var mode: ReadPreference.Mode {
        ReadPreference.Mode(mongocMode: mongoc_read_prefs_get_mode(self.readPref))
    }

    fileprivate var tagSets: [Document]? {
        guard let bson = mongoc_read_prefs_get_tags(self.readPref) else {
            fatalError("Failed to retrieve read preference tags")
        }
        // we have to copy because libmongoc owns the pointer.
        let wrapped = Document(copying: bson)

        guard !wrapped.isEmpty else {
            return nil
        }

        // swiftlint:disable:next force_unwrapping
        return wrapped.values.map { $0.documentValue! } // libmongoc will always give us an array of documents
    }

    fileprivate var maxStalenessSeconds: Int? {
        let maxStaleness = mongoc_read_prefs_get_max_staleness_seconds(self.readPref)
        return maxStaleness == MONGOC_NO_MAX_STALENESS ? nil : Int(exactly: maxStaleness)
    }

    deinit {
        mongoc_read_prefs_destroy(readPref)
    }
}
