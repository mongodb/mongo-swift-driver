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

internal struct StartSessionOperation: Operation {
    private let session: ClientSession

    internal func execute(using connection: Connection, _: ClientSession?) throws {
        let sessionPtr: OpaquePointer = try withSessionOpts(wrapping: self.session.options) { opts in
            var error = bson_error_t()
            guard let session = mongoc_client_start_session(connection.clientHandle, opts, &error) else {
                throw extractMongoError(error: error)
            }
            return session
        }
        session.state = .active(session: sessionPtr, connection: connection)
        // swiftlint:disable:next force_unwrapping
        session.id = Document(copying: mongoc_client_session_get_lsid(sessionPtr)!) // always returns a value
    }
}