import libmongoc

public enum MongoError: Error {
    case invalidUri(message: String)
    case invalidClient()
    case invalidResponse()
    case invalidCursor(message: String)
    case invalidCollection(message: String)
    case commandError(message: String)
    case writeError(message: String)
    case bsonParseError(domain: UInt32, code: UInt32, message: String)
    case bsonEncodeError(message: String)
}

public func toErrorString(_ error: bson_error_t) -> String {
    var e = error
    return withUnsafeBytes(of: &e.message) { (rawPtr) -> String in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
    }
}

public func bsonEncodeError(value: BsonValue, forKey: String) -> MongoError {
    return MongoError.bsonEncodeError(message:
        "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType)")
}
