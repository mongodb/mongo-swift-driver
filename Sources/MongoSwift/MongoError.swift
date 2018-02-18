import libmongoc

public enum MongoError: Error {
  case invalidUri(message: String)
  case invalidClient()
  case invalidResponse()
  case invalidCursor()
}

public func toErrorString(_ error: bson_error_t) -> String {
  var e = error
  return withUnsafeBytes(of: &e.message) { (rawPtr) -> String in
    let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
    return String(cString: ptr)
  }
}
