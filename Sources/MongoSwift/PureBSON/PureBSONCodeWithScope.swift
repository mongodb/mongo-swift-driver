import Foundation

public struct PureBSONCodeWithScope: Equatable, Hashable, Codable {
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
}

extension PureBSONCodeWithScope: PureBSONValue {
    internal var bson: BSON { return .codeWithScope(self) }

    internal init(from data: Data) throws {
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

    internal func toBSON() -> Data {
        let encodedScope = self.scope?.toBSON()
        var length = Int32(4 + self.code.utf8.count + 1 + (encodedScope?.count ?? 0)).toBSON()
        let encodedCode = self.code.toBSON()
        length.append(encodedCode)
        if let encodedScope = encodedScope {
            length.append(encodedScope)
        }
        return length
    }
}
