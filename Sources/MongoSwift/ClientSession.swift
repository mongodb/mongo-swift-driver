import Foundation
import mongoc

/// Options to use when creating a `ClientSession`.
public struct ClientSessionOptions {
    /// Whether to enable causal consistency for this session. By default, causal consistency is enabled.
    ///
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/
    public let causalConsistency: Bool?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(causalConsistency: Bool? = nil) {
        self.causalConsistency = causalConsistency
    }
}

/// Private helper for providing a `mongoc_session_opt_t` that is only valid within the body of the provided
/// closure.
private func withSessionOpts<T>(
    wrapping options: ClientSessionOptions?,
    _ body: (OpaquePointer) throws -> T
) rethrows -> T {
    // swiftlint:disable:next force_unwrapping
    var opts = mongoc_session_opts_new()! // always returns a value
    defer { mongoc_session_opts_destroy(opts) }
    if let causalConsistency = options?.causalConsistency {
        mongoc_session_opts_set_causal_consistency(opts, causalConsistency)
    }
    return try body(opts)
}

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
        /// Indicates that the session is active. Stores a pointer to the underlying `mongoc_client_session_t` and the
        /// source `Connection` for this session.
        case active(session: OpaquePointer, connection: Connection)
        /// Indicates that the session has been ended.
        case inactive
    }

    /// Indicates the state of this session.
    internal private(set) var state: State

    /// Returns whether this session has been ended or not.
    internal var active: Bool {
        if case .active = self.state {
            return true
        }
        return false
    }

    /// The client used to start this session.
    public let client: MongoClient

    /// The session ID of this session.
    public let id: Document

    /// The most recent cluster time seen by this session. This value will be nil if either of the following are true:
    /// - No operations have been executed using this session and `advanceClusterTime` has not been called.
    /// - This session has been ended.
    public var clusterTime: Document? {
        guard case let .active(session, _) = self.state,
            let time = mongoc_client_session_get_cluster_time(session) else {
            return nil
        }
        return Document(copying: time)
    }

    /// The operation time of the most recent operation performed using this session. This value will be nil if either
    /// of the following are true:
    /// - No operations have been performed using this session.
    /// - This session has been ended.
    public var operationTime: Timestamp? {
        guard case let .active(session, _) = self.state else {
            return nil
        }

        var timestamp: UInt32 = 0
        var increment: UInt32 = 0
        mongoc_client_session_get_operation_time(session, &timestamp, &increment)

        guard timestamp != 0 && increment != 0 else {
            return nil
        }
        return Timestamp(timestamp: timestamp, inc: increment)
    }

    /// The options used to start this session.
    public let options: ClientSessionOptions?

    /// Initializes a new client session.
    internal init(client: MongoClient, options: ClientSessionOptions? = nil) throws {
        self.options = options
        self.client = client

        let connection = try client.connectionPool.checkOut()
        let session: OpaquePointer = try withSessionOpts(wrapping: options) { opts in
            var error = bson_error_t()
            guard let session = mongoc_client_start_session(connection.clientHandle, opts, &error) else {
                throw extractMongoError(error: error)
            }
            return session
        }

        self.state = .active(session: session, connection: connection)
        // swiftlint:disable:next force_unwrapping
        self.id = Document(copying: mongoc_client_session_get_lsid(session)!) // always returns a value
    }

    /// Retrieves this session's underlying connection. Throws an error if the provided client was not the client used
    /// to create this session, or if this session has been ended.
    internal func getConnection(forUseWith client: MongoClient) throws -> Connection {
        guard case let .active(_, connection) = self.state else {
            throw ClientSession.SessionInactiveError
        }
        guard self.client == client else {
            throw ClientSession.ClientMismatchError
        }
        return connection
    }

    /// Destroy the underlying `mongoc_client_session_t` and set this session to inactive.
    /// Does nothing if this session is already inactive.
    internal func end() {
        if case let .active(session, _) = self.state {
            mongoc_client_session_destroy(session)
            self.state = .inactive
        }
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
        if case let .active(session, _) = self.state {
            mongoc_client_session_advance_cluster_time(session, clusterTime._bson)
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
        if case let .active(session, _) = self.state {
            mongoc_client_session_advance_operation_time(session, operationTime.timestamp, operationTime.increment)
        }
    }

    /// Appends this provided session to an options document for libmongoc interoperability.
    /// - Throws:
    ///   - `UserError.logicError` if this session is inactive
    internal func append(to doc: inout Document) throws {
        guard case let .active(session, _) = self.state else {
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
