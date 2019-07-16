import Foundation

public struct PureBSONCodeWithScope: PureBSONValue, Equatable, Hashable {
    /// A string containing Javascript code.
    public let code: String
    /// An optional scope `Document` containing a mapping of identifiers to values,
    /// representing the context in which `code` should be evaluated.
    public let scope: PureBSONDocument?

    /// Initializes a `CodeWithScope` with an optional scope value.
    public init(code: String, scope: PureBSONDocument? = nil) {
        self.code = code
        self.scope = scope
    }

    public init(from data: Data) throws {
        let length: Int = try readInteger(from: data)
        guard data.count == 4 + length else {
            throw RuntimeError.internalError(message: "buffer not sized correctly for CodeWithScope")
        }
        let code = try readString(from: data)

        var scope: PureBSONDocument?
        if length > code.utf8.count + 4 {
            scope = try PureBSONDocument(from: data[(code.utf8.count + 4)...])
        }

        self.init(code: code, scope: scope)
    }
}
