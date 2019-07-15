import Foundation

public enum BSON {
    case double(Double)
    case string(String)
    case bool(Bool)
    case objectId(PureBSONObjectId)
}

internal protocol PureBSONValue {
    init(from data: Data) throws
    func toBSON() -> Data
}

extension String: PureBSONValue {
    internal init(from data: Data) throws {
        guard let str = String(data: data, encoding: .utf8) else {
            throw InvalidBSONError("Unable to initialize String from BSON data")
        }
        self = str
    }

    internal func toBSON() -> Data {
        // `String`s are Unicode under the hood so force unwrap always succeeds.
        // see https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
        return self.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
    }
}

extension Bool: PureBSONValue {
    internal init(from data: Data) throws {
        guard data.count == 1 else {
            throw RuntimeError.internalError(message: "Expected to get 1 byte, got \(data.count)")
        }
        switch data[0] {
        case 0:
            self = false
        case 1:
            self = true
        default:
            throw InvalidBSONError("Unable to initialize Bool from byte \(data[0])")
        }
    }

    internal func toBSON() -> Data {
        return self ? Data([1]) : Data([0])
    }
}

internal struct InvalidBSONError: LocalizedError {
    internal let message: String

    internal init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        return self.message
    }
}
