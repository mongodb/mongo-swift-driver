/// A wrapper for resumeToken.
public struct ChangeStreamToken: Codable {
    private let resumeToken: Document

    public init(resumeToken: Document) {
        self.resumeToken = resumeToken
    }
}
