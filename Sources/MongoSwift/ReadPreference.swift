import CLibMongoC

/// Represents a MongoDB read preference, indicating which member(s) of a replica set read operations should be
/// directed to.
/// - SeeAlso: https://docs.mongodb.com/manual/reference/read-preference/
public struct ReadPreference: Equatable {
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
    public var mode: Mode

    /// Optionally specified ordered array of tag sets. If provided, a server will only be considered suitable if its
    /// tags are a superset of at least one of the tag sets.
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-preference-tags/#replica-set-read-preference-tag-sets
    public var tagSets: [Document]?

    // swiftlint:disable line_length
    /// An optionally specified value indicating a maximum replication lag, or "staleness", for reads from secondaries.
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-preference-staleness/#replica-set-read-preference-max-staleness
    public var maxStalenessSeconds: Int?
    // swiftlint:enable line_length

    /// A `ReadPreference` with mode `primary`. This is the default mode. With this mode, all operations read from the
    /// current replica set primary.
    public static let primary = ReadPreference(.primary)
    /// A `ReadPreference` with mode `primaryPreferred`. With this mode, in most situations operations read from the
    /// primary, but if it is unavailable, operations read from secondary members.
    public static let primaryPreferred = ReadPreference(.primaryPreferred)
    /// A `ReadPreference` with mode `secondary`. With this mode, all operations read from secondary members of the
    /// replica set.
    public static let secondary = ReadPreference(.secondary)
    /// A `ReadPreference` with mode `secondaryPreferred`. With this mode, in most situations operations read from
    /// secondary members, but if no secondary members are available, operations read from the primary.
    public static let secondaryPreferred = ReadPreference(.secondaryPreferred)
    /// A `ReadPreference` with mode `nearest`. With this mode, operations read from the member of the replica set with
    /// the least network latency, irrespective of the member’s type.
    public static let nearest = ReadPreference(.nearest)

    /**
     * Initializes a new `ReadPreference` with the mode `primaryPreferred`. With this mode, in most situations
     * operations read from the primary, but if it is unavailable, operations read from secondary members.
     *
     * - Parameters:
     *   - tagSets: an optional `[Document]`, containing an ordered array of tag sets. If provided, a server will only
     *     be considered suitable if its tags are a superset of at least one of the tag sets.
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
     *   - tagSets: an optional `[Document]`, containing an ordered array of tag sets. If provided, a server will only
     *     be considered suitable if its tags are a superset of at least one of the tag sets.
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
     *   - tagSets: an optional `[Document]`, containing an ordered array of tag sets. If provided, a server will only
     *     be considered suitable if its tags are a superset of at least one of the tag sets.
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
     *   - tagSets: an optional `[Document]`, containing an ordered array of tag sets. If provided, a server will only
     *     be considered suitable if its tags are a superset of at least one of the tag sets.
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

    /// Initializes a `ReadPreference` from a `Mode`.
    internal init(_ mode: Mode) {
        self.mode = mode
        self.tagSets = nil
        self.maxStalenessSeconds = nil
    }

    private init(_ mode: Mode, tagSets: [Document]?, maxStalenessSeconds: Int?) throws {
        if let maxStaleness = maxStalenessSeconds {
            guard maxStaleness >= MONGOC_SMALLEST_MAX_STALENESS_SECONDS else {
                throw InvalidArgumentError(
                    message: "Expected maxStalenessSeconds to be >= " +
                        " \(MONGOC_SMALLEST_MAX_STALENESS_SECONDS), \(maxStaleness) given"
                )
            }
        }
        self.mode = mode
        self.tagSets = tagSets
        self.maxStalenessSeconds = maxStalenessSeconds
    }

    /// Initializes a new `ReadPreference` by copying a `mongoc_read_prefs_t`. Does not free the original.
    internal init(copying pointer: OpaquePointer) {
        self.mode = Mode(mongocMode: mongoc_read_prefs_get_mode(pointer))

        guard let tagsPointer = mongoc_read_prefs_get_tags(pointer) else {
            fatalError("Failed to retrieve read preference tags")
        }
        // we have to copy because libmongoc owns the pointer.
        let wrappedTags = Document(copying: tagsPointer)
        if !wrappedTags.isEmpty {
            // swiftlint:disable:next force_unwrapping
            self.tagSets = wrappedTags.values.map { $0.documentValue! } // libmongoc will always return array of docs
        }

        let maxStalenessValue = mongoc_read_prefs_get_max_staleness_seconds(pointer)
        if maxStalenessValue != MONGOC_NO_MAX_STALENESS {
            self.maxStalenessSeconds = Int(exactly: maxStalenessValue)
        }
    }

    internal func withMongocReadPreference<T>(body: (OpaquePointer) throws -> T) rethrows -> T {
        // swiftlint:disable:next force_unwrapping
        let rp = mongoc_read_prefs_new(self.mode.mongocMode)! // never returns nil
        defer { mongoc_read_prefs_destroy(rp) }

        if let tagSets = self.tagSets, !tagSets.isEmpty {
            let tags = Document(tagSets.map { .document($0) })
            tags.withBSONPointer { tagsPtr in
                mongoc_read_prefs_set_tags(rp, tagsPtr)
            }
        }

        if let maxStaleness = self.maxStalenessSeconds {
            mongoc_read_prefs_set_max_staleness_seconds(rp, Int64(maxStaleness))
        }

        return try body(rp)
    }
}

internal func withOptionalMongocReadPreference<T>(
    from rp: ReadPreference?,
    body: (OpaquePointer?) throws -> T
) rethrows -> T {
    guard let rp = rp else {
        return try body(nil)
    }
    return try rp.withMongocReadPreference(body: body)
}
