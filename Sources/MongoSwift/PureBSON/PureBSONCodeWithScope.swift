import Foundation

public struct PureBSONCode: Equatable, Hashable, Codable {
    /// A string containing Javascript code.
    public let code: String

    /// Initializes a `CodeWithScope`.
    public init(code: String) {
        self.code = code
    }
}

extension PureBSONCode: PureBSONValue {
    internal static var bsonType: BSONType { return .javascript }

    internal var bson: BSON { return .code(self) }

    internal var canonicalExtJSON: String {
        return "{ \"$code\": \(self.code.canonicalExtJSON) }"
    }

    internal init(from data: inout Data) throws {
        self.code = try readString(from: &data)
    }

    internal func toBSON() -> Data {
        return self.code.toBSON()
    }
}

public struct PureBSONCodeWithScope: Equatable, Hashable, Codable {
    /// A string containing Javascript code.
    public let code: String
    /// An optional scope `Document` containing a mapping of identifiers to values,
    /// representing the context in which `code` should be evaluated.
    public let scope: PureBSONDocument

    /// Initializes a `CodeWithScope`.
    public init(code: String, scope: PureBSONDocument) {
        self.code = code
        self.scope = scope
    }
}

extension PureBSONCodeWithScope: PureBSONValue {
    internal static var bsonType: BSONType { return .javascriptWithScope }

    internal var bson: BSON { return .codeWithScope(self) }

    internal var canonicalExtJSON: String {
        return "{ \"$code\": \(self.code.canonicalExtJSON), \"$scope\": \(self.scope.canonicalExtJSON) }"
    }

    internal var extJSON: String {
        return "{ \"$code\": \(self.code.canonicalExtJSON), \"$scope\": \(self.scope.extJSON) }"
    }

    internal init(from data: inout Data) throws {
        _ = try Int32(from: &data)
        self.code = try readString(from: &data)
        self.scope = try PureBSONDocument(from: &data)

    }

    internal func toBSON() -> Data {
        let encodedCode = self.code.toBSON()
        let encodedScope = scope.toBSON()
        let byteLength = Int32(4 + encodedCode.count + encodedScope.count).toBSON()
        return byteLength + encodedCode + encodedScope
    }
}
