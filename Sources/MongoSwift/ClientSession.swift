/// Options to use when creating a ClientSession.
internal struct SessionOptions: Encodable {
    /// Specifies whether read operations should be causally ordered within the session.
    private let causalConsistency: Bool?
}

/// :nodoc: A session for ordering sequential operations.
public class ClientSession: Encodable {
    /// Initializes a new client session.
    internal init() {
    }

    /// Cleans up internal state.
    deinit {
    }

    /// Finish the session.
    private func endSession() {
    }

    /// The server session id for this session.
    private var sessionId: Document {
        return Document()
    }

    /// The cluster time returned by the last operation executed in this session.
    private var clusterTime: Int64 {
        return Int64()
    }

    /// The operation time returned by the last operation executed in this session.
    private var operationTime: Int64 {
        return Int64()
    }
}
