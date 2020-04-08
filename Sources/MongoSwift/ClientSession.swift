import CLibMongoC
import Foundation
import NIO

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
 *   let futureCount = client.withSession { session in
 *       collection.insertOne(["x": 1], session: session).flatMap { _ in
 *           collection.countDocuments(session: session)
 *       }
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
    /// Error thrown when an inactive session is used.
    internal static let SessionInactiveError = LogicError(message: "Tried to use an inactive session")
    /// Error thrown when a user attempts to use a session with a client it was not created from.
    internal static let ClientMismatchError = InvalidArgumentError(
        message: "Sessions may only be used with the client used to create them"
    )

    /// Enum for tracking the state of a session.
    internal enum State {
        /// Indicates that this session has not been used yet and a corresponding `mongoc_client_session_t` has not
        /// yet been created. If the user sets operation time or cluster time prior to using the session, those values
        /// are stored here so they can be set upon starting the session.
        case notStarted(opTime: Timestamp?, clusterTime: Document?)
        /// Indicates that the session has been started and a corresponding `mongoc_client_session_t` exists. Stores a
        /// pointer to the underlying `mongoc_client_session_t` and the source `Connection` for this session.
        case started(session: OpaquePointer, connection: Connection)
        /// Indicates that the session has been ended.
        case ended
    }

    /// Indicates the state of this session.
    internal var state: State

    /// Returns whether this session is in the `started` state.
    internal var active: Bool {
        if case .started = self.state {
            return true
        }
        return false
    }

    /// The client used to start this session.
    public let client: MongoClient

    /// The session ID of this session. This is internal for now because we only have a value available after we've
    /// started the libmongoc session.
    internal var id: Document?

    /// The server ID of the mongos this session is pinned to. A server ID of 0 indicates that the session is unpinned.
    internal var serverId: UInt32? {
        switch self.state {
        case .notStarted, .ended:
            return nil
        case let .started(session, _):
            return mongoc_client_session_get_server_id(session)
        }
    }

    /// Enum tracking the state of the transaction associated with this session.
    internal enum TransactionState: String, Decodable {
        /// There is no transaction in progress.
        case none
        /// A transaction has been started, but no operation has been sent to the server.
        case starting
        /// A transaction is in progress.
        case inProgress
        /// The transaction was committed.
        case committed
        /// The transaction was aborted.
        case aborted

        fileprivate var mongocTransactionState: mongoc_transaction_state_t {
            switch self {
            case .none:
                return MONGOC_TRANSACTION_NONE
            case .starting:
                return MONGOC_TRANSACTION_STARTING
            case .inProgress:
                return MONGOC_TRANSACTION_IN_PROGRESS
            case .committed:
                return MONGOC_TRANSACTION_COMMITTED
            case .aborted:
                return MONGOC_TRANSACTION_ABORTED
            }
        }

        fileprivate init(mongocTransactionState: mongoc_transaction_state_t) {
            switch mongocTransactionState {
            case MONGOC_TRANSACTION_NONE:
                self = .none
            case MONGOC_TRANSACTION_STARTING:
                self = .starting
            case MONGOC_TRANSACTION_IN_PROGRESS:
                self = .inProgress
            case MONGOC_TRANSACTION_COMMITTED:
                self = .committed
            case MONGOC_TRANSACTION_ABORTED:
                self = .aborted
            default:
                fatalError("Unexpected transaction state: \(mongocTransactionState)")
            }
        }
    }

    /// The transaction state of this session.
    internal var transactionState: TransactionState? {
        switch self.state {
        case .notStarted, .ended:
            return nil
        case let .started(session, _):
            return TransactionState(mongocTransactionState: mongoc_client_session_get_transaction_state(session))
        }
    }

    /// Indicates whether or not the session is in a transaction.
    internal var inTransaction: Bool {
        if let transactionState = self.transactionState {
            return transactionState != .none
        }
        return false
    }

    /// The most recent cluster time seen by this session. This value will be nil if either of the following are true:
    /// - No operations have been executed using this session and `advanceClusterTime` has not been called.
    /// - This session has been ended.
    public var clusterTime: Document? {
        switch self.state {
        case let .notStarted(_, clusterTime):
            return clusterTime
        case let .started(session, _):
            guard let time = mongoc_client_session_get_cluster_time(session) else {
                return nil
            }
            return Document(copying: time)
        case .ended:
            return nil
        }
    }

    /// The operation time of the most recent operation performed using this session. This value will be nil if either
    /// of the following are true:
    /// - No operations have been performed using this session and `advanceOperationTime` has not been called.
    /// - This session has been ended.
    public var operationTime: Timestamp? {
        switch self.state {
        case let .notStarted(opTime, _):
            return opTime
        case let .started(session, _):
            var timestamp: UInt32 = 0
            var increment: UInt32 = 0
            mongoc_client_session_get_operation_time(session, &timestamp, &increment)

            guard timestamp != 0 && increment != 0 else {
                return nil
            }
            return Timestamp(timestamp: timestamp, inc: increment)
        case .ended:
            return nil
        }
    }

    /// The options used to start this session.
    public let options: ClientSessionOptions?

    /// Initializes a new client session.
    internal init(client: MongoClient, options: ClientSessionOptions? = nil) {
        self.options = options
        self.client = client
        self.state = .notStarted(opTime: nil, clusterTime: nil)
    }

    /// Starts this session's corresponding libmongoc session, if it has not been started already. Throws an error if
    /// this session has already been ended.
    internal func startIfNeeded() -> EventLoopFuture<Void> {
        switch self.state {
        case .notStarted:
            let operation = StartSessionOperation(session: self)
            return self.client.operationExecutor.execute(operation, client: self.client, session: nil)
        case .started:
            return self.client.operationExecutor.makeSucceededFuture(Void())
        case .ended:
            return self.client.operationExecutor.makeFailedFuture(ClientSession.SessionInactiveError)
        }
    }

    /// Retrieves this session's underlying connection. Throws an error if the provided client was not the client used
    /// to create this session, or if this session has not been started yet, or if this session has already been ended.
    internal func getConnection(forUseWith client: MongoClient) throws -> Connection {
        guard case let .started(_, connection) = self.state else {
            throw ClientSession.SessionInactiveError
        }
        guard self.client == client else {
            throw ClientSession.ClientMismatchError
        }
        return connection
    }

    /// Ends this `ClientSession`. Call this method when you are finished using the session. You must ensure that all
    /// operations using this session have completed before calling this. The returned future must be fulfilled before
    /// this session's parent `MongoClient` is closed.
    public func end() -> EventLoopFuture<Void> {
        switch self.state {
        case .notStarted, .ended:
            self.state = .ended
            return self.client.operationExecutor.makeSucceededFuture(Void())
        case let .started(session, _):
            return self.client.operationExecutor.execute {
                mongoc_client_session_destroy(session)
                self.state = .ended
            }
        }
    }

    /// Cleans up internal state.
    deinit {
        guard case .ended = self.state else {
            assertionFailure("ClientSession was not ended before going out of scope; please call ClientSession.end()")
            return
        }
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
        switch self.state {
        case let .notStarted(opTime, _):
            self.state = .notStarted(opTime: opTime, clusterTime: clusterTime)
        case let .started(session, _):
            mongoc_client_session_advance_cluster_time(session, clusterTime._bson)
        case .ended:
            return
        }
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
        switch self.state {
        case let .notStarted(_, clusterTime):
            self.state = .notStarted(opTime: operationTime, clusterTime: clusterTime)
        case let .started(session, _):
            mongoc_client_session_advance_operation_time(session, operationTime.timestamp, operationTime.increment)
        case .ended:
            return
        }
    }

    /// Appends this provided session to an options document for libmongoc interoperability.
    /// - Throws:
    ///   - `LogicError` if this session is inactive
    internal func append(to doc: inout Document) throws {
        guard case let .started(session, _) = self.state else {
            throw ClientSession.SessionInactiveError
        }

        var error = bson_error_t()
        try withMutableBSONPointer(to: &doc) { docPtr in
            guard mongoc_client_session_append(session, docPtr, &error) else {
                throw extractMongoError(error: error)
            }
        }
    }

    /**
     * Starts a multi-document transaction for all subsequent operations in this session. Any options provided in
     * `options` override the default transaction options for this session and any options inherited from
     * `MongoClient`. The transaction must be completed with `commitTransaction` or `abortTransaction`. An in-progress
     * transaction is automatically aborted when `ClientSession.end()` is called.
     *
     * - Parameters:
     *   - options: The options to use when starting this transaction
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when `startTransaction` is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `LogicError` if the session already has an in-progress transaction.
     *    - `LogicError` if `startTransaction` is called on an ended session.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/transactions/
     */
    public func startTransaction(options: TransactionOptions? = nil) -> EventLoopFuture<Void> {
        switch self.state {
        case .notStarted, .started:
            let operation = StartTransactionOperation(options: options)
            return self.client.operationExecutor.execute(operation, client: self.client, session: self)
        case .ended:
            return self.client.operationExecutor.makeFailedFuture(ClientSession.SessionInactiveError)
        }
    }

    /**
     * Commits a multi-document transaction for this session. Server and network errors are not ignored.
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when `commitTransaction` is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `CommandError` if an error occurs that prevents the command from executing.
     *    - `LogicError` if the session has no in-progress transaction.
     *    - `LogicError` if `commitTransaction` is called on an ended session.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/transactions/
     */
    public func commitTransaction() -> EventLoopFuture<Void> {
        switch self.state {
        case .notStarted, .started:
            let operation = CommitTransactionOperation()
            return self.client.operationExecutor.execute(operation, client: self.client, session: self)
        case .ended:
            return self.client.operationExecutor.makeFailedFuture(ClientSession.SessionInactiveError)
        }
    }

    /**
     * Aborts a multi-document transaction for this session. Server and network errors are ignored.
     *
     * - Returns:
     *    An `EventLoopFuture<Void>` that succeeds when `abortTransaction` is successful.
     *
     *    If the future fails, the error is likely one of the following:
     *    - `LogicError` if the session has no in-progress transaction.
     *    - `LogicError` if `abortTransaction` is called on an ended session.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/transactions/
     */
    public func abortTransaction() -> EventLoopFuture<Void> {
        switch self.state {
        case .notStarted, .started:
            let operation = AbortTransactionOperation()
            return self.client.operationExecutor.execute(operation, client: self.client, session: self)
        case .ended:
            return self.client.operationExecutor.makeFailedFuture(ClientSession.SessionInactiveError)
        }
    }

    /**
     * Starts a multi-document transaction and executes the provided closure. The transaction is only valid within the
     * body of the closure and will be committed after the body completes. Any options provided in `options` override
     * the default transaction options for this session and any options inherited from `MongoClient`.
     *
     * If an error occurs, `withTransaction` includes logic to retry transactions and commits, whenever possible. Note
     * that the function has an retry time limit of 120 seconds that is not configurable.
     *
     * The provided closure should not attempt to start a new transaction, commit or abort the current transaction,
     * and/or end the session. If the closure commits or aborts the current transaction and/or ends the session,
     * however, `withTransaction` will return without taking further action.
     *
     * - Parameters:
     *   - options: The options to use when starting the transaction.
     *
     * - Returns:
     *   - An `EventLoopFuture<T>`, the return value of the user-provided closure.
     *
     *   If the future fails, the error is likely one of the following:
     *   - `CommandError` if an error prevents a command from executing.
     *   - `LogicError` if the session already has an in-progress transaction.
     *   - `LogicError` if `withTransaction` is called on an ended session.
     *
     * - SeeAlso:
     *   - https://docs.mongodb.com/manual/core/transactions/
     */
    public func withTransaction<T>(
        options: TransactionOptions? = nil,
        _ transactionBody: @escaping (ClientSession) throws -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        switch self.state {
        case .notStarted, .started:
            // Enforce a 120-second timeout to limit transaction retry behavior.
            let retryTimeoutTime = Date(timeIntervalSinceNow: 120)
            return self.attemptTransaction(
                retryTimeoutTime: retryTimeoutTime,
                options: options,
                transactionBody
            )
        case .ended:
            return self.client.operationExecutor.makeFailedFuture(ClientSession.SessionInactiveError)
        }
    }

    // Private helper function that attempts to start a multi-document transaction, execute the provided closure, and
    // commit the transaction. If an error occurs, the function attempts to retry the transaction, whenever possible.
    // - Note: This function should not be used outside the context of `withTransaction`.
    private func attemptTransaction<T>(
        retryTimeoutTime: Date,
        options: TransactionOptions?,
        _ transactionBody: @escaping (ClientSession) throws -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        self.startTransaction(options: options).flatMap { _ in
            do {
                let transactionBodyFuture = try transactionBody(self)
                return transactionBodyFuture.flatMap { value in
                    if [.none, .committed, .aborted].contains(self.transactionState ?? .none) {
                        return self.client.operationExecutor.makeSucceededFuture(value)
                    }
                    return self.attemptTransactionCommit(
                        value: value,
                        retryTimeoutTime: retryTimeoutTime,
                        options: options,
                        transactionBody
                    )
                }.flatMapError { error in
                    if [.starting, .inProgress].contains(self.transactionState ?? .none) {
                        return self.abortTransaction().flatMap { _ in
                            self.maybeRetryOrFail(
                                error: error,
                                retryTimeoutTime: retryTimeoutTime,
                                options: options,
                                transactionBody
                            )
                        }
                    }
                    return self.maybeRetryOrFail(
                        error: error,
                        retryTimeoutTime: retryTimeoutTime,
                        options: options,
                        transactionBody
                    )
                }
            } catch {
                return self.client.operationExecutor.makeFailedFuture(error)
            }
        }
    }

    // Private helper function that attempts to commit a multi-document transaction. If an error occurs, the function
    // attempts to retry either the commit or the transaction, whenever possible.
    // - Note: This function should not be used outside the context of `withTransaction`.
    private func attemptTransactionCommit<T>(
        value: T,
        retryTimeoutTime: Date,
        options: TransactionOptions?,
        _ transactionBody: @escaping (ClientSession) throws -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        self.commitTransaction().flatMap { _ in
            self.client.operationExecutor.makeSucceededFuture(value)
        }.flatMapError { error in
            if let labeledError = error as? LabeledError, let errorLabels = labeledError.errorLabels,
                retryTimeoutTime.timeIntervalSinceNow > 0 {
                if !isMaxTimeMSExpiredError(error) && errorLabels.contains("UnknownTransactionCommitResult") {
                    return self.attemptTransactionCommit(
                        value: value,
                        retryTimeoutTime: retryTimeoutTime,
                        options: options,
                        transactionBody
                    )
                }
                if errorLabels.contains("TransientTransactionError") {
                    return self.attemptTransaction(
                        retryTimeoutTime: retryTimeoutTime,
                        options: options,
                        transactionBody
                    )
                }
            }
            return self.client.operationExecutor.makeFailedFuture(error)
        }
    }

    // Private helper function that attempts to retry a multi-document transaction, whenever possible.
    // - Note: This function should not be used outside the context of `withTransaction`.
    private func maybeRetryOrFail<T>(
        error: Error,
        retryTimeoutTime: Date,
        options: TransactionOptions?,
        _ transactionBody: @escaping (ClientSession) throws -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        if let labeledError = error as? LabeledError, let errorLabels = labeledError.errorLabels,
            retryTimeoutTime.timeIntervalSinceNow > 0 && errorLabels.contains("TransientTransactionError") {
            return self.attemptTransaction(
                retryTimeoutTime: retryTimeoutTime,
                options: options,
                transactionBody
            )
        }
        return self.client.operationExecutor.makeFailedFuture(error)
    }
}
