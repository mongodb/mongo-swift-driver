/// Describes the modes for configuring the fullDocument field of a change stream document.
public struct FullDocument: RawRepresentable, Codable {
    /// Specifies that the `fullDocument` field of an update event will contain a copy of the entire document that
    /// was changed from some time after the change occurred. If the document was deleted since the updated happened,
    /// it will be nil.
    public static let updateLookup = FullDocument("updateLookup")
    /// For an unknown value. For forwards compatibility, no error will be thrown when an unknown value is provided.
    public static func other(_ value: String) -> FullDocument {
        FullDocument(value)
    }

    public var rawValue: String

    /// Creates a `FullDocument`. Never returns nil.
    public init?(rawValue: String) { self.rawValue = rawValue }
    internal init(_ value: String) { self.rawValue = value }
}

/// Options to use when creating a `ChangeStream`.
public struct ChangeStreamOptions: Codable {
    /// The number of documents to return per batch. If omitted, the server will use its default batch size.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/command/aggregate
    public var batchSize: Int?

    /// Specifies a collation.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/command/aggregate
    public var collation: BSONDocument?

    /**
     * Indicates how the `fullDocument` field of a change stream document should be filled out by the server.
     * By default (indicated by a nil value for this option), the `fullDocument` field in the change stream document
     * will always be present in the case of 'insert' and 'replace' operations (containing the document being inserted)
     * and will be nil for all other operations.
     */
    public var fullDocument: FullDocument?

    /// The maximum amount of time in milliseconds for the server to wait on new documents to satisfy a
    /// change stream query. If omitted, the server will use its default timeout.
    public var maxAwaitTimeMS: Int?

    /**
     * A `ResumeToken` that manually specifies the logical starting point for the new change stream.
     * The change stream will attempt to resume notifications starting after the operation associated with
     * the provided token.
     * - Note: A change stream cannot be resumed after an invalidate event (e.g. a collection drop or rename).
     * - SeeAlso: https://docs.mongodb.com/manual/changeStreams/#resume-a-change-stream
     */
    public var resumeAfter: ResumeToken?

    /**
     * Similar to `resumeAfter`, this option takes a `ResumeToken` which will serve as the logical starting
     * point for the new change stream. This option differs from `resumeAfter` in that it will allow a change stream
     * to receive notifications even after an invalidate event (e.g. it will allow watching a collection that has
     * been dropped and recreated).
     * - Note: The server will report an error if `startAfter` and `resumeAfter` are both specified.
     * - SeeAlso: https://docs.mongodb.com/master/changeStreams/#change-stream-start-after
     */
    // TODO: SWIFT-519 - Make this public when support is added for 4.2 change stream features.
    // internal var startAfter: ResumeToken?

    /// The change stream will only provide changes that occurred at or after the specified timestamp.
    /// Any command run against the server will return an operation time that can be used here.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/method/db.runCommand/
    public var startAtOperationTime: BSONTimestamp?

    /// Initializes a `ChangeStreamOptions`.
    public init(
        batchSize: Int? = nil,
        collation: BSONDocument? = nil,
        fullDocument: FullDocument? = nil,
        maxAwaitTimeMS: Int? = nil,
        resumeAfter: ResumeToken? = nil,
        startAtOperationTime: BSONTimestamp? = nil
    ) {
        self.batchSize = batchSize
        self.collation = collation
        self.fullDocument = fullDocument
        self.maxAwaitTimeMS = maxAwaitTimeMS
        self.resumeAfter = resumeAfter
        self.startAtOperationTime = startAtOperationTime
    }
}
