import Foundation
import libmongoc

public enum MongoError {
    case invalidUri(message: String)
    case invalidClient()
    case invalidResponse()
    case invalidCursor(message: String)
    case invalidCollection(message: String)
    case commandError(message: String)
    case bsonParseError(domain: UInt32, code: UInt32, message: String)
    case bsonEncodeError(message: String)
    case typeError(message: String)
    case readConcernError(message: String)
}

extension MongoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidUri(message), let .invalidCursor(message),
            let .invalidCollection(message), let .commandError(message),
            let .bsonParseError(_, _, message), let .bsonEncodeError(message),
            let .typeError(message):
            return message
        default:
            return nil
        }
    }
}

internal func toErrorString(_ error: bson_error_t) -> String {
    var e = error
    return withUnsafeBytes(of: &e.message) { (rawPtr) -> String in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
    }
}

internal func bsonEncodeError(value: BsonValue, forKey: String) -> MongoError {
    return MongoError.bsonEncodeError(message:
        "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType)")
}
