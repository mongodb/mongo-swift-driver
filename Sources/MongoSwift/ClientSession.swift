import Foundation
import mongoc

/// Options to use when creating a ClientSession.
public struct ClientSessionOptions {
    /// Whether to enable causal consistency for this session. By default, causal consistency is enabled.
    public let causalConsistency: Bool?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(causalConsistency: Bool? = nil) {
        self.causalConsistency = causalConsistency
    }
}

/// Private helper for providing a `mongoc_session_opt_t` that is only valid within the body of the provided
/// closure.
private func withSessionOpts<T>(wrapping options: ClientSessionOptions?,
                                _ body: (OpaquePointer) throws -> T) rethrows -> T {
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
    internal static var SessionInactiveError = UserError.logicError(message: "Tried to use an inactive session")

    /// Pointer to the underlying `mongoc_client_session_t`.
    internal fileprivate(set) var _session: OpaquePointer?

    /// Returns whether this session has been ended or not.
    internal var active: Bool { return self._session != nil }

    /// The client used to start this session.
    public let client: MongoClient

    /// The session ID of this session.
    public let id: Document

    /// The most recent cluster time seen by this session.
    /// If no operations have been executed using this session and `advanceClusterTime` has not been called, this will
    /// be `nil`.
    public var clusterTime: Document? {
        guard let time = mongoc_client_session_get_cluster_time(self._session) else {
            return nil
        }
        return Document(copying: time)
    }

    /// The operation time of the most recent operation performed using this session.
    public var operationTime: Timestamp? {
        var timestamp: UInt32 = 0
        var increment: UInt32 = 0
        mongoc_client_session_get_operation_time(self._session, &timestamp, &increment)

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

        self._session = try withSessionOpts(wrapping: options) { opts in
            var error = bson_error_t()
            guard let session = mongoc_client_start_session(client._client, opts, &error) else {
                throw parseMongocError(error)
            }
            return session
        }
        // swiftlint:disable:next force_unwrapping
        self.id = Document(copying: mongoc_client_session_get_lsid(self._session)!) // always returns a value
    }

    /// Destroy the underlying `mongoc_client_session_t` and set this session to inactive.
    /// Does nothing if this session is already inactive.
    internal func end() {
        guard self.active else {
            return
        }
        mongoc_client_session_destroy(self._session)
        self._session = nil
    }

    /// Cleans up internal state.
    deinit {
        self.end()
    }

    /**
     * Advances the clusterTime for this session to the given time, if it is greater than the current clusterTime.
     * If the provided clusterTime is less than the current clusterTime, this method has no effect.
     *
     * - Parameters:
     *   - clusterTime: The session's new cluster time, as a `Document` like `["cluster time": Timestamp(...)]`
     */
    public func advanceClusterTime(to clusterTime: Document) {
        mongoc_client_session_advance_cluster_time(self._session, clusterTime._storage._bson)
    }

    /**
     * Advances the operationTime for this session to the given time if it is greater than the current operationTime.
     * If the provided operationTime is less than the current operationTime, this method has no effect.
     *
     * - Parameters:
     *   - operationTime: The session's new operationTime
     */
    public func advanceOperationTime(to operationTime: Timestamp) {
        mongoc_client_session_advance_operation_time(self._session, operationTime.timestamp, operationTime.increment)
    }

    /// Appends this provided session to an options document for libmongoc interoperability.
    /// - Throws:
    ///   - `UserError.logicError` if this session is inactive
    internal func append(to doc: inout Document) throws {
        guard self.active else {
            throw ClientSession.SessionInactiveError
        }

        var error = bson_error_t()
        try withMutableBSONPointer(to: &doc) { docPtr in
            guard mongoc_client_session_append(self._session, docPtr, &error) else {
                throw parseMongocError(error)
            }
        }
    }
}
