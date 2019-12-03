import MongoSwift

/**
 * A MongoDB client session.
 * This class represents a logical session used for ordering sequential operations.
 *
 * To create a client session, use `startSession` or `withSession` on a `MongoClient`.
 *
 * If `causalConsistency` is not set to `false` when starting a session, read and write operations that use the session
 * will be provided causal consistency guarantees depending on the read and write concerns used. Using "majority"
 * read and write preferences will provide the full set of guarantees. See
 * https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/#sessions for more details.
 *
 * e.g.
 *   ```
 *   let opts = CollectionOptions(readConcern: ReadConcern(.majority), writeConcern: try WriteConcern(w: .majority))
 *   let collection = database.collection("mycoll", options: opts)
 *   try client.withSession { session in
 *       try collection.insertOne(["x": 1], session: session)
 *       try collection.find(["x": 1], session: session)
 *   }
 *   ```
 *
 * To disable causal consistency, set `causalConsistency` to `false` in the `ClientSessionOptions` passed in to either
 * `withSession` or `startSession`.
 *
 * - SeeAlso:
 *   - https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/#sessions
 *   - https://docs.mongodb.com/manual/core/causal-consistency-read-write-concerns/
 */
public final class ClientSession {
    /// The client used to start this session.
    public let client: MongoClient

    /// The most recent cluster time seen by this session. This value will be nil if either of the following are true:
    /// - No operations have been executed using this session and `advanceClusterTime` has not been called.
    /// - This session has been ended.
    public var clusterTime: Document? {
        fatalError("unimplemented")
    }

    /// The operation time of the most recent operation performed using this session. This value will be nil if either
    /// of the following are true:
    /// - No operations have been performed using this session and `advanceOperationTime` has not been called.
    /// - This session has been ended.
    public var operationTime: Timestamp? {
        fatalError("unimplemented")
    }

    /// The options used to start this session.
    public let options: ClientSessionOptions?

    /// Initializes a new client session.
    internal init(wrapping session: MongoSwift.ClientSession) throws {
        fatalError("unimplemented")
    }

    /// Cleans up internal state.
    deinit {
        fatalError("unimplemented")
    }

    /**
     * Advances the clusterTime for this session to the given time, if it is greater than the current clusterTime. If
     * the session has been ended, or if the provided clusterTime is less than the current clusterTime, this method has
     * no effect.
     *
     * - Parameters:
     *   - clusterTime: The session's new cluster time, as a `Document` like `["cluster time": Timestamp(...)]`
     */
    public func advanceClusterTime(to clusterTime: Document) {
        fatalError("unimplemented")
    }

    /**
     * Advances the operationTime for this session to the given time if it is greater than the current operationTime.
     * If the session has been ended, or if the provided operationTime is less than the current operationTime, this
     * method has no effect.
     *
     * - Parameters:
     *   - operationTime: The session's new operationTime
     */
    public func advanceOperationTime(to operationTime: Timestamp) {
        fatalError("unimplemented")
    }
}
