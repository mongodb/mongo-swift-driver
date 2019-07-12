/// Describes the modes for configuring the fullDocument field of a
/// `ChangeStreamDocument`.
public enum FullDocument: RawRepresentable, Codable {
    /// The change stream document will include both a delta describing the
    /// changes to the document, as well as a copy of the entire document that
    /// was changed from some time after the change occurred.
    case updateLookup
    /// For an unknown value. For forwards compatibility, no error will be
    /// thrown when an unknown value is provided.
    case other(String)

    public var rawValue: String {
        switch self {
        case .updateLookup:
            return "updateLookup"
        case .other(let v):
            return v
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "updateLookup":
            self = .updateLookup
        default:
            self = .other(rawValue)
        }
    }
}

/// Options to use when creating a `ChangeStream`.
public struct ChangeStreamOptions: Codable {
    /**
     * Indicates how the `fullDocument` field of a `ChangeStreamDocument` should be filled out by the server.
     * By default (indicated by a nil value for this option), the fullDocument field in the change stream document
     * will always be present in the case of 'insert' and 'replace' operations (containing the document being inserted)
     * and will be nil for all other operations.
     */
    public let fullDocument: FullDocument?

    /// A `ChangeStreamToken` used to manually specify the logical starting point for the new change stream.
    public let resumeAfter: ChangeStreamToken?

    /// The maximum amount of time in milliseconds for the server to wait on new documents
    // to satisfy a change stream query. Uses the server default timeout when omitted.
    public let maxAwaitTimeMS: Int64?

    /**
     * The number of documents to return per batch. This option is sent only if the caller explicitly provides a value.
     * The default is to not send a value.
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/aggregate
     */
    public let batchSize: Int32?

    /**
     * Specifies a collation.
     * This option is sent only if the caller explicitly provides a value. The
     * default is to not send a value.
     * - SeeAlso: https://docs.mongodb.com/manual/reference/command/aggregate
     */
    public let collation: Document?

    /**
     * The change stream will only provide changes that occurred at or after
     * the specified timestamp. Any command run against the server will return
     * an operation time that can be used here.
     * - SeeAlso: https://docs.mongodb.com/manual/reference/method/db.runCommand/
     */
    public let startAtOperationTime: Timestamp?

    /**
     * Similar to `resumeAfter`, this option takes a resume token and starts a new change stream returning the first
     * notification after the token.
     * This will allow users to watch collections that have been dropped and
     * recreated or newly renamed collections without missing any
     * notifications.
     * The server will report an error if `startAfter` and `resumeAfter` are
     * both specified.
     * - SeeAlso: https://docs.mongodb.com/master/changeStreams/#change-stream-start-after
     */
    public let startAfter: ChangeStreamToken?

    /// Initializes a `ChangeStreamOption`.
    public init(fullDocument: FullDocument? = nil,
                resumeAfter: Document? = nil,
                maxAwaitTimeMS: Int64? = nil,
                batchSize: Int32? = nil,
                collation: Document? = nil,
                startAtOperationTime: Timestamp? = nil,
                startAfter: Document? = nil) {
        self.fullDocument = fullDocument
        self.resumeAfter = resumeAfter
        self.maxAwaitTimeMS = maxAwaitTimeMS
        self.batchSize = batchSize
        self.collation = collation
        self.startAtOperationTime = startAtOperationTime
        self.startAfter = startAfter
    }
}
