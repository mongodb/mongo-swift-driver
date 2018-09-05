import libmongoc

/**
 * A class to represent a MongoDB read preference.
 *
 * - SeeAlso: https://docs.mongodb.com/manual/reference/read-preference/
 */
public final class ReadPreference {

    /// An enumeration of possible ReadPreference modes.
    public enum Mode: String {
        case primary
        case primaryPreferred
        case secondary
        case secondaryPreferred
        case nearest

        internal var readMode: mongoc_read_mode_t {
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

        internal init(readMode: mongoc_read_mode_t) {
            switch readMode {
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
                preconditionFailure("Unexpected read preference mode: \(readMode)")
            }
        }
    }

    /// A pointer to a `mongoc_read_prefs_t`.
    internal var _readPreference: OpaquePointer?

    /// The mode of this `ReadPreference`
    public var mode: Mode {
        let readMode = mongoc_read_prefs_get_mode(self._readPreference)

        return Mode(readMode: readMode)
    }

    /// The tags of this `ReadPreference`
    public var tagSets: [Document] {
        guard let bson = mongoc_read_prefs_get_tags(self._readPreference) else {
            preconditionFailure("Failed to retrieve read preference tags")
        }

        let wrapped = Document(fromPointer: bson)

        // swiftlint:disable:next force_cast
        return wrapped.values as! [Document]
    }

    /// The maxStalenessSeconds of this `ReadPreference`
    public var maxStalenessSeconds: Int64? {
        let maxStalenessSeconds = mongoc_read_prefs_get_max_staleness_seconds(self._readPreference)

        return maxStalenessSeconds == MONGOC_NO_MAX_STALENESS ? nil : maxStalenessSeconds
    }

    /**
     * Initializes a `ReadPreference` from a `Mode`.
     *
     * - Parameters:
     *   - mode: a `Mode`
     *
     * - Returns: a new `ReadPreference`
     */
    public init(_ mode: Mode) {
        self._readPreference = mongoc_read_prefs_new(mode.readMode)
    }

    /**
     * Initializes a `ReadPreference`.
     *
     * - Parameters:
     *   - mode: a `Mode`
     *   - tagSets: an optional `[Document]`
     *   - maxStalenessSeconds: an optional `Int64`
     *
     * - Returns: a new `ReadPreference`
     *
     * - Throws:
     *   - A `MongoError.readPreferenceError` if `mode` is `.primary` and `tagSets` is non-empty
     *   - A `MongoError.readPreferenceError` if `maxStalenessSeconds` non-nil and < 90
     */
    public init(_ mode: Mode, tagSets: [Document]? = nil, maxStalenessSeconds: Int64? = nil) throws {
        self._readPreference = mongoc_read_prefs_new(mode.readMode)

        if let tagSets = tagSets {
            guard mode != .primary || tagSets.isEmpty else {
                throw MongoError.readPreferenceError(message: "tagSets may not be used with primary mode")
            }

            let encoder = BsonEncoder()
            let tags = try encoder.encode(Document(tagSets))
            mongoc_read_prefs_set_tags(self._readPreference, tags.data)
        }

        if let maxStalenessSeconds = maxStalenessSeconds {
            guard maxStalenessSeconds >= MONGOC_SMALLEST_MAX_STALENESS_SECONDS else {
                throw MongoError.readPreferenceError(message: "Expected maxStalenessSeconds to be >= " +
                    " \(MONGOC_SMALLEST_MAX_STALENESS_SECONDS), \(maxStalenessSeconds) given")
            }

            mongoc_read_prefs_set_max_staleness_seconds(self._readPreference, maxStalenessSeconds)
        }
    }

    /// Initializes a new `ReadPreference` by copying an existing `ReadPreference`.
    public init(from readPreference: ReadPreference) {
        self._readPreference = mongoc_read_prefs_copy(readPreference._readPreference)
    }

    /// Initializes a new `ReadPreference` by copying a `mongoc_read_prefs_t`.
    /// The caller is responsible for freeing the original `mongoc_read_prefs_t`.
    internal init(from readPreference: OpaquePointer?) {
        self._readPreference = mongoc_read_prefs_copy(readPreference)
    }

    /// Cleans up the internal `mongoc_read_prefs_t`.
    deinit {
        guard let readPreference = self._readPreference else { return }
        mongoc_read_prefs_destroy(readPreference)
        self._readPreference = nil
    }
}

/// An extension of `ReadPreference` to make it `Equatable`.
extension ReadPreference: Equatable {
    public static func == (lhs: ReadPreference, rhs: ReadPreference) -> Bool {
        return lhs.mode == rhs.mode && lhs.tagSets == rhs.tagSets &&
            lhs.maxStalenessSeconds == rhs.maxStalenessSeconds
    }
}
