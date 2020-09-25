import CLibMongoC
import Foundation

/// Options to use when creating a `ClientSession`.
public struct ClientSessionOptions {
    /// Whether to enable causal consistency for this session. By default, causal consistency is enabled.
    ///
    /// - SeeAlso: https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/
    public var causalConsistency: Bool?

    /// The default `TransactionOptions` to use for transactions started on this session.
    ///
    /// These may be overridden by options provided directly to `ClientSession.startTransaction`.
    ///
    /// If this option is not specified, the options will be inherited from the client that started this session where
    /// applicable (e.g. write concern).
    public var defaultTransactionOptions: TransactionOptions?

    /// Convenience initializer allowing any/all parameters to be omitted.
    public init(causalConsistency: Bool? = nil, defaultTransactionOptions: TransactionOptions? = nil) {
        self.causalConsistency = causalConsistency
        self.defaultTransactionOptions = defaultTransactionOptions
    }
}

/// Private helper for providing a `mongoc_session_opt_t` that is only valid within the body of the provided
/// closure.
private func withSessionOpts<T>(
    wrapping options: ClientSessionOptions?,
    _ body: (OpaquePointer) throws -> T
) rethrows -> T {
    // swiftlint:disable:next force_unwrapping
    let opts = mongoc_session_opts_new()! // always returns a value
    defer { mongoc_session_opts_destroy(opts) }

    if let causalConsistency = options?.causalConsistency {
        mongoc_session_opts_set_causal_consistency(opts, causalConsistency)
    }

    withMongocTransactionOpts(copying: options?.defaultTransactionOptions) {
        mongoc_session_opts_set_default_transaction_opts(opts, $0)
    }

    return try body(opts)
}

/// An operation corresponding to starting a libmongoc session.
internal struct StartSessionOperation: Operation {
    /// The session to start.
    private let session: ClientSession

    internal init(session: ClientSession) {
        self.session = session
    }

    internal func execute(
        using connection: Connection,
        session _: ClientSession?
    ) throws -> (session: OpaquePointer, connection: Connection) {
        let sessionPtr: OpaquePointer = try withSessionOpts(wrapping: self.session.options) { opts in
            var error = bson_error_t()
            return try connection.withMongocConnection { connPtr in
                guard let sessionPtr = mongoc_client_start_session(connPtr, opts, &error) else {
                    throw extractMongoError(error: error)
                }
                return sessionPtr
            }
        }
        return (sessionPtr, connection)
    }
}
