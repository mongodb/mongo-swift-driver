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
 *   let opts = MongoCollectionOptions(readConcern: .majority, writeConcern: .majority)
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

    internal let asyncSession: MongoSwift.ClientSession

    /// The most recent cluster time seen by this session. This value will be nil if either of the following are true:
    /// - No operations have been executed using this session and `advanceClusterTime` has not been called.
    /// - This session has been ended.
    public var clusterTime: BSONDocument? { self.asyncSession.clusterTime }

    /// The operation time of the most recent operation performed using this session. This value will be nil if either
    /// of the following are true:
    /// - No operations have been performed using this session and `advanceOperationTime` has not been called.
    /// - This session has been ended.
    public var operationTime: BSONTimestamp? { self.asyncSession.operationTime }

    /// The options used to start this session.
    public var options: ClientSessionOptions? { self.asyncSession.options }

    /// Initializes a new client session.
    internal init(client: MongoClient, options: ClientSessionOptions?) {
        self.client = client
        self.asyncSession = client.asyncClient.startSession(options: options)
    }

    /// Ends the underlying async session.
    internal func end() {
        // we only call this method from places that we can't throw (deinit, defers) so we handle the error here
        // instead. the async method will only fail if the async client, thread pool, or event loop group have been
        // closed/ended. we manage the lifetimes of all of those ourselves, so if we hit the assertionFailure it's due
        // to a bug in our own code.
        do {
            try self.asyncSession.end().wait()
        } catch {
            assertionFailure("Error ending async session: \(error)")
        }
    }

    /// Cleans up internal state.
    deinit {
        // a repeated call to `end` is a no-op so it's ok to call this even if `end()` was already called explicitly.
        self.end()
    }

    /**
     * Advances the clusterTime for this session to the given time, if it is greater than the current clusterTime. If
     * the session has been ended, or if the provided clusterTime is less than the current clusterTime, this method has
     * no effect.
     *
     * - Parameters:
     *   - clusterTime: The session's new cluster time, as a `Document` like `["cluster time": Timestamp(...)]`
     */
    public func advanceClusterTime(to clusterTime: BSONDocument) {
        self.asyncSession.advanceClusterTime(to: clusterTime)
    }

    /**
     * Advances the operationTime for this session to the given time if it is greater than the current operationTime.
     * If the session has been ended, or if the provided operationTime is less than the current operationTime, this
     * method has no effect.
     *
     * - Parameters:
     *   - operationTime: The session's new operationTime
     */
    public func advanceOperationTime(to operationTime: BSONTimestamp) {
        self.asyncSession.advanceOperationTime(to: operationTime)
    }

    /**
     * Starts a multi-document transaction for all subsequent operations in this session. Any options provided in
     * `options` override the default transaction options for this session and any options inherited from
     * `MongoClient`. The transaction must be completed with `commitTransaction` or `abortTransaction`. An in-progress
     * transaction is automatically aborted when `ClientSession` goes out of scope.
     *
     * - Parameters:
     *   - options: The options to use when starting this transaction
     *
     * - Throws:
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `LogicError` if the session already has an in-progress transaction.
     *   - `LogicError` if `startTransaction` is called on an ended session.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/transactions/
     */
    public func startTransaction(options: TransactionOptions? = nil) throws {
        try self.asyncSession.startTransaction(options: options).wait()
    }

    /**
     * Commits a multi-document transaction for this session. Server and network errors are not ignored.
     *
     * - Throws:
     *   - `CommandError` if an error occurs that prevents the command from executing.
     *   - `LogicError` if the session has no in-progress transaction.
     *   - `LogicError` if `commitTransaction` is called on an ended session.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/transactions/
     */
    public func commitTransaction() throws {
        try self.asyncSession.commitTransaction().wait()
    }

    /**
     * Aborts a multi-document transaction for this session. Server and network errors are ignored.
     *
     * - Throws:
     *   - `LogicError` if the session has no in-progress transaction.
     *   - `LogicError` if `abortTransaction` is called on an ended session.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/transactions/
     */
    public func abortTransaction() throws {
        try self.asyncSession.abortTransaction().wait()
    }
}
