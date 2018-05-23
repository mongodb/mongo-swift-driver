/// Options to use when creating a ClientSession.
public struct SessionOptions: Encodable {
    /// Specifies whether read operations should be causally ordered within the session.
    public let causalConsistency: Bool?
}

/// A session for ordering sequential operations.
public class ClientSession: Encodable {

    /// Initializes a new client session.
    public init() {
    }

    /// Clean up the internal mongoc_session_t.
    deinit {
    }

    /// Finish the session.
    func endSession() {
    }

    /// The server session id for this session.
    var sessionId: Document {
        return Document()
    }

    /// The cluster time returned by the last operation executed in this session.
    var clusterTime: Int64 {
        return Int64()
    }

    /// The operation time returned by the last operation executed in this session.
    var operationTime: Int64 {
        return Int64()
    }
}
