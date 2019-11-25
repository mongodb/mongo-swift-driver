import Foundation
import mongoc

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
    /// Error thrown when an inactive session is used.
    internal static let SessionInactiveError = UserError.logicError(message: "Tried to use an inactive session")
    /// Error thrown when a user attempts to use a session with a client it was not created from.
    internal static let ClientMismatchError = UserError.invalidArgumentError(
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
    internal init(client: MongoClient, options: ClientSessionOptions? = nil) throws {
        self.options = options
        self.client = client
        self.state = .notStarted(opTime: nil, clusterTime: nil)
    }

    /// Starts this session's corresponding libmongoc session, if it has not been started already. Throws an error if
    /// this session has already been ended.
    internal func startIfNeeded() throws {
        switch self.state {
        case .notStarted:
            let operation = StartSessionOperation(session: self)
            try self.client.executeOperation(operation)
        case .started:
            return
        case .ended:
            throw ClientSession.SessionInactiveError
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

    /// Destroy the underlying `mongoc_client_session_t` and ends this session. Has no effect if this session is
    /// already ended.
    internal func end() {
        if case let .started(session, _) = self.state {
            mongoc_client_session_destroy(session)
        }
        self.state = .ended
    }

    /// Cleans up internal state.
    deinit {
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
    ///   - `UserError.logicError` if this session is inactive
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
}
