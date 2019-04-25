import Foundation
import mongoc

internal typealias MutableClientSessionPointer = OpaquePointer

/// Options to use when creating a ClientSession.
public struct ClientSessionOptions {}

/// Private wrapper of a mongoc_session_opt_t.
private class SessionOptWrapper {
    /// Opaque pointer to a `mongoc_session_opt_t`
    fileprivate var _opts: OpaquePointer?

    fileprivate init(from options: ClientSessionOptions?) {
        guard options != nil else {
            return
        }
        self._opts = mongoc_session_opts_new()
    }

    deinit {
        guard let opts = self._opts else {
            return
        }
        mongoc_session_opts_destroy(opts)
    }
}

/// A MongoDB client session.
public final class ClientSession {
    /// Error thrown when an inactive session is used.
    internal static var SessionInactiveError = UserError.logicError(message: "Tried to use an inactive session")

    /// Pointer to the underlying `mongoc_client_session_t`.
    internal fileprivate(set) var _session: MutableClientSessionPointer?

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

    /// The options used to start this session.
    public let options: ClientSessionOptions?

    /// Initializes a new client session.
    internal init(client: MongoClient, options: ClientSessionOptions? = nil) throws {
        self.options = options
        self.client = client

        let opts = SessionOptWrapper(from: options)
        var error = bson_error_t()
        guard let session = mongoc_client_start_session(client._client, opts._opts, &error) else {
            throw parseMongocError(error)
        }
        // swiftlint:disable:next force_unwrapping
        self.id = Document(copying: mongoc_client_session_get_lsid(session)!) // always returns a value
        self._session = session
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
        mongoc_client_session_advance_cluster_time(self._session, clusterTime.storage.pointer)
    }

    /// Appends this provided session to an options document for libmongoc interoperability.
    /// - Throws:
    ///   - `UserError.logicError` if this session is inactive
    internal func append(to doc: inout Document) throws {
        guard self.active else {
            throw ClientSession.SessionInactiveError
        }

        doc.copyStorageIfRequired()
        var error = bson_error_t()
        guard mongoc_client_session_append(self._session, doc.storage.pointer, &error) else {
            throw parseMongocError(error)
        }
        doc.count = Int(bson_count_keys(doc.storage.pointer))
    }
}
