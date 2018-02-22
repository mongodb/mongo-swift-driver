import libmongoc

public enum MongoError: Error {
    case invalidUri(message: String)
    case invalidClient()
    case invalidResponse()
    case invalidCursor()
    case bsonParseError(domain: UInt32, code: UInt32, message: String)
    case bsonAppendError(message: String)
}

public func toErrorString(_ error: bson_error_t) -> String {
    var e = error
    return withUnsafeBytes(of: &e.message) { (rawPtr) -> String in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
    }
}

public func bsonAppendError(value: BsonValue, forKey: String) -> MongoError {
    return MongoError.bsonAppendError(
        message: "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType)")
}
